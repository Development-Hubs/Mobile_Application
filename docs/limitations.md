# What is not built or not verified

This list is meant to be exact. Please do not describe the app as complete.

## Not verified

1. **Never compiled.** The code was written in an environment with no Flutter or Dart SDK, and the package registry was unreachable. `flutter analyze`, `flutter test` and builds have **not run**. Expect a first pass of compile fixes (typos, API signature changes in package versions).
2. **No device testing.** No screen has been seen on a phone. The layouts, RTL mirroring, the skyline animation, dark mode and large-text behaviour are untested.
3. **CI has not run.** `.github/workflows/ci.yml` is written, but GitHub Actions is blocked by billing on the organisation.
4. **Backend tests not run.** The ERP changes in chatbot PRs #253 and #254 include feature tests that were not executed (that environment had PHP 8.3; the ERP needs 8.4).
5. **No end-to-end run against demoagent / demopartner.** Response shapes were taken from the ERP source code, not from live answers.

## Needs your accounts (cannot be done from the code)

Everything below is prepared in the repository; only your own accounts and keys are missing.

* **Firebase project for push** — create it and put its ids in your config (`FIREBASE_*`) or run `flutterfire configure` ([push.md](push.md)); set the ERP push driver.
* **Signing keys** — `tool/make_keystore.sh` creates the Android upload key on your machine; Apple certificate and profile come from your Apple Developer account ([release.md](release.md)).
* **Store listings** — create the apps in Google Play Console and App Store Connect; texts in English and Arabic and the privacy answers are ready in [store-listing.md](store-listing.md). Put the App Store id in `IOS_APP_ID`.
* **Online card payment** — needs a contract with a payment provider (e.g. a Qatar acquiring bank or gateway) and its keys. Until then customers pay at the office or by transfer and send the proof from the invoice screen; the office confirms.
* **Privacy policy URL** — both stores require one on your website.
* **GitHub Actions billing** — CI and release workflows are written but cannot run until billing is fixed on the organisation.

## Not built (by decision)

* ERP administration modules (CRM, finance, HRM admin, recruitment pipelines, packages, agent network, GM, chatbot admin) stay on the ERP web, opened from the app's *In the ERP* section. They are desktop work with large tables and forms.
* An Arabic brand font: Arabic uses the system font (SF Arabic / Noto) because Inter has no Arabic glyphs.

## Design notes

* The Doha skyline, dhow and patterns are generated artwork drawn in code (`DohaSkyline`). They are not photographs or third-party images.
* Biometric unlock only unlocks the token already on the phone. The app never takes selfies or face photos, and never stores face templates.

## Registration and sign-in without a company code

* Customer registration (`POST /api/mobile/v1/auth/register`) and staff sign-in without a company code need the ERP changes in chatbot PR #255 (on top of #253 and #254). Until those are deployed, staff sign-in shows the *Company code* field when the server asks for it, and registration answers with the ERP's error instead of pretending to succeed.
* A registered customer starts as a **prospect** customer file. What they can open in the app is still decided by the ERP's permissions for that membership.
* When the app talks to the shared address (not `<company>.onesourceerp.com`) and no `COMPANY_CODE` is set, the ERP cannot tell which company a new customer belongs to and answers `company_required`.
