import AlarmKit
import AppIntents
import CallKit
import Flutter
import SwiftUI
import UIKit
import UserNotifications

/// Rings with the app closed. iPhone apps can't play sound or raise the volume
/// in the background, so every upcoming reminder gets a chain of system
/// alarms, one every [interval]: AlarmKit alarms on iOS 26+ (ring through
/// silent mode and Focus), time-sensitive notifications before that. Stopping
/// one does nothing because the next one follows; only a passed proof or a
/// snooze ("stop") ends the chain. Mirrors AlarmScheduler/AlarmService.kt.
///
/// While the app runs, Dart's Ringer plays the alarm (it ramps its own
/// volume), so the chain is pushed [lead] ahead and only fires if the app is
/// closed or suspended. During calls the chain waits until the call ends plus
/// the resume delay, like AlarmService.kt.
///
/// Channel contract (same as MainActivity.kt): sync, ring, stop, hold,
/// isPausedForCall, setupStatus, fixSetup, plus usesSystemAlarms.
final class AlarmChain: NSObject, CXCallObserverDelegate {
  static let shared = AlarmChain()

  /// 30 s escalating sound, trimmed below 30 s: iOS plays the default sound
  /// instead of a longer one.
  static let sound = "escalating_alarm.caf"

  private static let interval: TimeInterval = 120
  private static let chainLength = 15
  /// How far ahead the chain is kept while the app itself is ringing.
  private static let lead: TimeInterval = 120
  /// During a call nobody tells us when it ends if the app gets suspended, so
  /// the chain is pushed this far ahead and pushed again while we run.
  private static let callWindow: TimeInterval = 300
  /// iOS keeps at most 64 pending notifications per app.
  private static let budget = 60
  /// A rescheduled chain that moves less than this is left alone.
  private static let tolerance: TimeInterval = 45

  private let defaults = UserDefaults.standard
  private let calls = CXCallObserver()
  private var timer: Timer?
  private var active = false
  private var activeSince = Date()
  /// When Dart last said each ringing task is still ringing.
  private var lastRing: [String: Date] = [:]
  private var callEndedAt: Date?
  private var work: Task<Void, Never>?

  private lazy var backend: AlarmBackend = {
    if #available(iOS 26.0, *) { return SystemAlarms() }
    return NotificationAlarms()
  }()

  func attach(to messenger: FlutterBinaryMessenger) {
    FlutterMethodChannel(name: "nag_alarm/alarms", binaryMessenger: messenger)
      .setMethodCallHandler { [weak self] call, result in self?.handle(call, result) }
    FlutterMethodChannel(name: "nag_alarm/calls", binaryMessenger: messenger)
      .setMethodCallHandler { [weak self] call, result in
        if call.method == "isInCall" {
          result(self?.inCall ?? false)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }

    calls.setDelegate(self, queue: .main)
    let center = NotificationCenter.default
    center.addObserver(self, selector: #selector(didBecomeActive),
                       name: UIApplication.didBecomeActiveNotification, object: nil)
    center.addObserver(self, selector: #selector(willResignActive),
                       name: UIApplication.willResignActiveNotification, object: nil)
    timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
      self?.tick()
    }
    replan()
  }

