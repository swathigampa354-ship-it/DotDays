<p align="center">
  <img src="assets/icons/icon.png" width="120" alt="DotDays Icon"/>
</p>

<h1 align="center">DotDays</h1>

<p align="center">
  <strong>Life in Dots — Every dot is a day of your life.</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.5+-02569B?logo=flutter" alt="Flutter"/>
  <img src="https://img.shields.io/badge/Dart-3.5+-0175C2?logo=dart" alt="Dart"/>
  <img src="https://img.shields.io/badge/Platform-Android-3DDC84?logo=android" alt="Android"/>
  <img src="https://img.shields.io/badge/License-MIT-green" alt="License"/>
</p>

<p align="center">
  A beautifully minimal Android wallpaper app that visualizes your life as a grid of dots.<br/>
  Each dot represents a unit of time — days, weeks, or goal progress — turning your phone's wallpaper into a daily reminder of how you spend your time.
</p>

---

## 📸 Screenshots

<p align="center">
  <img src="screenshots/ss1.png" width="250" alt="Screenshot 1"/>
  &nbsp;&nbsp;&nbsp;
  <img src="screenshots/ss2.png" width="250" alt="Screenshot 2"/>
  &nbsp;&nbsp;&nbsp;
  <img src="screenshots/ss3.png" width="250" alt="Screenshot 3"/>
</p>

---

## ✨ Features

### 🗓️ Three Calendar Modes
- **Year View** — 365 dots representing each day of the current year
- **Life View** — Every week of your entire life (birth to expected lifespan) as a single dot
- **Goal View** — Track progress toward any custom goal with a countdown grid

### 🎨 Live Wallpaper
- Set the dot grid as your **home screen**, **lock screen**, or **both**
- Wallpaper updates **automatically every day** — no need to open the app
- Consistent rendering between preview and actual wallpaper

### ⚙️ Auto-Update Engine
- Background wallpaper updates via an **exact alarm** at midnight (`android_alarm_manager_plus`)
- Survives **phone reboots** with a native `BootReceiver`
- Requests **battery optimization exemption** for reliable background execution
- Works on aggressive OEMs (Xiaomi, Realme, Samsung, OPPO)

### 🎯 Customization
- Choose your **lived dot color** (accent color for completed days)
- Pick your **date of birth** and **expected lifespan** for the Life view
- Set custom **goal names** with start and end dates

---

## 🏗️ Architecture

```
lib/
├── core/              # Theme, constants, design tokens
├── features/
│   ├── home/          # Main home screen
│   ├── onboarding/    # First-launch setup flow
│   ├── year/          # Year calendar configuration
│   ├── life/          # Life calendar configuration
│   ├── goal/          # Goal tracking configuration
│   ├── wallpaper/     # Wallpaper preview & application
│   └── settings/      # App settings screen
├── services/
│   ├── background_service.dart          # Midnight exact-alarm scheduling
│   ├── headless_wallpaper_renderer.dart # Canvas-based wallpaper generation
│   ├── wallpaper_service.dart           # System wallpaper application
│   ├── wallpaper_auto_updater.dart      # App-launch fallback updater
│   ├── battery_optimization_service.dart # Battery exemption requests
│   └── storage_service.dart             # SharedPreferences wrapper
├── shared/            # Models, providers, shared widgets
├── routes/            # GoRouter navigation
└── main.dart          # App entry point
```

---

## 🛠️ Tech Stack

| Layer | Technology |
|-------|-----------|
| **Framework** | Flutter 3.5+ |
| **State Management** | Riverpod |
| **Navigation** | GoRouter |
| **Background Tasks** | android_alarm_manager_plus |
| **Storage** | SharedPreferences |
| **Wallpaper** | wallpaper_manager_flutter |
| **Rendering** | dart:ui Canvas API (headless) |

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK `3.47.7` (pinned in CI — `.github/workflows/build-apk.yml`)
  and Dart `^3.5.0`
- JDK 17 or newer
- Android SDK (platform 36, build-tools 36)
- An Android device or emulator running Android 7.0+ (Android 10 / API 29+ is
  the tested target)

### Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/DotDays.git
cd DotDays

# Install dependencies
flutter pub get

# Run the app
flutter run

