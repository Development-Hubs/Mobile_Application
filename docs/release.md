# Releasing OneSource Connect

Nothing secret is in the repository. These steps need your accounts; each is done once.

## 1. Android upload key

```bash
tool/make_keystore.sh ~/onesource-upload-keystore.jks     # creates the keystore and android/key.properties (git-ignored)
flutter build appbundle --release --dart-define-from-file=config/production.local.json
```
`android/app/signing.gradle` (applied by `tool/configure_platforms.py`) signs release builds when `android/key.properties` exists.
Turn on **Play App Signing** in Google Play Console so Google keeps the app signing key; your file is only the upload key.

## 2. Google Play

1. Play Console → Create app → package `qa.onesource.onesource_connect`, default language English, add Arabic.
2. Fill the store listing and the Data safety form from [store-listing.md](store-listing.md).
3. For uploads from CI: create a service account with "Release manager" access and add its JSON as the `PLAY_SERVICE_ACCOUNT_JSON` secret.

## 3. Apple

1. App Store Connect → New app → bundle id `qa.onesource.onesourceConnect` (register it in Certificates, Identifiers & Profiles with **Push Notifications** enabled).
2. Put the numeric Apple id into `IOS_APP_ID` in your config so the "update required" screen opens the right page.
3. For CI: an Apple Distribution certificate (.p12), an App Store provisioning profile, and an App Store Connect API key.

## 4. Firebase (push)

See [push.md](push.md). Put the project values in your config (`FIREBASE_*`), or run `flutterfire configure` locally.

## 5. GitHub secrets for `.github/workflows/release.yml`

| Secret | What |
|---|---|
| `APP_CONFIG_JSON` | the whole `config/production.local.json` (API address, store ids, Firebase values) |
| `ANDROID_KEYSTORE_BASE64` | `base64 -w0 upload-keystore.jks` |
| `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` | keystore password, alias (`upload`) |
| `PLAY_SERVICE_ACCOUNT_JSON` | Play Console service account (only for upload) |
| `IOS_DIST_CERT_P12_BASE64`, `IOS_DIST_CERT_PASSWORD` | Apple Distribution certificate |
| `IOS_PROVISIONING_PROFILE_BASE64`, `APPLE_TEAM_ID` | App Store profile for `qa.onesource.onesourceConnect`, team id |
| `ASC_API_KEY_ID`, `ASC_API_ISSUER_ID`, `ASC_API_KEY_P8` | App Store Connect API key (only for TestFlight upload) |

Run: Actions → **Release builds** → choose the track and whether to upload. Artifacts (AAB, IPA) are attached to the run.

**Not yet run:** GitHub Actions is blocked by billing on the organisation, so neither workflow has executed. The iOS signing step
edits the generated Xcode project for manual signing; if your project differs, open `ios/Runner.xcworkspace` once, choose the
team and profile under *Signing & Capabilities*, and build with `flutter build ipa --export-options-plist=ExportOptions.plist`.