  private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    switch call.method {
    case "sync":
      if let json = call.arguments as? String { sync(json) }
      result(nil)
    case "ring":
      if let json = call.arguments as? String, let alarm = parse(json) { ring(alarm) }
      result(nil)
    case "stop":
      if let id = call.arguments as? String { stop(id) }
      result(nil)
    case "hold":
      if let args = call.arguments as? [String: Any], let id = args["id"] as? String,
         let until = args["until"] as? NSNumber {
        hold(id, until: until.doubleValue)
      }
      result(nil)
    case "isPausedForCall":
      result(pauseDuringCalls && callBlockedUntil(Date()) != nil)
    case "usesSystemAlarms":
      if #available(iOS 26.0, *) { result(true) } else { result(false) }
    case "setupStatus":
      Task { @MainActor in result(await self.setupStatus()) }
    case "fixSetup":
      Task { @MainActor in
        await self.fixSetup(call.arguments as? String ?? "")
        result(nil)
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: Channel methods

  /// Dart's list of upcoming alarms replaces the stored one.
  private func sync(_ json: String) {
    defaults.set(json, forKey: "schedule")
    if !scheduledAlarms().isEmpty {
      Task { @MainActor in
        // First reminder: ask now rather than stay silent.
        if await self.backend.requestIfUndetermined() { self.replan() }
      }
    }
    replan()
  }

  /// The task rings in the app. Called every tick; cheap unless it's new.
  private func ring(_ alarm: [String: Any]) {
    guard let id = alarm["id"] as? String else { return }
    lastRing[id] = Date()
    var ringing = ringingAlarms()
    if ringing[id] != nil { return }
    ringing[id] = ["title": alarm["title"] as? String ?? "Reminder"]
    defaults.set(ringing, forKey: "ringing")
    replan()
  }

  /// Proof passed or snoozed: end the chain.
  private func stop(_ id: String) {
    var ringing = ringingAlarms()
    ringing[id] = nil
    defaults.set(ringing, forKey: "ringing")
    lastRing[id] = nil
    // Dart's next sync would drop it too; don't let a replan revive it first.
    if var schedule = scheduleJson(), let alarms = schedule["alarms"] as? [[String: Any]] {
      schedule["alarms"] = alarms.filter { $0["id"] as? String != id }
      if let data = try? JSONSerialization.data(withJSONObject: schedule) {
        defaults.set(String(data: data, encoding: .utf8), forKey: "schedule")
      }
    }
    replan()
  }

  /// Silent until [until] (ms) while a photo approval is pending; 0 ends it.
  private func hold(_ id: String, until: Double) {
    var ringing = ringingAlarms()
    guard var alarm = ringing[id] else { return }
    alarm["holdUntil"] = until > 0 ? until : nil
    ringing[id] = alarm
    defaults.set(ringing, forKey: "ringing")
    replan()
  }

  // MARK: Planning

  private func tick() {
    let now = Date()
    // Dart stopped ringing something without telling us (e.g. deleted it).
    if active && now.timeIntervalSince(activeSince) > 10 {
      var ringing = ringingAlarms()
      let stale = ringing.keys.filter {
        now.timeIntervalSince(lastRing[$0] ?? .distantPast) > 10
      }
      if !stale.isEmpty {
        stale.forEach { ringing[$0] = nil }
        defaults.set(ringing, forKey: "ringing")
      }
    }
    replan()
  }

  @objc private func didBecomeActive() {
    active = true
    activeSince = Date()
    replan()
  }

  @objc private func willResignActive() {
    active = false
    // Upcoming alarms go back to their exact time; the app may be suspended.
    replan()
  }

  func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall) {
    if inCall {
      callEndedAt = nil
    } else if callEndedAt == nil {
      callEndedAt = Date()
    }
    replan()
  }

  private var inCall: Bool { calls.calls.contains { !$0.hasEnded } }

  private var pauseDuringCalls: Bool {
    scheduleJson()?["pauseDuringCalls"] as? Bool ?? true
  }

  /// The earliest time an alarm may ring because of a call, or nil.
  private func callBlockedUntil(_ now: Date) -> Date? {
    if inCall { return now.addingTimeInterval(Self.callWindow) }
    guard let ended = callEndedAt else { return nil }
    let delay = scheduleJson()?["callResumeDelaySeconds"] as? Double ?? 30
    let resume = ended.addingTimeInterval(delay)
    if resume <= now {
      callEndedAt = nil
      return nil
    }
    return resume
  }

  /// Serialized, so two replans never interleave their cancels and schedules.
  private func replan() {
    let previous = work
    work = Task { @MainActor in
      await previous?.value
      await self.replanNow()
    }
  }

  private struct Wanted {
    let id: String
    let title: String
    let start: Date
  }

  private struct Planned: Codable {
    var start: Date
    var count: Int
    var ids: [String]
  }

  @MainActor
  private func replanNow() async {
    let now = Date()
    var notBefore = now.addingTimeInterval(1)
    if pauseDuringCalls, let resume = callBlockedUntil(now) {
      notBefore = max(notBefore, resume)
    }

    var wanted: [Wanted] = []
    let ringing = ringingAlarms()
    for (id, alarm) in ringing {
      // The app is running and ringing it: keep the chain ahead of us.
      var start = max(notBefore, now.addingTimeInterval(Self.lead))
      if let hold = alarm["holdUntil"] as? Double {
        start = max(start, Date(timeIntervalSince1970: hold / 1000))
      }
      wanted.append(Wanted(id: id, title: alarm["title"] as? String ?? "Reminder",
                           start: start))
    }
    for alarm in scheduledAlarms() {
      guard let id = alarm["id"] as? String, ringing[id] == nil,
            let due = alarm["dueAt"] as? Double else { continue }
      var start = max(notBefore, Date(timeIntervalSince1970: due / 1000))
      // In the foreground Dart rings it when it's due.
      if active { start = max(start, now.addingTimeInterval(Self.lead)) }
      wanted.append(Wanted(id: id, title: alarm["title"] as? String ?? "Reminder",
                           start: start))
    }

    // Every reminder gets its first alarm, then the soonest get their repeats.
    wanted.sort { $0.start < $1.start }
    var counts: [String: Int] = [:]
    var left = Self.budget
    for w in wanted where left > 0 {
      counts[w.id] = 1
      left -= 1
    }
    for w in wanted where counts[w.id] != nil {
      let extra = min(Self.chainLength - 1, left)
      counts[w.id]! += extra
      left -= extra
    }

    var planned = loadPlanned()
    for (id, p) in planned where counts[id] == nil {
      await backend.cancel(p.ids)
      planned[id] = nil
    }
    let allowed = await backend.isAuthorized()
    for w in wanted {
      guard let count = counts[w.id] else { continue }
      if let p = planned[w.id] {
        if p.count == count && abs(p.start.timeIntervalSince(w.start)) < Self.tolerance {
          continue
        }
        await backend.cancel(p.ids)
        planned[w.id] = nil
      }
      guard allowed else { continue }
      let times = (0..<count).map { w.start.addingTimeInterval(Double($0) * Self.interval) }
      let ids = await backend.schedule(id: w.id, title: w.title, times: times)
      planned[w.id] = Planned(start: w.start, count: count, ids: ids)
    }
    savePlanned(planned)
  }

  // MARK: Storage

  private func scheduleJson() -> [String: Any]? {
    guard let json = defaults.string(forKey: "schedule") else { return nil }
    return parse(json)
  }

  private func scheduledAlarms() -> [[String: Any]] {
    scheduleJson()?["alarms"] as? [[String: Any]] ?? []
  }

  /// id -> {title, holdUntil (ms)?}
  private func ringingAlarms() -> [String: [String: Any]] {
    defaults.dictionary(forKey: "ringing") as? [String: [String: Any]] ?? [:]
  }

  private func loadPlanned() -> [String: Planned] {
    guard let data = defaults.data(forKey: "planned") else { return [:] }
    return (try? JSONDecoder().decode([String: Planned].self, from: data)) ?? [:]
  }

  private func savePlanned(_ planned: [String: Planned]) {
    defaults.set(try? JSONEncoder().encode(planned), forKey: "planned")
  }

  private func parse(_ json: String) -> [String: Any]? {
    guard let data = json.data(using: .utf8) else { return nil }
    return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
  }

  // MARK: Setup screen

  @MainActor
  private func setupStatus() async -> [String: Bool] {
    if #available(iOS 26.0, *) {
      return ["alarmKit": AlarmManager.shared.authorizationState == .authorized]
    }
    return ["notifications": await NotificationAlarms.isAuthorized()]
  }

