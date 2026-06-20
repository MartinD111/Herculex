# Release checklist

Herculex is on-device only, so there is no backend to provision. The remaining
work to ship is platform packaging and store submission.

## 1. Confirm the application / bundle ID

The placeholder `com.example.*` has been replaced with **`com.ams.herculex`** in:

- `android/app/build.gradle.kts` (`namespace`, `applicationId`)
- `android/app/src/main/kotlin/com/ams/herculex/MainActivity.kt` (package)
- `ios/Runner.xcodeproj/project.pbxproj` (`PRODUCT_BUNDLE_IDENTIFIER`)

> ⚠️ The application ID is **permanent** once published. If `com.ams.herculex`
> is not the reverse form of a domain you control, change it now (search & replace
> the three locations above) before the first upload.

## 2. Android release signing

A keystore is **not** committed. The build reads `android/key.properties` when
present and otherwise falls back to debug signing (so `flutter run --release`
still works locally). To produce an uploadable build:

```bash
# Generate an upload keystore (keep the .jks and passwords safe & backed up)
keytool -genkey -v -keystore ~/herculex-upload.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Create `android/key.properties` (git-ignored):

```properties
storePassword=••••••
keyPassword=••••••
keyAlias=upload
storeFile=/absolute/path/to/herculex-upload.jks
```

Then:

```bash
flutter build appbundle --release   # → build/app/outputs/bundle/release/app-release.aab
```

R8 shrinking/obfuscation is enabled; keep rules live in
`android/app/proguard-rules.pro`. Smoke-test the release build on a device before
uploading (R8 can strip code the rules miss).

## 3. iOS release signing

Open `ios/Runner.xcworkspace` in Xcode → Signing & Capabilities → select your
team and a provisioning profile for `com.ams.herculex`, then:

```bash
flutter build ipa --release
```

## 4. Permissions / privacy

Declared permissions and their justification (needed for store privacy forms):

| Permission | Used for |
| --- | --- |
| Camera | Barcode scanning for nutrition lookup |
| Internet | OpenFoodFacts product lookup (the only network call) |
| Notifications | Active-workout lock-screen status |
| Foreground service (health) | Keeping the active-workout notification alive |

Data collection: **none leaves the device** except the barcode/product query to
OpenFoodFacts. Both stores will ask you to declare this; the honest answer is
"no data collected / no account."

## 5. Store assets still required

- App icon set (`flutter_launcher_icons` or the existing `scripts/generate_icons.py`).
- Screenshots per required device size.
- Short + full description, privacy-policy URL (a simple "all data stays on your
  device" page satisfies both stores).

## 6. Pre-flight

```bash
flutter analyze        # expect: no issues
flutter test           # expect: all green
flutter build apk --release   # or appbundle
```
