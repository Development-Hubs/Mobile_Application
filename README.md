# OneSource Connect

The mobile companion of the OneSource ERP, for **staff**, **customers** and **workers**. One Flutter app for Android and iOS, in English (left to right) and Arabic (right to left), with Qatar maroon, navy and gold branding and a hand-drawn Doha skyline over the Corniche.

> **Status: source code only, not yet compiled.** The code was written without a Flutter SDK. No APK or IPA has been built and nothing has run on a device. Read [docs/limitations.md](docs/limitations.md) before testing.

## What is in the app

| Area | Who | Screens |
|---|---|---|
| Sign-in | everyone | One screen, no role cards. Staff use **work email + password + MFA code**. Customers and workers use **phone + one-time code**, with an optional invitation code. A workspace chooser appears only when the phone is linked to more than one company or record. |
| Security | everyone | Token in Keychain / Android Keystore storage; optional biometric unlock through the OS (no face images); signed-in devices list; sign out here or everywhere. |
| Home | staff | Live attendance card with a **"Please mark your attendance"** reminder, admin requests, unread counts, and the modules the ERP allows. |
| Home | customer / worker | Document expiry bars, accommodation, trips, training, certificates (worker); placements, contracts, recruitment and pickup (customer). |
| Attendance | staff of agent companies | Live clock ring, check in, breaks, check out (with confirmation), location when the company requires it, timeline, month calendar, correction requests. Managers: today's team board and approve / reject corrections. |
| Help desk | everyone | Cases with queues (staff), chat-style conversation, internal notes (staff), attachments up/download, case actions. |
| Inbox and push | everyone | Notifications, mark read, per-topic push settings, push via Firebase (after your setup, see docs/push.md), `onesource://` links into cases, trips and attendance. |
| Renewals, care calls, bed board (assign, check in/out, move), driver trips (with an offline outbox), trainer sessions (QR check-in code), assessments (rubric + evidence photos), training approvals | staff with those permissions | Queues and actions from `/api/mobile/v1`. |
| Learning | customer / worker | Requirements, enrolments, sessions, results, certificates, course materials, quizzes with saved progress, catalogue, request a place, withdraw, session check-in by QR scan or code. |
| Calendar | everyone | 30-day agenda with RSVP. |
| More | everyone | Module library built from `GET me`. ERP modules that have no mobile screens yet open the ERP in the browser and are labelled so. |
| Settings | everyone | Language (auto / English / Arabic), theme, **motion** (follow device / reduced / full), biometrics, devices, about. |

Permissions always come from the ERP (`GET me` → `permissions`, `areas`, `modules`, `attendance`, `driver`). Nothing is unlocked by a choice made on the phone, and the server checks every call again.

## Getting started

Requirements: Flutter **3.27 or newer** (stable), Xcode 15+ for iOS, Android Studio / JDK 17 for Android, Python 3.

```bash
git clone https://github.com/Development-Hubs/Mobile_Application.git
cd Mobile_Application
tool/bootstrap.sh                       # generates ios/ and android/ host files, applies permissions, runs pub get
cp config/demoagent.example.json config/demoagent.local.json
flutter run --dart-define-from-file=config/demoagent.local.json
```

`tool/bootstrap.sh` runs `flutter create` (which never overwrites existing files), removes the template's sample test, generates the app icons from `assets/brand` (`flutter_launcher_icons`), then `tool/configure_platforms.py` adds the iOS usage descriptions (Face ID, camera, photos, location), Arabic/English localisations, the `onesource://` URL scheme, background push, iOS 13 minimum, and Android `minSdk 24`. The committed `AndroidManifest.xml` and `MainActivity.kt` (a `FlutterFragmentActivity`, needed by `local_auth`) are kept.

### Environments

Build-time values are passed with `--dart-define-from-file`. **They are not secrets** — they ship inside the app.

| File | ERP |
|---|---|
| `config/demoagent.example.json` | https://demoagent.onesourceerp.com (agent company: attendance enabled) |
| `config/demopartner.example.json` | https://demopartner.onesourceerp.com (partner company: attendance answers `module_disabled`) |
| `config/production.example.json` | production template |

Keys: `API_BASE_URL`, `COMPANY_CODE` (optional pre-fill for staff sign-in), `ENV_NAME` (shows a gold ribbon, e.g. `DEMO`), `ALLOW_CUSTOM_SERVER` (lets testers type another ERP address).

Copy an example to `config/<name>.local.json` (ignored by git). Signing keys, Firebase files and store credentials must be provided through your CI secret store or local keychain — **never commit them**. `.gitignore` already excludes `*.jks`, `key.properties`, `google-services.json`, `GoogleService-Info.plist` and `config/*.local.json`.

Use **demo/staging data** when testing. Do not punch attendance, change renewals, record care calls or move trips on live records just to try a screen.

## Project layout

```
lib/
  main.dart, app.dart               start-up, theme, locale, motion scope
  core/
    api/        ApiClient (envelope, Idempotency-Key, token renewal), ApiException, paging
    auth/       SessionController (bootstrap → token → me), secure SessionStore, Biometrics, Me model
    config/     Env (dart-define values)
    i18n/       translate(), strings_en.dart / strings_ar.dart (generated by tool/strings.py)
    router/     go_router with session gates and capability checks
    settings/   language, theme, motion, biometrics preferences
    theme/      palette, Material 3 theme, MotionScope + Reveal animation
    widgets/    DohaSkyline painter, brand mark, hero headers, glass cards, busy buttons, skeletons, paged lists
  features/     auth, home, modules, attendance, cases, notifications, renewals, care, accommodation, driver,
                training, calendar, settings
test/           API client, strings parity, module gating, helpers
tool/           bootstrap.sh, configure_platforms.py, strings.py, check_strings.dart
docs/           feature parity matrix, limitations, API notes
```

### Rules the code follows

* **No sample data.** A failed call shows the ERP's error and a retry button. Success is shown only after the ERP answers.
* **Idempotency.** Every POST/PUT/DELETE sends an `Idempotency-Key`. A form keeps one key until it succeeds, so a retry after a lost answer cannot create a second case, punch or request.
* **Sessions.** Tokens are renewed when they expire within three days. `401`/`403` answers such as `token_revoked`, `workspace_revoked`, `account_blocked`, `company_unavailable` wipe the token and return to sign-in. A workspace switch clears every cached list (`epochProvider`).
* **Private files** are downloaded with the token into the app's temporary directory only.
* **Motion.** Every animation goes through `MotionScope`: the device "remove animations" setting or the in-app setting stops the skyline, shimmer, pulses and transitions.
* **Strings.** Edit `tool/strings.py` (both languages side by side), run `python3 tool/strings.py`. `dart run tool/check_strings.dart` and `test/strings_test.dart` fail when a translation or placeholder is missing.

## Tests and CI

```bash
flutter analyze
flutter test
dart run tool/check_strings.dart
```

`.github/workflows/ci.yml` generates the host projects, analyses, tests, builds an unsigned debug APK (uploaded as an artifact) and an unsigned iOS build. **The workflow has not run yet** — GitHub Actions is currently blocked by billing on the organisation.

## Backend

The app uses the existing `/api/mobile/v1` of the ERP plus additions made for it in the ERP repository: [#253](https://github.com/Development-Hubs/chatbot/pull/253) (permissions in `GET me`, staff attendance) and [#254](https://github.com/Development-Hubs/chatbot/pull/254) (manager attendance, bed subject search, training approvals, assessor rubric). See [docs/api.md](docs/api.md).