  @MainActor
  private func fixSetup(_ item: String) async {
    if await backend.requestIfUndetermined() {
      replan()
      return
    }
    // Asked before: only the Settings app can change it now.
    var url = UIApplication.openSettingsURLString
    if item == "notifications", #available(iOS 16.0, *) {
      url = UIApplication.openNotificationSettingsURLString
    }
    if let settings = URL(string: url) { await UIApplication.shared.open(settings) }
  }
}

/// Where the chain's alarms go.
private protocol AlarmBackend {
  /// Schedules one alarm per time; returns the ids to cancel them with.
  func schedule(id: String, title: String, times: [Date]) async -> [String]
  func cancel(_ ids: [String]) async
  func isAuthorized() async -> Bool
  /// Shows the permission prompt if it was never shown; true if it was.
  func requestIfUndetermined() async -> Bool
}

// MARK: iOS 26+: AlarmKit

@available(iOS 26.0, *)
struct ReminderAlarm: AlarmMetadata {}

/// "Prove it" on the alarm: opens the app, which shows the alarm screen
/// because the task is due.
@available(iOS 26.0, *)
struct ProveItIntent: LiveActivityIntent {
  static let title: LocalizedStringResource = "Prove it"
  static let openAppWhenRun = true
  static let isDiscoverable = false

