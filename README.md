<h1 align="center">💊 Pills Reminder</h1>

<p align="center">
  A medication reminder app built with Flutter — Clean Architecture, GetX state management, Hive local storage, and precise local notifications. Works fully offline.
</p>

---

## Table of Contents

- [Features](#features)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Getting Started (Development)](#getting-started-development)
- [Building a Debug APK and Installing on Your Phone](#building-a-debug-apk-and-installing-on-your-phone)
- [Building a Signed Release APK / AAB](#building-a-signed-release-apk--aab)
- [Building for iOS](#building-for-ios)
- [Using the App](#using-the-app)
- [Permissions](#permissions)
- [Troubleshooting](#troubleshooting)
- [Roadmap](#roadmap)
- [Contributing](#contributing)
- [License](#license)

---

## Features

- ⏰ Schedule custom medication reminders
- 📅 One-time, daily, and weekly notifications
- 🔁 Reschedules automatically after device reboot (`BOOT_COMPLETED` receiver)
- 🧠 Clean architecture, feature-first layout
- ⚡ Fast local storage with Hive
- 🔔 Precise local notifications with actionable buttons
- 📱 English and Arabic translations (RTL supported)
- 🌗 Light and dark themes
- ✅ Offline-first (no account needed today — see [Roadmap](#roadmap))

---

## Tech Stack

| Tech | Role |
|------|------|
| Flutter | UI framework |
| GetX | State management, routing, DI, i18n |
| Hive CE | NoSQL local storage |
| flutter_local_notifications | Scheduling & displaying reminders |
| timezone / flutter_timezone | Correct local-time scheduling across zones |
| permission_handler | Runtime permission requests |

---

## Project Structure

```
lib/
├── core/                 # Shared models, styles, utilities, bindings, widgets
│   ├── bindings/         # GetX dependency bindings
│   ├── models/           # Shared Hive-backed entities (notifications, weekday, frequency)
│   ├── styles/           # Theme, strings, sizes, text styles
│   ├── utils/            # Notification helpers, timezone helpers
│   └── widgets/          # Reusable widgets (buttons, dropdowns, app bar)
├── features/
│   ├── medications/      # Add / edit / list medications
│   │   ├── data/         # Hive data source, repo impl, models + adapters
│   │   ├── domain/       # Entities, abstract repos & data sources
│   │   └── presentation/ # Screens, widgets, GetX controllers
│   ├── notifications/    # Notification list, details, background handlers
│   ├── onboarding/       # First-run flow
│   └── settings/         # Theme, language, grouping settings
├── app.dart              # Root MaterialApp with GetX
└── main.dart             # Entry point (Hive init, timezone init, controllers)
```

---

## Prerequisites

You need the following installed on your machine:

1. **Flutter SDK** — stable channel. Install from <https://docs.flutter.dev/get-started/install>.
   - Dart SDK ships with Flutter; this project targets Dart `>=3.8.0 <4.0.0`.
   - After installing, run `flutter doctor` and resolve any red items.
2. **Android toolchain** (for Android builds):
   - Android Studio (installs the Android SDK, platform tools, and an emulator image).
   - A real device with **USB debugging** enabled, or an emulator.
   - JDK 17+ (Android Studio bundles one).
3. **Xcode 15+ and CocoaPods** (only if you want to build for iOS; macOS required).
4. **Git**.

Check everything is ready:

```bash
flutter --version
flutter doctor -v
```

---

## Getting Started (Development)

```bash
# 1. Clone
git clone https://github.com/ahmedwaked90/pills-reminder-flutter.git
cd pills-reminder-flutter

# 2. Install dependencies
flutter pub get

# 3. (Only if you change the Hive models) regenerate adapters
dart run build_runner build --delete-conflicting-outputs

# 4. Run on a connected device or emulator
flutter devices           # list available devices
flutter run               # runs on the first available device
# or target a specific one:
flutter run -d <device-id>
```

Static analysis and tests:

```bash
flutter analyze
flutter test
```

---

## Building a Debug APK and Installing on Your Phone

This is the fastest way to get the app on your own Android phone without setting up signing keys or the Play Store.

### Option A — Direct install over USB (recommended)

1. On your phone: **Settings → About phone → tap "Build number" 7 times** to enable Developer Options.
2. **Settings → Developer options → enable USB debugging**.
3. Connect the phone to your computer with a USB cable. Confirm the "Allow USB debugging" prompt on the phone.
4. From the project root:

   ```bash
   flutter devices          # verify your phone appears
   flutter run --release    # builds release and installs it directly
   ```

   Press `q` in the terminal when you want to detach — the app stays installed on the phone.

### Option B — Build an APK, then sideload

Use this when the phone isn't connected to your computer (e.g. you want to share the APK, or install over Wi-Fi via a file transfer).

```bash
# Build a single APK (simplest):
flutter build apk --release

# Output:
# build/app/outputs/flutter-apk/app-release.apk
```

Transfer `app-release.apk` to your phone (USB, Google Drive, Telegram to yourself, email, etc.), open it on the phone, and tap **Install**. You'll likely need to grant your file manager permission to "install unknown apps" the first time.

Smaller downloads (one APK per CPU architecture):

```bash
flutter build apk --release --split-per-abi
# Outputs app-armeabi-v7a-release.apk, app-arm64-v8a-release.apk, app-x86_64-release.apk
# Most modern phones need: app-arm64-v8a-release.apk
```

> **Note on signing**: Without a `keystore.properties` file (see next section), `flutter build apk --release` will fall back to the debug signing key. That APK installs fine on your own phone but **cannot be published to Play Store** and cannot be updated over the top of a Play-signed install.

---

## Building a Signed Release APK / AAB

Do this when you want a proper release build (e.g. to publish, or to share a stable long-lived APK).

### 1. Generate an upload keystore (one time)

```bash
keytool -genkey -v \
  -keystore ~/pills-reminder-upload-key.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

Keep the generated `.jks` file **safe and backed up** — if you lose it, you can't push updates to Play under the same signing identity.

### 2. Create `android/keystore.properties`

This file is read by `android/app/build.gradle.kts` (it's already wired up — see lines 17–42 of that file). **Do not commit it** (the project `.gitignore` should exclude it; double-check).

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=/absolute/path/to/pills-reminder-upload-key.jks
```

### 3. Build

```bash
# Signed APK (for direct install / sideload):
flutter build apk --release

# Signed App Bundle (for Play Store upload):
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

### 4. (Optional) Bump the version

Edit `pubspec.yaml`:

```yaml
version: 1.6.0+7     # <versionName>+<versionCode>
```

`versionName` is what users see; `versionCode` must increase with every upload to Play.

---

## Building for iOS

Requires macOS with Xcode 15+ installed.

```bash
cd ios
pod install           # first time, or after changing iOS plugins
cd ..
open ios/Runner.xcworkspace
```

In Xcode: set your **Team** and **Bundle Identifier** under *Signing & Capabilities*, then build to a connected iPhone or simulator. Command-line equivalent:

```bash
flutter build ios --release          # unsigned (needs Xcode to sign & deploy)
flutter run -d <iphone-device-id>    # build + install on a connected iPhone
```

---

## Using the App

1. **First launch** — pick your language (English / Arabic) on the onboarding screen.
2. **Add a medication** — tap the floating **+** button on the main screen.
   - Name of the medication
   - Frequency: once, daily, or weekly (pick the weekdays)
   - Time(s) of day to be reminded
3. **Edit or delete** — tap any medication in the list to open it, then edit or delete.
4. **Notifications** — the Notifications tab shows upcoming/past reminders. Notification actions (e.g. "Taken") are available from the notification itself.
5. **Settings** — switch theme (light / dark / system), switch language, and toggle grouped notifications.
6. **After reboot** — a `BOOT_COMPLETED` receiver reschedules your reminders automatically; you don't need to open the app.

---

## Permissions

On Android the app requests, at runtime where required:

| Permission | Why |
|---|---|
| `POST_NOTIFICATIONS` | Show reminders (required on Android 13+). |
| `SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM` | Fire reminders at the exact time (required on Android 12+). |
| `RECEIVE_BOOT_COMPLETED` | Re-schedule reminders after you restart the phone. |

If a reminder doesn't fire at the exact time, check that both notification permission **and** "Alarms & reminders" (exact-alarm permission) are granted in **Settings → Apps → Pills Reminder**.

On iOS the app requests standard local-notification permission on first use.

---

## Troubleshooting

**`flutter.sdk not set in local.properties`** — run `flutter pub get` once from the project root; it writes `android/local.properties`. If still missing, create it with `sdk.dir=/path/to/Android/Sdk` and `flutter.sdk=/path/to/flutter`.

**`Execution failed for task ':app:...' NDK not configured`** — install the NDK version pinned in `android/app/build.gradle.kts` (`27.0.12077973`) via Android Studio → SDK Manager → SDK Tools → NDK (side by side).

**Notifications don't fire** — on Android 12+ open *Settings → Apps → Pills Reminder → Alarms & reminders* and allow it. On Android 13+ allow notifications. Battery optimization / "Don't optimize" for this app also helps on aggressive OEMs (Xiaomi, Huawei, Oppo, Samsung).

**Build runner errors after editing a Hive model** — delete generated files and re-run:
```bash
dart run build_runner build --delete-conflicting-outputs
```

**`CocoaPods could not find compatible versions`** (iOS) — `cd ios && pod repo update && pod install`.

**Install blocked by "Unknown apps"** (sideloading) — in Android settings, grant "Install unknown apps" to the app you're installing from (Files, Chrome, Drive…).

---

## Roadmap

- 🔐 **Accounts + cloud sync** — planned next: email/password login backed by a Laravel API, so medications and schedules sync across devices. Not yet implemented; the app is currently local-only.
- 📊 Adherence stats
- ⌚ Wear OS companion

---

## Contributing

PRs welcome — bug fixes, new languages, UI polish. Before opening a PR:

```bash
flutter analyze
flutter test
```

---

## License

MIT — see [LICENSE](LICENSE).
