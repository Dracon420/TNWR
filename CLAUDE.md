# Notes for Claude sessions working on T.N.W.R.

Several Claude sessions work on this repo (on the Windows PC and on the Mac).
**Before starting: `git pull`. Before pushing: `git pull --rebase`, run
`flutter analyze` and `flutter test`, and add a line to "Change log" below.**
Keep this file current when you add a feature or change how something works.

User-facing docs: [README.md](README.md). iPhone tester guide:
[docs/BETA_INSTALL.md](docs/BETA_INSTALL.md). Backend: [docs/ALEXA_SETUP.md](docs/ALEXA_SETUP.md).

## Which machine builds what

| Machine | Builds | Notes |
|---|---|---|
| Windows PC | Windows `.exe`, Android `.apk` | See README "For developers" |
| Mac (macOS 27, Xcode 27, Homebrew Flutter + CocoaPods) | iPhone `TNWR.ipa`, iOS Simulator | Free Apple ID only; tester installs with AltStore |

iPhone build: `tools/make_ipa.sh` → `build/ipa/TNWR.ipa` (unsigned; AltStore
signs it with the tester's Apple ID). The `.ipa` is not in git.

## How alarms work (all platforms)

`AppController` ([lib/app_controller.dart](lib/app_controller.dart)) ticks once
a second: marks due tasks ringing, escalates the Dart `Ringer`, handles
snooze / complete / cancel / approval holds / call pauses. It talks to an
optional OS `AlarmEngine` ([lib/alarm/alarm_engine.dart](lib/alarm/alarm_engine.dart))
over the `nag_alarm/alarms` MethodChannel (same contract on every platform:
`sync`, `ring`, `stop`, `hold`, `isPausedForCall`, `setupStatus`, `fixSetup`).

- **Windows**: no engine; Dart rings (tray app, fullscreen takeover).
- **Android**: `AndroidAlarmEngine`, `ownsRinging = true`. Kotlin
  `AlarmService` plays, escalates and handles calls in the background.
- **iPhone**: `IosAlarmEngine`, `ownsRinging = false`. Native code:
  [ios/Runner/AlarmChain.swift](ios/Runner/AlarmChain.swift).
  - iOS apps can't play sound or raise volume once closed, so each upcoming
    reminder gets a **chain of 15 system alarms, 2 minutes apart**. Stop on one
    does nothing (the next follows); only `stop(id)` (proof passed, snooze,
    emergency off) ends it.
  - **iOS 26+**: AlarmKit alarms (ring through silent mode/Focus), with a
    "Prove it" button (`ProveItIntent`) that opens the app.
    **iOS 16–25**: time-sensitive local notifications (silent mode can mute
    them; free Apple ID can't get the time-sensitive entitlement).
    Every AlarmKit call is behind `#available(iOS 26.0, *)`; AlarmKit and
    ActivityKit are weak-linked (`OTHER_LDFLAGS`). Deployment target iOS 16.
  - While the app runs, Dart rings in-app and the chain is pushed ~2 min
    ahead (a dead man's switch: it only fires if the app is killed/suspended).
    Dart calls `ring` every tick while ringing even though it doesn't own
    ringing; native drops a "ringing" id Dart stops confirming (10 s while
    the app is in front).
  - Calls: `CXCallObserver` (also serves `nag_alarm/calls` → `isInCall`).
  - Max 60 pending alarms (iOS notification limit is 64): each reminder gets
    its first alarm, then the soonest get their repeats.
  - Sound: `ios/Runner/escalating_alarm.caf`, a 29.5 s cut of
    `assets/sounds/escalating_30s.wav` (iOS ignores sounds ≥ 30 s).

### Rules that must not break

- **Update the store before `engine.stop()`** in snooze/complete/cancel
  (`AppController._endRing`, `snooze`). Otherwise a tick in between sees the
  task still ringing and re-arms the alarm. Covered by `test/engine_test.dart`
  ("a tick landing during stop…").
- The engine is told about `hold` / `releaseHold` / `ring` whether or not it
  owns ringing (the iPhone chain needs them).
- Phone setup is platform-neutral: engines mix in `PhoneSetup`; the native
  `setupStatus` returns only the items that apply on that phone.

## iOS Simulator gotchas (Mac)

- Google ML Kit (photo proof) has no arm64 Simulator build, and iOS 26+
  Simulators are arm64 only. The Podfile's `post_install` runs
  [tools/mlkit_arm64_sim.py](tools/mlkit_arm64_sim.py), which makes
  Simulator-only xcframework copies inside `ios/Pods`. Device builds are
  unaffected. Don't remove that hook.
- The iOS 27 Simulator can't grant AlarmKit permission (Apple bug), so
  AlarmKit is only testable on a real iPhone. To test the chain logic in the
  Simulator, temporarily make `backend` return `NotificationAlarms()`.
- Debug builds must be started with `flutter run`; launching the installed
  debug app directly shows a blank screen.

## Change log (newest first)

- **2026-09-27** (Windows session) `test/emergency_cancel_test.dart` tearDown
  tolerates a temp file still open: Windows refuses to delete it (macOS
  allows it), which failed the test on the PC. Tests must pass on both
  machines, so avoid leaving files open when a test ends.
- **2026-09-26** (Windows session) Scrolling screens use
  `screenListPadding()` ([lib/ui/insets.dart](lib/ui/insets.dart)): Android 15+
  draws under the navigation bar, and a ListView with explicit padding doesn't
  add room for it. Use it for any new full-screen list.

- **2026-09-27** Emergency off (Mac session): alarm screen button
  "Hold 10 s to cancel without proof" → dialog "Are you sure you wish to
  cancel this alarm?" → `AppController.cancelRing`. Stops like a proof
  (engine + iPhone chain) but leaves `completedAt` unset: one-time → Done,
  repeating → next time. Widget `HoldToCancelButton` in
  `lib/ui/alarm_screen.dart`; tests in `test/emergency_cancel_test.dart`.
- **2026-09-27** iPhone version (Mac session), commit 6833995: everything in
  "How alarms work → iPhone" above; `IosAlarmEngine`, `PhoneSetup` mixin
  with iOS items (`alarmKit`, `notifications`), Info.plist usage strings +
  background audio, iPhone SMS links use `sms:NUMBER&body=`, steps proof
  asks for `Permission.sensors` on iOS (was Android-only, always denied),
  Dart player uses the iOS playback audio category (ignores silent switch).
  Fixed store-before-stop race (also affected Android).
- **2026-09-26** Keep passed proofs when Android closes the app mid-alarm
  (`passedProofs`, pending approval saved on the task).

## Status

- iPhone beta: `.ipa` sent to the tester (iPhone 16 Pro, iOS 26.6.2 → AlarmKit
  path). Waiting for their checklist results (docs/BETA_INSTALL.md).
- Not done: Mac app, sync between phone and PC, one-click beta downloads.