  func perform() async throws -> some IntentResult { .result() }
}

@available(iOS 26.0, *)
private struct SystemAlarms: AlarmBackend {
  private var manager: AlarmManager { .shared }

  func schedule(id: String, title: String, times: [Date]) async -> [String] {
    let prove = AlarmButton(text: "Prove it", textColor: .white,
                            systemImageName: "checkmark.seal")
    let alert: AlarmPresentation.Alert
    if #available(iOS 26.1, *) {
      alert = .init(title: "\(title)", secondaryButton: prove,
                    secondaryButtonBehavior: .custom)
    } else {
      alert = .init(title: "\(title)",
                    stopButton: AlarmButton(text: "Stop", textColor: .white,
                                            systemImageName: "stop.circle"),
                    secondaryButton: prove, secondaryButtonBehavior: .custom)
    }
    let attributes = AlarmAttributes<ReminderAlarm>(
      presentation: AlarmPresentation(alert: alert), tintColor: .orange)
    var ids: [String] = []
    for time in times {
      let alarmId = UUID()
      do {
        _ = try await manager.schedule(
          id: alarmId,
          configuration: .alarm(schedule: .fixed(time), attributes: attributes,
                                secondaryIntent: ProveItIntent(),
                                sound: .named(AlarmChain.sound)))
        ids.append(alarmId.uuidString)
      } catch {
        NSLog("TNWR: couldn't schedule alarm for \(id): \(error)")
        break
      }
    }
    return ids
  }

  func cancel(_ ids: [String]) async {
    for id in ids.compactMap(UUID.init(uuidString:)) {
      try? manager.cancel(id: id)
    }
  }

  func isAuthorized() async -> Bool { manager.authorizationState == .authorized }

  func requestIfUndetermined() async -> Bool {
    guard manager.authorizationState == .notDetermined else { return false }
    _ = try? await manager.requestAuthorization()
    return true
  }
}

// MARK: iOS 15.5 to 25: notifications

private struct NotificationAlarms: AlarmBackend {
  private var center: UNUserNotificationCenter { .current() }

  static func isAuthorized() async -> Bool {
    let status = await UNUserNotificationCenter.current().notificationSettings()
      .authorizationStatus
    return status == .authorized
  }

  func schedule(id: String, title: String, times: [Date]) async -> [String] {
    var ids: [String] = []
    for (i, time) in times.enumerated() {
      let content = UNMutableNotificationContent()
      content.title = title
      content.body = "Ringing until you prove it's done. Tap to open."
      content.sound = UNNotificationSound(named: UNNotificationSoundName(AlarmChain.sound))
      // Breaks through Focus where the phone allows it.
      content.interruptionLevel = .timeSensitive
      let parts = Calendar.current.dateComponents(
        [.year, .month, .day, .hour, .minute, .second], from: time)
      let requestId = "\(id)#\(i)"
      do {
        try await center.add(UNNotificationRequest(
          identifier: requestId, content: content,
          trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)))
        ids.append(requestId)
      } catch {
        NSLog("TNWR: couldn't schedule notification for \(id): \(error)")
      }
    }
    return ids
  }

  func cancel(_ ids: [String]) async {
    center.removePendingNotificationRequests(withIdentifiers: ids)
    center.removeDeliveredNotifications(withIdentifiers: ids)
  }

  func isAuthorized() async -> Bool { await Self.isAuthorized() }

  func requestIfUndetermined() async -> Bool {
    guard await center.notificationSettings().authorizationStatus == .notDetermined
    else { return false }
    _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    return true
  }
}
