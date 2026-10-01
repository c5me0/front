<p align="center">
  <img src="design-system/brand/cameo-icon.svg" alt="CAMEO app icon" width="128" />
</p>

# CAMEO

**Call, capture, and keep your moments together.**

CAMEO is a shared space for couples. Keep photo memories on a timeline, make voice calls, and revisit the moments you highlighted together. The Flutter app supports Android and iOS, starts in English, and also supports Korean.

[Download the Android demo](https://github.com/c5me0/front/releases/download/v1.0.1-demo/cameo-1.0.1-demo.apk) · [Watch the sign-in clip](readme-assets/login-walkthrough.mp4)

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
./tool/run_deployed.sh -d <device-id>
```

The launcher uses the deployed API at `https://api.cameo.deltalab.dev`. To supply your own app configuration, set `CAMEO_APP_CONFIG` to a local JSON file:

```bash
CAMEO_APP_CONFIG=/absolute/path/app-config.json ./tool/run_deployed.sh -d <device-id>
```

Keep service-account credentials and private configuration outside the app bundle and repository. Source builds use the live API; the downloadable demo APK includes the prepared conversation shown in the recording.

## Brand assets

The app icon uses the original monochrome CAMEO artwork from [System Silica in Figma](https://www.figma.com/design/XkkwFSECjyapJoex9kLeuS/product.cameo--Copy-?node-id=2503-460). The Figma file is used as a read-only design reference.

- [1024 × 1024 app icon](design-system/brand/cameo-icon-1024.png)
- [Original vector artwork](design-system/brand/cameo-icon.svg)
- [White wordmark](design-system/brand/cameo-wordmark-white.svg)

Android includes adaptive and themed icons. iOS icon sizes are generated from the same artwork. To regenerate the platform assets on macOS, run `swift tool/generate_icons.swift` from `apps/flutter`.
