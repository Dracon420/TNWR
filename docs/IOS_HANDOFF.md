# iPhone version: hand-off plan

> **Status (2026-09-27): done.** Built on the Mac and pushed (commit 6833995).
> How it turned out, and what differs from this plan, is in
> [CLAUDE.md](../CLAUDE.md#how-alarms-work-all-platforms). Kept for history.

This is the plan for building the iOS version on the Mac. The Windows and
Android versions (and Alexa, proofs, photo approval) are done; read
[README.md](../README.md) first. **Start a Claude Code session in this repo on
the Mac and point it at this file.**

## Situation and constraints

- Mac: MacBook Neo (A18 Pro, 8 GB), macOS Tahoe 26.6.2. Xcode from the App Store.
- **Free Apple ID only** (no $99 program). Apps signed this way expire after 7
  days, have no push notifications, and **no NFC capability** (NFC proof stays
  Android-only; `hasNfcReader` already returns false on iOS).
- **No iPhone for development.** Build and check the UI in the **iOS Simulator**.
  Real-device testing is done by the beta tester, who installs an unsigned `.ipa`
  with **SideStore/AltStore** (signed with *their* Apple ID, refreshed
  automatically from their Windows PC). So produce an `.ipa`, not just a
  Simulator build.
- Everything must stay **free** (no paid services).
- **Backwards compatible across all iOS versions (required).** The tester's iOS
  version is unknown, and later users will have all kinds. One build must run on
  every iOS version the plugins allow (currently iOS 15.5 / 16, set by ML Kit and
  mobile_scanner) and pick the best alarm method at runtime:

  | iOS | Background alarm | Silent mode |
  |---|---|---|
  | **26+** | AlarmKit system alarms + repeat chain | Rings through silent and Focus |
  | **15.5 to 25** | Time-sensitive local notifications + repeat chain, 30 s escalating sound | Silent mode can mute it, so say so in the setup screen and suggest turning it off at night |

  Every AlarmKit call goes behind `if #available(iOS 26.0, *)`, with the fallback
  in the `else`. Never raise the deployment target just to use a newer API.
- Keep code in the style of the existing code (see `android/.../AlarmService.kt`
  and `lib/alarm/alarm_engine.dart`).

## What iOS needs to do (same behavior as Android)

1. **Background alarms: AlarmKit (iOS 26+).** Third-party alarms that ring
   through silent mode and Focus, with the app closed. Apps **can't** raise the
   volume in the background or block the Stop button, so:
   - Use the bundled `assets/sounds/escalating_30s.wav` (it gets louder by
     itself and turns into the siren) as the alarm sound. Convert to `.caf` if
     AlarmKit needs it, add it to the Runner bundle.
   - **Repeat chain:** for each upcoming task schedule the due-time alarm plus
     repeats every ~2 minutes (e.g. 15 of them). Stopping one does nothing,
     because the next fires. Only a passed proof cancels the chain (`stop`).
   - A secondary "Prove it" button opens the app, which shows the alarm screen
     because the task is due.
   - Fallback for iOS < 26 (see the table above): time-sensitive local
     notifications (`UNNotificationInterruptionLevel.timeSensitive`, iOS 15+) with
     the same repeat chain and the 30 s escalating sound as the notification sound.
     Keep the channel contract identical so Dart doesn't care which is used.
2. **Implement the `nag_alarm/alarms` MethodChannel** in `ios/Runner`, same
   contract as `MainActivity.kt`:
   - `sync(json)`: `{"alarms":[{id,title,dueAt(ms),snoozesUsed,esc:{...}}],
     "pauseDuringCalls", "callResumeDelaySeconds"}`. Replace all scheduled chains.
   - `ring(json)`: task is due while the app is open. Make sure it's ringing.
   - `stop(id)`: proof passed or snoozed. Cancel that task's chain.
   - `hold({id, until})`: a photo approval is pending. Keep the chain silent
     until `until` (ms; 0 = end now) by cancelling pending alarms and
     rescheduling the rest of the chain from `until`. Then it rings at the volume
     it had (see `AppController.holdForApproval` and `AlarmService.kt`).
   - `isPausedForCall`, `setupStatus`, `fixSetup(item)`.
   Then return an `AndroidAlarmEngine`-like `IosAlarmEngine` from `main.dart`
   when `Platform.isIOS`. Decide whether it `ownsRinging`: while the app is
   open, the Dart `Ringer` (audioplayers) can ramp its own volume in-app. That
   is probably simplest: `ownsRinging = false` in the foreground, with AlarmKit
   covering the closed/locked case.
3. **Calls come first** (required, see README): implement
   `nag_alarm/calls` → `isInCall` with `CXCallObserver` (covers phone calls,
   FaceTime, and CallKit apps like WhatsApp). While in a call, don't let chained
   alarms fire: postpone the remaining chain until the call ends plus the
   resume delay.
4. **Setup screen items for iOS** (`SetupItem` in `lib/alarm/alarm_engine.dart`
   is Android-flavored): AlarmKit authorization (`AlarmManager.requestAuthorization`),
   notifications (fallback). Adapt the setup screen per platform.
5. **Info.plist usage strings** (the app is rejected or crashes without them):
   `NSAlarmKitUsageDescription`, `NSCameraUsageDescription` (scan + photo proofs),
   `NSPhotoLibraryUsageDescription` (image_picker requires it), 
   `NSLocationWhenInUseUsageDescription` (place proof), `NSMotionUsageDescription`
   (steps proof). Add `UIBackgroundModes: audio` so an alarm that starts while
   the app is open keeps playing when the phone locks.
6. **Deployment target:** iOS 16+ (ML Kit, mobile_scanner). AlarmKit code behind
   `if #available(iOS 26.0, *)`.
7. **SMS link:** iOS uses `sms:NUMBER&body=...` instead of `?body=`. Check
   `smsUri` in `lib/proof/approval_challenge.dart` on iOS.
8. **Packaging for the tester:** `flutter build ios --release --no-codesign`,
   then zip `Runner.app` inside a `Payload/` folder as `TNWR.ipa`. Write
   `docs/BETA_INSTALL.md` for the tester (SideStore/AltStore on their Windows PC
   plus their own Apple ID, Developer Mode on the iPhone, the 7-day refresh).

## Verify

- `flutter test` passes (32+ tests).
- Simulator: create a reminder, test-ring it, pass each proof type available
  on iOS, check Settings → Phone setup.
- AlarmKit in the Simulator: schedule a test alarm 1 minute out, close the
  app, and confirm the system alarm UI appears and the chain repeats after Stop.
- If possible, also run the Simulator on an older iOS runtime (Xcode →
  Settings → Components) to check the fallback path doesn't crash.
- Hand the `.ipa` to the tester with a checklist (and ask their iOS version first): rings when locked, rings on
  silent, repeats after Stop, stops after proof, pauses during a call.

## Mac setup (once)

1. **Xcode** from the Mac App Store. Open it once; install the iOS platform when asked.
   Then in Terminal: `sudo xcode-select -s /Applications/Xcode.app` and
   `sudo xcodebuild -runFirstLaunch`.
2. Xcode → Settings → **Accounts** → + → your Apple ID.
3. **Homebrew** (brew.sh), then `brew install --cask flutter` and `brew install cocoapods`.
4. `git clone https://github.com/Dracon420/TNWR.git`, then `cd TNWR`, `flutter pub get`,
   and `flutter doctor` (fix anything it flags for iOS).
5. `open -a Simulator`, then `flutter run` to see the app in the iPhone Simulator.
