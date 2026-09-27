import 'dart:async';

import 'package:flutter/foundation.dart';

import 'alarm/alarm_engine.dart';
import 'alarm/call_detector.dart';
import 'alarm/ringer.dart';
import 'core/escalation.dart';
import 'core/models.dart';
import 'core/schedule.dart';
import 'core/settings.dart';
import 'core/task_store.dart';

/// Hooks the desktop shell (or later, a phone engine) uses to react when the
/// alarm starts and stops.
abstract class AlarmSurface {
  Future<void> onRinging();
  Future<void> onQuiet();
}

/// Ticks once a second: marks due tasks as ringing, escalates the ringer, and
/// applies snooze/complete. Ringing state is saved to disk, so killing and
/// relaunching the app keeps the alarm going where it left off.
///
/// While the user is on a call or video chat, a ringing alarm goes silent and
/// comes back after the call, at the same loudness it had before.
///
/// With an [AlarmEngine] that owns ringing (Android), the OS engine plays the
/// sound, escalates and handles calls, so alarms ring with the app closed;
/// this class keeps the engine's schedule in sync and tells it when to stop.
/// An engine that doesn't own ringing (iPhone) is still told what rings and
/// what's held, so its system alarms take over if the app is closed.
class AppController extends ChangeNotifier {
  AppController(
    this.store,
    this.ringer, {
    required this.settings,
    this.surface,
    this.engine,
    CallDetector? calls,
    DateTime Function()? clock,
  }) : _calls = calls ?? CallDetector(),
       _now = clock ?? DateTime.now {
    store.addListener(_scheduleSync);
    settings.addListener(_scheduleSync);
  }

  final TaskStore store;
  final Ringer ringer;
  final AppSettings settings;
  final AlarmSurface? surface;
  final AlarmEngine? engine;
  final CallDetector _calls;
  final DateTime Function() _now;

  Timer? _ticker;
  bool _ticking = false;
  EscalationState? current;

  /// When the ringing alarm was silenced for a call; null when not paused.
  DateTime? _pausedAt;
  DateTime? _callEndedAt;

  /// Set from the engine when it owns ringing.
  bool _enginePausedForCall = false;
  Timer? _syncTimer;

  bool get _engineRings => engine?.ownsRinging ?? false;

  bool get pausedForCall =>
      _engineRings ? _enginePausedForCall : _pausedAt != null;

  /// Silent while a photo approval is pending (see [holdForApproval]).
  String? _holdTaskId;
  DateTime? _holdStarted;
  DateTime? _holdUntil;

  bool get waitingForApproval => _holdUntil != null;

  /// Time left before the alarm rings again; null when not waiting.
  Duration? get approvalWaitLeft {
    final until = _holdUntil;
    if (until == null) return null;
    final left = until.difference(_now());
    return left.isNegative ? Duration.zero : left;
  }

  NagTask? get ringingTask {
    final ringing =
        store.tasks.where((t) => t.status == TaskStatus.ringing).toList()
          ..sort((a, b) => a.ringingSince!.compareTo(b.ringingSince!));
    return ringing.isEmpty ? null : ringing.first;
  }

