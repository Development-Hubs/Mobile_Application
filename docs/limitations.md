# What is not built or not verified

This list is meant to be exact. Please do not describe the app as complete.

## Not verified

1. **Never compiled.** The code was written in an environment with no Flutter or Dart SDK, and the package registry was unreachable. `flutter analyze`, `flutter test` and builds have **not run**. Expect a first pass of compile fixes (typos, API signature changes in package versions).
2. **No device testing.** No screen has been seen on a phone. The layouts, RTL mirroring, the skyline animation, dark mode and large-text behaviour are untested.
3. **CI has not run.** `.github/workflows/ci.yml` is written, but GitHub Actions is blocked by billing on the organisation.
4. **Backend tests not run.** The ERP changes in chatbot PR #253 include feature tests that were not executed (that environment had PHP 8.3; the ERP needs 8.4).
5. **No end-to-end run against demoagent / demopartner.** Response shapes were taken from the ERP source code, not from live answers.

## Not built

* **Push notifications.** No Firebase project, `google-services.json` or APNs key. The inbox works without push. To add: Firebase Messaging, then `POST devices/push` after sign-in and `DELETE devices/push` on sign-out.
* **Deep links** (`onesource://…`) from outside the app. Links inside notifications are followed inside the app only.
* **Offline drafts and queued retries.** Lost answers are safe to retry because of idempotency keys, but nothing is stored for later sending.
* **QR scanning** for training check-in (the code is typed instead).
* **Course materials, quizzes, assessor rubric form, enrolment approval** (endpoints exist).
* **Bed assignment and moves** (needs a subject search endpoint).
* **Attendance approvals and the manager board** on mobile.
* All ERP modules listed as *Web* in [feature-parity.md](feature-parity.md).
* **App icons, splash images and store listings.** `flutter create` provides default icons. The Play Store link on the update screen uses the planned id `qa.onesource.onesource_connect`; the App Store link is a placeholder until the app is listed.
* **Release signing.** No keystore or provisioning profile is included, by design.
* **Arabic font.** Inter (bundled, OFL) has no Arabic glyphs; Arabic uses the system font (SF Arabic / Noto). A licensed Arabic brand font can be added later.

## Design notes

* The Doha skyline, dhow and patterns are generated artwork drawn in code (`DohaSkyline`). They are not photographs or third-party images.
* Biometric unlock only unlocks the token already on the phone. The app never takes selfies or face photos, and never stores face templates.
