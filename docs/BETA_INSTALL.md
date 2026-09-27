# Installing the iPhone beta

T.N.W.R. isn't on the App Store yet. You install it yourself from a file,
`TNWR.ipa`, with the free **AltStore** app and **your own Apple ID**. It costs
nothing. The catch: Apple makes apps installed this way stop opening after
**7 days** unless they're refreshed. AltStore refreshes them for you from your
Windows PC (details below).

**Before you start, tell us your iOS version** (Settings → General → About →
iOS Version). How the alarm works depends on it:

| Your iOS | How T.N.W.R. rings when the app is closed |
|---|---|
| **26 or later** | Real system alarms, like the Clock app. They ring through silent mode and Focus. |
| **16 to 25** | Notifications with the alarm sound. **Silent mode (and Focus) can mute them**, so leave silent mode off at night. |
| **15 or older** | Not supported. |

While T.N.W.R. is open (or ringing on the lock screen), it rings itself on any
version and gets louder until you prove the task is done.

---

## One-time setup (about 20 minutes)

You need: your iPhone, its USB cable, a Windows PC, and your Apple ID.

### 1. On the PC: install AltServer

1. Install **iTunes** and **iCloud** from **apple.com** (the download links on
   Apple's site, *not* the Microsoft Store versions; AltServer can't use those).
   Open iCloud once and sign in.
2. Download **AltServer for Windows** from **[altstore.io](https://altstore.io)**
   and install it. It lives in the system tray (bottom-right, near the clock).

### 2. Put AltStore on the iPhone

1. Plug the iPhone into the PC and tap **Trust** on the phone if asked.
   In iTunes, click the phone icon and tick **Sync with this iPhone over Wi-Fi**,
   then **Apply**. This lets AltServer refresh the app later without the cable.
2. Click the AltServer tray icon → **Install AltStore** → your iPhone. Sign in
   with your Apple ID when asked. (It's sent only to Apple.)
3. On the iPhone: **Settings → General → VPN & Device Management** → tap your
   Apple ID → **Trust**.
4. Turn on **Developer Mode**: **Settings → Privacy & Security → Developer
   Mode** → on, then restart the phone and tap **Turn On** when it asks.

### 3. Install T.N.W.R.

1. Get `TNWR.ipa` onto the iPhone: AirDrop it, or save it to **Files** (for
   example from an email or iCloud Drive).
2. Open **AltStore** → **My Apps** → **+** (top left) → pick `TNWR.ipa`.
   Keep the PC on and AltServer running; this takes a minute.
3. Open **T.N.W.R.**

### 4. Set up T.N.W.R.

Tap the red **Finish phone setup** banner (or **⚙️ Settings → Phone setup**)
and tap **Fix**:

- **iOS 26+: Allow alarms.** Tap **Allow** when iOS asks. If you tapped Don't
  Allow by mistake, Fix opens Settings. Turn on **Alarms** there.
- **iOS 16–25: Allow notifications.** Tap **Allow**. Then check **Settings →
  Notifications → T.N.W.R.**: **Sounds** on, and **Lock Screen** on.

The first time you use a proof, iOS asks for the camera (scan and photo
proofs), location (place proof), or Motion & Fitness (steps proof). Tap Allow.
The **NFC tag** proof isn't available on iPhone.

---

## Keeping it working: the 7-day refresh

Apps installed with a free Apple ID stop opening after 7 days. To prevent that:

- Keep **AltServer running** on the PC (it starts with Windows) and the phone on
  the **same Wi-Fi**. AltStore refreshes in the background. You can also open
  **AltStore → My Apps → Refresh All** any time.
- If T.N.W.R. says it's expired, plug the phone into the PC, open AltStore and
  tap **Refresh All**. Your reminders are kept.

A free Apple ID can have **3 sideloaded apps** at a time (AltStore counts as one).

---

## What to test (please report back)

Tell us your **iPhone model and iOS version**, then try each of these with a
reminder set 2 minutes ahead. Tick what worked and describe what didn't:

- [ ] **Rings when locked**: lock the phone and wait. Does it ring?
- [ ] **Rings with the app closed**: swipe T.N.W.R. away in the app switcher,
      then wait. (iOS 16–25: a notification with the alarm sound.)
- [ ] **Rings on silent**: turn on silent mode and repeat. iPhone 15 Pro and
      later: hold the Action button, or use the bell in Control Center. Older
      iPhones: the switch on the side. *(Expected to ring on iOS 26+ only.)*
- [ ] **Repeats after Stop**: stop or dismiss the alarm without proving the
      task. It should come back about 2 minutes later, and keep coming back.
- [ ] **"Prove it" button** (iOS 26+): opens T.N.W.R. on the alarm screen.
- [ ] **Stops after proof**: pass the proof. Nothing should ring for that
      reminder afterwards.
- [ ] **Snooze**: comes back after the snooze time, louder.
- [ ] **Pauses during a call**: be on a phone or FaceTime/WhatsApp call when it
      comes due. It should wait until about 30 s after you hang up.
      (Most reliable while T.N.W.R. is open.)
- [ ] **Each proof type** you can: math, typing, scan a code, photo, place, steps.

Screenshots or a short screen recording of anything odd help a lot.
