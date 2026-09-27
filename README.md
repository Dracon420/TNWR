# T.N.W.R. — The Naggy Wife Reminder

**A reminder that won't shut up until the job is actually done.**

T.N.W.R. rings at the time you set, then gets **louder and louder** until you
**prove** you did the task. There's no "dismiss" button. The only ways out are
passing the proof challenge or using one of a few snoozes, and every snooze
makes the next ring start louder.

> **Beta.** Windows and Android are working. See [Platform status](#platform-status).

---

## Contents

- [Features](#features)
- [Platform status](#platform-status)
- [Installing](#installing)
- [How to use it](#how-to-use-it)
  - [Create a reminder](#1-create-a-reminder)
  - [Choose how annoying it is](#2-choose-how-annoying-it-is)
  - [Choose how to prove it's done](#3-choose-how-to-prove-its-done)
  - [When the alarm goes off](#4-when-the-alarm-goes-off)
  - [Managing reminders](#5-managing-reminders)
  - [Settings: theme and phone calls](#6-settings)
- [Sound guide (including hard of hearing)](#sound-guide)
- [Tips and troubleshooting](#tips-and-troubleshooting)
- [Privacy](#privacy)
- [Roadmap](#roadmap)
- [For developers](#for-developers)

---

## Features

- ⏰ **Reminders** that ring once, every day, or on chosen days of the week.
- 📈 **Escalating volume**: starts at the volume you pick and turns itself up
  on a schedule. It controls the **real device volume** (the PC's volume on
  Windows, the alarm volume on Android). It starts at your chosen level even if
  your volume was higher, turns it back up if you lower it, and unmutes. On
  Android it rings even in silent or vibrate mode, like the Clock app's alarms.
  When you're done, your volume goes back to where it was.
- 🔊 **Six alarm sounds**, from a soft chime to "max blast", including
  **low-pitched sounds for people who are hard of hearing**.
- 🔁 **Escalation sound**: switches to a harsher sound if you ignore it too long.
- 💡 **Screen flash**: an optional visual alarm.
- 🧠 **Proof it's done**: math problems, typing a random phrase, and on phones:
  scanning a barcode/QR code, tapping an NFC tag, being at a place, walking a
  number of steps, or a photo of the finished task (checked on the phone).
  Require all proofs, or any one of them.
- 😴 **Limited snoozes**: 0–3 per reminder. Each snooze makes the next ring
  start louder.
- 🔒 **Hard to escape (Windows)**: the alarm takes over the whole screen,
  stays on top, ignores the close button and Alt+F4, pulls itself back if you
  switch away, and can't be quit from the tray while ringing.
- 📳 **Vibrates** on phones, even in silent mode (can be turned off per reminder).
- 📞 **Steps aside for calls**: during a phone call, video chat or
  FaceTime-style call (or, on a PC, while any app uses the microphone or camera),
  a ringing alarm goes quiet. It comes back after the
  call, at the same loudness it had before. The task still has to be proven.
- 🔊 **Alexa**: link an Echo with a 6-digit code. It announces each reminder and keeps repeating it until you prove the task is done in the app.
- 💾 **Survives restarts**: close or kill the app mid-alarm and it picks up
  right where it left off, louder, when it reopens.
- 🌗 **Light, dark, or match-system theme.**
- 🖥️ **Lives in the system tray** on Windows and starts with Windows.

## Platform status

| Platform | Status |
|---|---|
| **Windows** | ✅ Working: everything in the feature list |
| **Android** | ✅ Working: rings on time **even when the app is closed or the phone is locked**, shows over the lock screen, rings through silent/vibrate mode, controls the alarm volume, pauses for calls, survives reboots. Needs a one-time [phone setup](#android) |
| **iPhone** | 🧪 Beta ([install guide](docs/BETA_INSTALL.md)): rings with the app closed. iOS 26+ uses system alarms that ring through silent mode and Focus; iOS 16–25 uses notifications, which silent mode can mute. Repeats every 2 minutes until the task is proven. No NFC proof |
| **Mac** | 🔜 Planned |
| **Alexa** | 🟡 Built, needs one-time setup ([Alexa setup guide](docs/ALEXA_SETUP.md)): your Echo announces the reminder and repeats it every 5 minutes until the task is proven done in the app |

## Installing

### Windows

A ready-to-run download is coming with the first beta release. Until then,
build it from source (see [For developers](#for-developers)) and run
`build\windows\x64\runner\Release\TNWR.exe`.

- The first time you run it, Windows may show **"Windows protected your PC"**
  because the beta isn't code-signed. Click **More info → Run anyway**.
- After the first run of a **release build**, T.N.W.R. starts automatically
  (hidden in the tray) whenever you sign in to Windows, so reminders still fire
  after a reboot.

### Android

Beta testers get an `.apk` file. On the phone, open it and allow
**Install unknown apps** for whichever app you opened it from (Files, Chrome, …).

**One-time phone setup (important).** Android asks you to allow a few things
before an app may ring while it's closed. Open T.N.W.R. and tap the red
**Finish phone setup** banner (or **⚙️ Settings → Phone setup**), then tap
**Fix** on each item until all four have green checks:

| Item | Why |
|---|---|
| **Allow notifications** | The alarm appears as a notification and opens over the lock screen |
| **Allow full-screen alarms** | Lets the alarm fill the screen like an incoming call |
| **Allow alarms & reminders** | Rings at the exact time you set |
| **Set battery to Unrestricted** | Stops the phone (Samsung especially) from putting T.N.W.R. to sleep and skipping alarms |

After that you can close the app. Alarms still ring on time, wake the
phone, and show over the lock screen.

### iPhone

Beta testers install `TNWR.ipa` with AltStore and their own Apple ID. See the
[iPhone beta install guide](docs/BETA_INSTALL.md). Then tap **Finish phone
setup** and allow **Alarms** (iOS 26+) or **Notifications** (iOS 16–25).

iPhone apps can't play sound or raise the volume once they're closed, so
T.N.W.R. schedules a system alarm every 2 minutes until you prove the task is
done. Pressing Stop on one only silences it until the next.

---

## How to use it

### 1. Create a reminder

1. Click **New reminder** (bottom-right).
2. **What needs doing?** Give it a name, like "Take out the trash". The
   optional **Notes** show on the alarm screen too.
3. **When**: tap the date/time to pick when it rings.
4. Choose **Once**, **Daily**, or **Weekly**. For weekly, tap the days
   (M T W T F S S) it should repeat on.
5. Set the options below (or leave the defaults) and click **Save**.

### 2. Choose how annoying it is

| Setting | What it does | Range (default) |
|---|---|---|
| **Starting volume** | How loud it is the moment it goes off | 5–100% (30%) |
| **Gets louder every** | How often the volume goes up by 10% | 5–120 seconds (20 s) |
| **Starting sound** | The sound it rings with first. Press ▶ to preview | Six sounds (Classic beep) |
| **Escalation sound** | The sound it switches to if you keep ignoring it | Six sounds (Siren) |
| **Switch after** | How long before it changes to the escalation sound | Immediately–10 min (2 min) |
| **Flash the screen** | Makes the alarm screen flash, for when sound might not be heard | Off |
| **Vibrate** | Phones: vibrates while ringing, even in silent mode | On |
| **Snoozes allowed** | How many times you can put it off for 5 minutes | 0–3 (1) |

See the [Sound guide](#sound-guide) to pick the right sounds.

### 3. Choose how to prove it's done

Pick at least one:

- **Math problems**: 1–10 problems, Easy / Medium / Hard.
  A wrong answer **resets your count to zero**.
- **Type a random phrase**: 3–20 random words. The phrase can't be copied,
  so you have to type it. Capital letters and extra spaces don't matter.

These need a phone, and you set them up **when you create the reminder**:

| Proof | Setup | To turn the alarm off |
|---|---|---|
| **Scan a barcode or QR code** | Scan any code where the task happens: the barcode on your medicine bottle, a sticker by the washer | Go there and scan that same code |
| **Tap an NFC tag** (Android) | Tap a cheap NFC sticker placed where the task is done | Go there and tap the phone on it |
| **Be at a place** | Stand at the place and switch it on; name it and set a radius (25–500 m) | Be there and tap **I'm here, check in** |
| **Walk steps** | Choose 20–2000 steps | Walk them. Counting starts when you open the challenge |
| **Photo of the finished task** | Photograph what "done" looks like (the empty sink, the made bed) | Take a new photo (camera only, no gallery). The phone checks it shows the same things as the reference photo. Nothing is uploaded |
| **Photo approved by someone** | Enter who approves (e.g. your wife), optionally their mobile number, and how long to wait for them (**Quiet while waiting**, 1–20 min) | Take a photo. Your messaging app opens with a link ready to send. The alarm goes **silent** for the waiting time; if they haven't answered by then, it rings again **at the volume it had**. They tap **Approve** or **Not done** on a web page (no app needed). Approve stops the alarm; Not done brings it back right away. Needs the [online setup](docs/ALEXA_SETUP.md#part-e-photo-approval) |

The automatic photo check runs on the phone, so it's good at "is this the
sink?" but can be fooled by a clever cheater. **Photo approved by someone**
is the strict version: a real person checks.

Then choose **All of these** (every proof must be passed) or **Any one**
(passing one is enough).

*Coming soon: scan a QR code or NFC tag, go to a place, walk a number of
steps, and a photo of the finished task approved by someone you choose.*

### 4. When the alarm goes off

- The alarm **fills the screen** and starts sounding.
- It shows the reminder, how long it's been ringing, and the current volume.
- To turn it off, click a proof (for example **Solve 3 math problems**) and
  complete it. Once enough proofs are passed, the alarm stops and your
  volume goes back to normal.
- **Snooze** (if allowed) silences it for 5 minutes. When it comes back, it
  starts **louder** than before.
- **Emergency off** (for a glitch, or a proof that can't work right now):
  press and **hold "Hold 10 s to cancel without proof" for 10 seconds**, then
  confirm **Cancel alarm**. Letting go early starts the count over. The task
  isn't counted as done: a one-time reminder moves to **Done** (tap it to set
  it again), a repeating one rings again at its next time.
- **What doesn't work (on purpose):** the close button, Alt+F4, switching to
  another window (it comes back within about 3 seconds), turning the volume
  down or muting (it turns it back up within a second), and **Quit** in the
  tray menu.
- If the app gets killed, the alarm resumes when T.N.W.R. is opened again, or
  at the next Windows sign-in. On Android the alarm runs in the background, so
  closing the app, swiping it away or restarting the phone doesn't stop it.
- **On Android** the alarm wakes the phone and appears **over the lock screen**.
  You can solve the proof right there without unlocking. A notification
  ("Ringing until you prove it's done") stays up while it rings; tapping it
  opens the alarm.
- **On a phone call or video chat?** (phones) The alarm goes quiet for the
  whole call and shows **"Paused for your call"**. It comes back 30 seconds
  after you hang up (adjustable in Settings), at the same loudness it had
  before. The call time doesn't make it louder. An alarm that comes due during
  a call waits for the call to end, then starts normally. You can still prove
  the task during the pause to turn it off for good.

**Repeating reminders** move to their next day automatically after you prove
them done. **One-time reminders** move to the **Done** section.

### 5. Managing reminders

- **Edit**: click a reminder in the list. Saving re-arms it, even if it was done.
- **⋮ menu** on a reminder:
  - **Test: ring in 5 seconds**: try out the sound and proof settings.
  - **Delete**: remove it.
- A reminder can't be edited or deleted **while it's ringing**. Prove it first.
- **Closing the window** hides T.N.W.R. to the **system tray** (near the
  clock). Reminders keep working. Click the tray icon to reopen it.
  Right-click it and choose **Quit** to exit completely (not possible while
  an alarm is ringing).

### 6. Settings

Click the ⚙️ gear in the top-right of the main screen.

| Setting | What it does | Default |
|---|---|---|
| **Connect Alexa** | Link an Echo: **Get code**, then say *"Alexa, ask naggy wife to link code …"* ([setup guide](docs/ALEXA_SETUP.md)) | Not connected |
| **Appearance** | System, Light, or Dark theme | System |
| **Pause alarms during calls** | Silences a ringing alarm during phone calls, video chats and FaceTime-style calls. On a PC: whenever an app uses the microphone or camera (Teams, Zoom, Discord…) | On |
| **Resume after call** | How long after a call ends before the alarm comes back | 30 s (0–120 s) |

**Which calls count (Android):** regular phone calls, an incoming call that's
still ringing, and voice/video chats in apps like WhatsApp, Messenger, Google
Meet and Zoom. Android puts the phone's audio into "call mode" for all of
these. T.N.W.R. reads only that, so it needs no phone permission and never sees
who you're talking to. On iPhone, regular calls, FaceTime, and apps that use
the iPhone's built-in call screen (WhatsApp, Messenger, …) count.

---

## Sound guide

| Sound | Loudness | Pitch | Good for |
|---|---|---|---|
| Gentle chime | Soft (≈ −20 dB) | High, 1.3–1.8 kHz | Light sleepers, quiet rooms |
| Classic beep | Loud (≈ −4 dB) | High, 1.3–1.8 kHz | Everyday use |
| Siren | Louder (≈ −1 dB) | Sweeps 0.7–1.6 kHz | Escalation |
| 🦻 Low tone 520 Hz | Loud (≈ −4 dB) | Low | **Hard of hearing**: the tone smoke alarms use to wake hard-of-hearing sleepers |
| 🦻 Bass pulse | Louder (≈ −2 dB) | Deep, 200 Hz | **Hard of hearing**, especially severe high-pitch loss |
| 🦻 Max blast | Loudest (≈ 0 dB, the maximum a sound file can hold) | Low, 520–780 Hz, no gaps | Anyone who sleeps through everything |

**Why low sounds for hearing loss?** The most common kind of hearing loss
(from age or noise) affects **high pitches** first. Many people who can't
hear a high beep hear a low, buzzy square-wave tone clearly.

**Suggested setups**

- *Normal hearing:* Classic beep → Siren.
- *Mild hearing loss:* Low tone 520 Hz → Max blast.
- *Severe hearing loss:* Bass pulse → Max blast, **Flash the screen on**,
  starting volume 70–100%, and a loud external speaker.

The dB figures compare the sounds with each other. Actual loudness depends on
your speakers and system volume. For very hard-of-hearing users, a Bluetooth
speaker or a bed shaker helps more than any sound file.

The screen flash runs at one flash per second, below the three-per-second rate
known to trigger photosensitive seizures.

---

## Tips and troubleshooting

| Problem | Fix |
|---|---|
| **"Windows protected your PC"** | Click **More info → Run anyway**. The beta isn't code-signed yet. |
| **No sound on Windows** | Check that a speaker or headphones is the default playback device. T.N.W.R. unmutes and raises the default device only. |
| **Alarm didn't ring after a reboot** | Launch-at-sign-in only turns on after running a **release** build once. Open T.N.W.R. manually once. |
| **Alarm didn't ring on Android** | Open **⚙️ Settings → Phone setup** and make sure all four items are green. If Do Not Disturb is on, make sure **Alarms** are allowed in its settings (they are by default). |
| **Want to start fresh** | Quit T.N.W.R. and delete `%APPDATA%\com.nagalarm\T.N.W.R\` (holds `tasks.json` and `settings.json`). |
| **Two copies running** | Only run one copy at a time for now. A duplicate would ring twice. |

## Privacy

Everything stays **on your device**: no account, no tracking. Reminders and
settings are plain files in the app's data folder. Only if you **connect
Alexa** are the titles and times of upcoming reminders sent to the server so
your Echo can say them. Only if you use **Photo approved by someone** is that
photo uploaded, and it's deleted as soon as it's approved or rejected. See
[PRIVACY.md](PRIVACY.md).

## Roadmap

- [x] Windows: escalating fullscreen alarm, tray, launch at sign-in
- [x] Sound choices for every hearing level, screen flash, light/dark theme
- [x] Math and typing proofs
- [x] Pause for phone calls and video chats (Android, while the app is open)
- [x] Android: rings through silent mode, controls the alarm volume
- [x] Android: rings with the app closed, over the lock screen, survives reboots
- [x] Android: vibration
- [x] More proofs: barcode/QR, NFC tag, location, step count, on-device photo check
- [x] PC: pause during Teams/Zoom/Discord calls (mic or camera in use)
- [x] Photo approval by a person you choose (link texted to them, no app needed)
- [ ] Sync reminders between phone and PC
- [x] iPhone beta: AlarmKit on iOS 26+, notification fallback on iOS 16–25
- [ ] Mac
- [x] Alexa: announce and repeat until done (needs [setup](docs/ALEXA_SETUP.md))
- [ ] One-click beta downloads

---

## For developers

**Requirements:** Flutter 3.47+ (Dart 3.13). For Windows builds: Visual Studio
2022 Build Tools with **Desktop development with C++**, and Windows
**Developer Mode** on. For Android: Android Studio (SDK) and
`flutter doctor --android-licenses`.

```
flutter pub get
flutter test                      # unit + widget tests
flutter run -d windows            # debug run
flutter build windows --release   # -> build/windows/x64/runner/Release/TNWR.exe
flutter build apk --release       # -> build/app/outputs/flutter-apk/app-release.apk
```

**iPhone** (on a Mac with Xcode, Homebrew `flutter` and `cocoapods`):

```
flutter run                                  # in the iOS Simulator
flutter build ios --release --no-codesign    # -> build/ios/iphoneos/Runner.app
tools/make_ipa.sh                            # -> build/ipa/TNWR.ipa for AltStore
```

Google ML Kit has no arm64 Simulator build, and iOS 26+ Simulators are arm64
only. The Podfile runs `tools/mlkit_arm64_sim.py`, which makes Simulator-only
copies. Device builds and the `.ipa` use Google's originals. The iOS 27
Simulator can't grant AlarmKit permission, so test the system alarms on a real
iPhone.

**Sounds** are generated by code, not recorded. To change them, edit
`tools/gen_sounds.py` and run:

```
python tools/gen_sounds.py
```

It prints each file's loudness in dBFS; keep the tiers in
`lib/core/models.dart` (`AlarmSound`, `Loudness`) in step with it.

**Project layout**

```
lib/core/       models, escalation math, scheduling, local storage, settings, branding
lib/alarm/      sound playback, system-volume control, the ringer, call detection
lib/proof/      proof challenges: math, typing, scan, NFC, location, steps, photo
lib/desktop/    tray icon, fullscreen takeover, launch at sign-in
lib/ui/         screens: reminder list, editor, alarm
windows/runner/ native Windows code: system volume (Core Audio) and
                looping sound playback (PlaySound) in flutter_window.cpp
android/app/src/main/kotlin/...  native Android code:
                AlarmScheduler (alarm-clock alarms), AlarmReceiver (fire, reboot),
                AlarmService (rings in the background: sound, volume, calls),
                AlarmStore (shared data), MainActivity (bridge to Dart, setup)
ios/Runner/AlarmChain.swift  native iPhone code: the repeating alarm chain
                (AlarmKit on iOS 26+, notifications before), call detection
                (CXCallObserver), phone setup
alexa/          Alexa skill: voice model, Node.js code, icons
supabase/       optional backend: SQL + edge functions for Alexa (alexa-*) and photo approval (approval*)
docs/           setup guides; docs/approve/ is the photo-approval web page (GitHub Pages)
tools/          sound and icon generators
test/           tests
```

**How it works:** `AppController` checks once a second. Due reminders become
*ringing* and are saved to disk right away, which is why a ringing alarm
survives restarts. While something rings, `escalationAt()` works out the
target volume and sound from how long it has been ringing, and the `Ringer`
applies it. Before ringing, it asks `CallDetector` whether a call is
active. If so, it stays silent, and on resume it shifts the ringing start time
by the length of the pause, so the call doesn't count toward escalation. On Android, an `AlarmEngine` owns ringing instead: the app sends the list
of upcoming reminders to `AlarmScheduler` whenever it changes, and the
native `AlarmService` does the ringing, escalation and call pausing (the
same rules as the Dart code), so it works with the app closed. The app tells
it to stop once a proof passes. The
app name lives in `lib/core/branding.dart`. The native
display names are set in each platform folder.