  void start() {
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => tick());
    tick();
    syncEngine();
  }

  /// Batches bursts of changes into one engine sync.
  void _scheduleSync() {
    if (engine == null) return;
    _syncTimer?.cancel();
    _syncTimer = Timer(const Duration(milliseconds: 300), syncEngine);
  }

  @visibleForTesting
  Future<void> syncEngine() async {
    await engine?.sync(
      store.tasks.where((t) => t.status == TaskStatus.scheduled).toList(),
      settings,
    );
  }

  @visibleForTesting
  Future<void> tick() async {
    if (_ticking) return;
    _ticking = true;
    try {
      final now = _now();
      for (final t in store.tasks) {
        if (t.status == TaskStatus.scheduled && !t.dueAt.isAfter(now)) {
          await store.upsert(
            _freshRing(t)
                .copyWith(status: TaskStatus.ringing, ringingSince: () => now),
          );
        }
      }

      var ringing = ringingTask;
      if (ringing == null) {
        _pausedAt = _callEndedAt = null;
        _holdTaskId = _holdStarted = _holdUntil = null;
        if (ringer.isRinging) await _silence();
        return;
      }

      if (!_engineRings) await engine?.ring(ringing);

      if (_holdUntil != null) {
        if (ringing.id == _holdTaskId && now.isBefore(_holdUntil!)) {
          notifyListeners(); // Countdown on the alarm screen.
          return;
        }
        // No verdict in time (or another alarm took over): ring again.
        await _endHold(now);
        ringing = ringingTask!;
      }

      if (_engineRings) {
        await engine!.ring(ringing);
        _enginePausedForCall = await engine!.isPausedForCall();
        // Only for display; the engine computes the real volume itself.
        current = escalationAt(
          ringing.escalation,
          now.difference(ringing.ringingSince!),
          snoozesUsed: ringing.snoozesUsed,
        );
        notifyListeners();
        return;
      }

      if (await _holdForCall(ringing, now)) return;
      ringing = ringingTask!;

      if (!ringer.isRinging) await surface?.onRinging();
      current = escalationAt(
        ringing.escalation,
        now.difference(ringing.ringingSince!),
        snoozesUsed: ringing.snoozesUsed,
      );
      await ringer.apply(current!);
      notifyListeners();
    } finally {
      _ticking = false;
    }
  }

  /// Returns true while the alarm should stay silent because of a call.
  Future<bool> _holdForCall(NagTask ringing, DateTime now) async {
    final inCall = settings.pauseDuringCalls && await _calls.isInCall();
    if (inCall) {
      _callEndedAt = null;
      if (_pausedAt == null) {
        _pausedAt = now;
        await _silence();
      }
      notifyListeners();
      return true;
    }
    if (_pausedAt == null) return false;

    _callEndedAt ??= now;
    final grace = Duration(seconds: settings.callResumeDelaySeconds);
    if (now.difference(_callEndedAt!) < grace) {
      notifyListeners();
      return true;
    }

    // Resume at the loudness it had before the call: time spent on the call
    // doesn't count toward escalation.
    final paused = now.difference(_pausedAt!);
    _pausedAt = _callEndedAt = null;
    await store.upsert(
      ringing.copyWith(ringingSince: () => ringing.ringingSince!.add(paused)),
    );
    return false;
  }

  /// The photo was sent: stay silent up to [wait] for the approver's verdict.
  /// If none comes, ring again at the volume it had when it went quiet.
  Future<void> holdForApproval(NagTask t, Duration wait) async {
    final now = _now();
    // End a call pause here so its time isn't counted twice.
    if (_pausedAt != null) {
      await _shiftStart(t.id, now.difference(_pausedAt!));
      _pausedAt = _callEndedAt = null;
    }
    _holdStarted ??= now; // A re-sent photo keeps the original start.
    _holdTaskId = t.id;
    _holdUntil = now.add(wait);
    await engine?.hold(t.id, _holdUntil!);
    if (!_engineRings) await _silence();
    notifyListeners();
  }

  /// The approver said no: ring again right away, at the same volume.
  Future<void> releaseApprovalHold() async {
    if (_holdStarted != null) await _endHold(_now());
  }

  Future<void> _endHold(DateTime now) async {
    final id = _holdTaskId!;
    final held = now.difference(_holdStarted!);
    _holdTaskId = _holdStarted = _holdUntil = null;
    // Silent time doesn't count toward escalation.
    await _shiftStart(id, held);
    await engine?.releaseHold(id);
    notifyListeners();
  }

  Future<void> _shiftStart(String id, Duration by) async {
    final t = store.byId(id);
    if (t?.ringingSince == null) return;
    await store.upsert(
      t!.copyWith(ringingSince: () => t.ringingSince!.add(by)),
    );
  }

  Future<void> _silence() async {
    current = null;
    await ringer.stop();
    await surface?.onQuiet();
    notifyListeners();
  }

  /// Clears the proofs and approval of a previous ring.
  NagTask _freshRing(NagTask t) => t.copyWith(
    passedProofs: const [],
    pendingApprovalId: () => null,
    pendingApprovalUrl: () => null,
  );

  /// Saves that proof [index] of [t] passed, so it survives the app being
  /// closed, and completes the task once enough proofs have passed.
  Future<void> proofPassed(NagTask t, int index) async {
    final live = store.byId(t.id) ?? t;
    final passed = ({...live.passedProofs, index}.toList()..sort());
    final updated = live.copyWith(passedProofs: passed);
    await store.upsert(updated);
    if (proofSatisfied(live.proofMode, live.proofs.length, passed.length)) {
      await complete(updated);
    }
  }

  /// Remembers (or with nulls, forgets) the photo approval being waited on.
  Future<void> savePendingApproval(NagTask t, String? id, String? url) async {
    final live = store.byId(t.id) ?? t;
    await store.upsert(
      live.copyWith(pendingApprovalId: () => id, pendingApprovalUrl: () => url),
    );
  }

  bool canSnooze(NagTask t) => t.snoozesUsed < t.escalation.maxSnoozes;

  Future<void> snooze(NagTask t) async {
    if (!canSnooze(t)) return;
    // Store first: a tick landing while the engine stops must not see the
    // task still ringing and start it again.
    await store.upsert(
      _freshRing(t).copyWith(
        status: TaskStatus.scheduled,
        dueAt: _now().add(Duration(minutes: t.escalation.snoozeMinutes)),
        ringingSince: () => null,
        snoozesUsed: t.snoozesUsed + 1,
      ),
    );
    await engine?.stop(t.id);
    await tick();
  }

  /// Called once the task's proofs are satisfied.
  Future<void> complete(NagTask t) => _endRing(t, proven: true);

  /// The emergency way out (a glitch, a proof that can't work): stops the
  /// alarm like a proof would, without counting the task as done. A
  /// repeating task moves on to its next time.
  Future<void> cancelRing(NagTask t) => _endRing(t, proven: false);

  Future<void> _endRing(NagTask t, {required bool proven}) async {
    final now = _now();
    final next = nextOccurrence(t.repeat, t.dueAt, now);
    await store.upsert(
      _freshRing(t).copyWith(
        status: next == null ? TaskStatus.done : TaskStatus.scheduled,
        dueAt: next,
        ringingSince: () => null,
        snoozesUsed: 0,
        completedAt: proven ? () => now : null,
      ),
    );
    await engine?.stop(t.id); // After the store; see snooze.
    await tick();
  }

  /// Makes a task ring a few seconds from now, for trying out its settings.
  Future<void> testRing(NagTask t) => store.upsert(
    _freshRing(t).copyWith(
      status: TaskStatus.scheduled,
      dueAt: _now().add(const Duration(seconds: 5)),
      ringingSince: () => null,
    ),
  );

  @override
  void dispose() {
    _ticker?.cancel();
    _syncTimer?.cancel();
    store.removeListener(_scheduleSync);
    settings.removeListener(_scheduleSync);
    super.dispose();
  }
}