# Build release APK
flutter build apk --split-per-abi
```

### Generate App Icon

```bash
dart run flutter_launcher_icons
```

The icon source file is at `assets/icons/icon.png`.

---

## 📱 How It Works

1. **Onboarding** — Choose your calendar type (Year/Life/Goal) and enter your details
2. **Preview** — See how the dot grid wallpaper will look on your phone
3. **Apply** — Set the wallpaper to your home screen, lock screen, or both
4. **Auto-Update** — The app registers a background task that regenerates the wallpaper daily with the updated dot count
5. **Boot Survival** — After phone restart, a native `BootReceiver` ensures the background task is re-registered

---

## 🔧 Background Task Reliability

DotDays uses multiple strategies to ensure the wallpaper updates reliably:

| Strategy | Purpose |
|----------|---------|
| **Background Task** | Exact midnight alarm via `android_alarm_manager_plus` |
| **Native Pre-Check** | `AlarmManager` at 23:50 refreshes wallpaper IDs |
| **BootReceiver** | Re-registers task after phone reboot |
| **Battery Optimization Exemption** | Prevents OS from killing the background task |
| **App-Launch Fallback** | Checks and updates wallpaper when app is opened |
| **Day-Change Guard** | Only regenerates wallpaper once per day |

---

## 🤝 Android 10+ Compatibility

DotDays targets modern Android without dropping older devices or 32-bit
hardware.

| Property | Value |
|----------|-------|
| **minSdk** | 24 (Android 7.0) — installs on Android 10 (API 29) and everything newer |
| **targetSdk** | 36 (Android 16) |
| **compileSdk** | 36 |
| **CPU ABIs** | `arm64-v8a` (64-bit ARM), `armeabi-v7a` (32-bit ARM), `x86_64` |
| **Build toolchain** | Flutter 3.47.7 · Gradle 8.14 · AGP 8.11.1 · Kotlin 2.2.20 · JDK 17 |

### What the compatibility pass changed

These were the only source changes — behaviour, screens and features are
untouched.

1. **`PreCheckReceiver.kt` — exact-alarm crash on Android 12+ (fixed).**
   `scheduleNext()` called `AlarmManager.setExactAndAllowWhileIdle()`
   unguarded. On Android 12+ (API 31) exact alarms require
   `SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM`, and the user can revoke that
   permission at any time from *Settings → Alarms & reminders*. Scheduling
   without it throws `SecurityException`; in `onReceive()` the trailing
   `scheduleNext()` call was outside the `try` block, so a revocation crashed
   the app during the nightly wallpaper pre-check. It now checks
   `canScheduleExactAlarms()` first, falls back to an inexact
   allow-while-idle alarm, and never lets a scheduling error escape the
   receiver.
2. **`background_service.dart` — start-up crash on scheduling failure (fixed).**
   `scheduleDaily()` is `await`ed from `main()` with no error handling, so any
   alarm-scheduling failure would abort start-up before `runApp()`. It now
   retries with an inexact alarm and is guaranteed not to throw.
3. **`.github/workflows/build-apk.yml` — reproducible, verifiable builds.**
   Flutter is pinned to 3.47.7, `flutter test` runs before the build, a new
   step prints each APK's `minSdk`/`targetSdk`/ABI set as build evidence, and
   release tags are unique per run (`v<version>-<date>-r<run>`).

Everything else — the 365-dot wallpaper, the three calendar modes
(Year/Life/Goal), the daily auto-update, boot re-scheduling, battery-optimization
opt-in, the OEM wallpaper-preserving workaround and all settings — behaves
exactly as before.

> **Note on "live wallpaper":** DotDays renders a wallpaper image
> (1080×2340 PNG) and applies it with `WallpaperManager`, then regenerates it
> once the day changes. It does **not** use an `android.service.wallpaper.WallpaperService`,
> so there is no live-wallpaper service or `<meta-data>` wallpaper metadata to
> maintain. That design was preserved rather than replaced.

### Verifying a build yourself

```bash
# Which SDK levels and ABIs did an APK actually get?
AAPT2=$(ls "$ANDROID_HOME"/build-tools/*/aapt2 | tail -1)
for apk in build/app/outputs/flutter-apk/*.apk; do
  echo "=== $apk ==="
  "$AAPT2" dump badging "$apk" | grep -E "^package:|^sdkVersion|^targetSdkVersion:|^native-code:"
done

# Signature + alignment
"$ANDROID_HOME"/build-tools/*/apksigner verify --verbose build/app/outputs/flutter-apk/DotDays.apk
zipalign -c -v 4 build/app/outputs/flutter-apk/DotDays.apk
```

### Release signing

Release APKs are signed with the **debug key** (`signingConfig` for the release
build type), which is what the stock Flutter template does so
`flutter build apk --release` works out of the box. Two consequences worth
knowing:

- Every CI run generates a fresh runner keystore, so consecutive releases are
  **not** installable over one another. Uninstall DotDays before installing a
  newer APK.
- To make upgrade-in-place installs possible, add your own keystore and a
  `key.properties` (both are already git-ignored) and point the release build
  type at it.

---

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

---

<p align="center">
  Made with ❤️ and Flutter<br/>
  <strong>Every dot counts. Make them matter.</strong>
</p>
