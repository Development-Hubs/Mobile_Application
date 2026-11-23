# What is not built or not verified

This list is meant to be exact. Please do not describe the app as complete.

## Not verified

1. **Never compiled.** The code was written in an environment with no Flutter or Dart SDK, and the package registry was unreachable. `flutter analyze`, `flutter test` and builds have **not run**. Expect a first pass of compile fixes (typos, API signature changes in package versions).
2. **No device testing.** No screen has been seen on a phone. The layouts, RTL mirroring, the skyline animation, dark mode and large-text behaviour are untested.
3. **CI has not run.** `.github/workflows/ci.yml` is written, but GitHub Actions is blocked by billing on the organisation.
4. **Backend tests not run.** The ERP changes in chatbot PRs #253 and #254 include feature tests that were not executed (that environment had PHP 8.3; the ERP needs 8.4).
5. **No end-to-end run against demoagent / demopartner.** Response shapes were taken from the ERP source code, not from live answers.

## Built but needs your setup

* **Push notifications** — code is in the app; it switches on once your Firebase files are added (`flutterfire configure`, see [push.md](push.md)) and the ERP push driver is set. Until then the in-app inbox works on its own.
* **Store links** on the "update required" screen — the Play Store link uses the planned id `qa.onesource.onesource_connect`; the App Store link needs the real app id after listing.
* **Release signing** — no keystore or provisioning profile is included, by design. Provide them through your CI secret store.

## Not built (by decision)

* Customer candidate catalogue, shortlist, interview requests, agreements and e-signature, invoices and payments, worker salary statements — these are not in API v1 and involve money or legal records.
* ERP modules listed as *Web* in [feature-parity.md](feature-parity.md) (CRM, finance, HRM admin, recruitment, packages, agent network, GM, chatbot admin). They open the ERP in the browser from the app.
* An Arabic brand font: Arabic uses the system font (SF Arabic / Noto) because Inter has no Arabic glyphs.

## Design notes

* The Doha skyline, dhow and patterns are generated artwork drawn in code (`DohaSkyline`). They are not photographs or third-party images.
* Biometric unlock only unlocks the token already on the phone. The app never takes selfies or face photos, and never stores face templates.
