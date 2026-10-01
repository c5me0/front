<p align="center">
  <img src="design-system/brand/cameo-icon.svg" alt="CAMEO app icon" width="128" />
</p>

# CAMEO

**Call, capture, and keep your moments together.**

CAMEO is a shared space for couples. Keep photo memories on a timeline, make voice calls, and revisit the moments you highlighted together. The Flutter app supports Android and iOS, starts in English, and also supports Korean.

<p align="center">
  <a href="readme-assets/cameo-intro-music.mp4?raw=true">
    <picture>
      <source media="(prefers-reduced-motion: reduce)" srcset="readme-assets/cameo-intro-preview.jpg" />
      <img src="readme-assets/cameo-intro-preview.gif" alt="CAMEO introduction — download the full video with music" width="320" />
    </picture>
  </a>
</p>

[Download the full CAMEO introduction with music](readme-assets/cameo-intro-music.mp4?raw=true) — 36 seconds. The animated preview is silent; the MP4 includes the original soundtrack.

[Download the Android demo](https://github.com/c5me0/front/releases/download/v1.0.1-demo/cameo-1.0.1-demo.apk) · [Watch the sign-in clip](readme-assets/login-walkthrough.mp4)

**Using an iPhone? You need a Mac with Xcode and must build the iOS app from source.** Follow the [iOS build guide](#build-and-run-on-ios-mac-required) below.

## Get started

1. Download and install the Android demo APK on a device running Android 7.0 or later.
2. Open **CAMEO** and tap **Continue with phone**.
3. Select **South Korea (+82)** for the demo numbers below.
4. Enter a demo phone number and tap **Send code**.
5. Enter **`000000`** to sign in. **The OTP is fixed to `000000` in the demo environment; you do not need to wait for an SMS.**

| Demo account | Phone number | Enter without separators |
| --- | --- | --- |
| Jamie | `010-0000-0000` | `01000000000` |
| Alex | `010-0000-0001` | `01000000001` |

Jamie and Alex are already connected as a couple and have a shared photo collection. Use one account on each device to explore the shared experience. The demo APK also includes a curated **September 30, 2026** conversation, **“Coffee, books & a quiet Sunday,”** with two highlights.

## Sign-in walkthrough

The clip below is taken from the recorded Android demo: welcome screen → phone number → fixed OTP → Memories.

[![CAMEO phone sign-in and OTP walkthrough](readme-assets/login-walkthrough.gif)](readme-assets/login-walkthrough.mp4)

[Download the MP4](readme-assets/login-walkthrough.mp4)

## What to explore

- **Memories:** shared photos, favorites, photo details, and a timeline of your time together.
- **Calls:** voice calls, shared photos, recordings, and highlighted conversations.
- **Storage:** start with **1 GB** shared storage; the **US$4.99 monthly** plan increases it to **50 GB**.
- **Languages:** English by default, with Korean available in Settings.

Purchases in this demo use the **RevenueCat Test Store**. The purchase confirmation is a sandbox flow and does not charge real money. The prepared September 30 conversation is sample content for the demo APK.

## Run from source

The verified toolchain is **Flutter 3.35.6 / Dart 3.9.2**, with an Android SDK or Xcode for the target platform.

```bash
cd apps/flutter
./tool/flutter.sh pub get
./tool/flutter.sh devices
./tool/run_deployed.sh -d "<device-id>"
```

The launcher uses the deployed API at `https://api.cameo.deltalab.dev`. To supply your own app configuration, set `CAMEO_APP_CONFIG` to a local JSON file:

```bash
CAMEO_APP_CONFIG=/absolute/path/app-config.json ./tool/run_deployed.sh -d "<device-id>"
```

Keep service-account credentials and private configuration outside the app bundle and repository. Source builds use the live API; the downloadable demo APK includes the prepared conversation shown in the recording.

## Build and run on iOS (Mac required)

**You must use a Mac running macOS and build CAMEO locally to run it on an iPhone or iOS Simulator.** The downloadable APK is for Android. This project uses **Flutter 3.35.6 / Dart 3.9.2** and targets **iOS 13.0 or later**. Local iOS builds used **Xcode 26.2** and **CocoaPods 1.16.2**.

### 1. Prepare your Mac

Install **Xcode 26.2** from [Apple's developer downloads](https://developer.apple.com/download/all/) and install [Homebrew](https://brew.sh/). Keep Xcode at `/Applications/Xcode.app`, then run these commands in Terminal to configure Xcode and install [CocoaPods](https://formulae.brew.sh/formula/cocoapods). Review and accept the Xcode license when prompted.

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
sudo xcodebuild -license
xcodebuild -downloadPlatform iOS
brew install cocoapods
pod --version
```

Download **Flutter 3.35.6** from the [Flutter SDK archive](https://docs.flutter.dev/install/archive). Choose **macOS arm64** for an Apple Silicon Mac or **macOS x64** for an Intel Mac. Extract the SDK to `~/development/flutter`, or adjust the SDK path in the next step to match your installation.

### 2. Download the project and install dependencies

```bash
git clone https://github.com/c5me0/front.git cameo
cd cameo/apps/flutter
export CAMEO_FLUTTER_SDK="$HOME/development/flutter"
./tool/flutter.sh --version
./tool/flutter.sh precache --ios
./tool/flutter.sh doctor -v
./tool/flutter.sh pub get
pod install --project-directory=ios
```

If you already cloned the repository, start from its `apps/flutter` directory and skip the clone command. Resolve any Xcode or CocoaPods issues reported by `doctor` before continuing. Keep using this Terminal window; in a new window, set `CAMEO_FLUTTER_SDK` again. All commands below run from **`apps/flutter`**.

### 3. Build and run in the iOS Simulator

Open Simulator, choose an iPhone from **File → Open Simulator**, and wait for it to boot:

```bash
open -a Simulator
./tool/flutter.sh devices
```

Copy the iOS simulator's device ID from the list and replace `<simulator-id>` below:

```bash
./tool/run_deployed.sh -d "<simulator-id>"
```

This command **builds, installs, and opens** CAMEO using the deployed API. A simulator build does not need an Apple signing team. Sign in with a [demo account](#get-started) and OTP **`000000`**.

To build the simulator app without launching it:

```bash
./tool/build_ios_sim.sh \
  --dart-define=CAMEO_API_BASE_URL=https://api.cameo.deltalab.dev
```

The output is **`apps/flutter/build/ios/iphonesimulator/Runner.app`**, relative to the repository root. This build runs in Simulator; use the next steps for an actual iPhone.

### 4. Build and run on an iPhone

1. Connect and unlock your iPhone, then tap **Trust** when asked to trust the Mac. On iOS 16 or later, enable **Settings → Privacy & Security → Developer Mode** and complete the restart prompt.
2. Open the workspace from Terminal:

   ```bash
   open ios/Runner.xcworkspace
   ```

3. In Xcode, add your Apple account under **Xcode → Settings → Accounts**. Select the **Runner** target, open **Signing & Capabilities**, enable **Automatically manage signing**, and choose your development team.
4. Use `com.cameo.cameo` if your team owns that Bundle Identifier, or choose a unique identifier registered to your team. This project includes the **Push Notifications** entitlement, so its device build needs an Apple Developer Program team and a provisioning profile that supports this capability. A free Personal Team cannot sign the current push-enabled configuration. See [Apple's supported capabilities](https://developer.apple.com/help/account/reference/supported-capabilities-ios).
5. Select the connected iPhone in Xcode and let it finish preparing the device and signing assets. Return to Terminal:

   ```bash
   ./tool/flutter.sh devices
   ./tool/run_deployed.sh -d "<iphone-device-id>"
   ```

Replace `<iphone-device-id>` with the connected iPhone's ID. The command builds, signs, installs, and launches the app. Follow any device trust prompts, then use the same demo phone numbers and **`000000`** OTP.

To create a signed device build without installing it, complete the signing setup above and run:

```bash
./tool/flutter.sh build ios --debug \
  --dart-define=CAMEO_API_BASE_URL=https://api.cameo.deltalab.dev
```

The output is **`apps/flutter/build/ios/iphoneos/Runner.app`**, relative to the repository root. Use `run_deployed.sh` to install and launch it during development. Push delivery also requires backend APNs configuration that matches your app's Bundle Identifier.

### Sandbox purchases in a source build

To try checkout, obtain the project's public RevenueCat Test Store configuration and pass its local JSON file through `CAMEO_APP_CONFIG`, as shown under [Run from source](#run-from-source). The launcher also automatically loads `.local/app-sandbox.json` at the repository root when present; that file is excluded from Git. Login and free storage work without the billing configuration. Use the **debug** commands above: this app deliberately disables Test Store keys in release builds.

For either build-only command, append `--dart-define-from-file=/absolute/path/app-config.json` to include that configuration. `CAMEO_APP_CONFIG` is read by `run_deployed.sh`, not by the build commands.

The setup and signing steps follow Flutter's [iOS setup guide](https://docs.flutter.dev/platform-integration/ios/setup) and [iOS build guide](https://docs.flutter.dev/deployment/ios).

## Brand assets

The app icon uses the original monochrome CAMEO artwork from [System Silica in Figma](https://www.figma.com/design/XkkwFSECjyapJoex9kLeuS/product.cameo--Copy-?node-id=2503-460). The Figma file is used as a read-only design reference.

- [1024 × 1024 app icon](design-system/brand/cameo-icon-1024.png)
- [Original vector artwork](design-system/brand/cameo-icon.svg)
- [White wordmark](design-system/brand/cameo-wordmark-white.svg)

Android includes adaptive and themed icons. iOS icon sizes are generated from the same artwork. To regenerate the platform assets on macOS, run `swift tool/generate_icons.swift` from `apps/flutter`.
