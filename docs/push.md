# Turning on push notifications

The app contains the push code (`lib/core/push/push_service.dart`, Firebase Cloud Messaging). It stays off until
the Firebase files of **your** Firebase project are added, because they identify your project and must not be committed.

1. Create a Firebase project and add an Android app `qa.onesource.onesource_connect` and an iOS app with the same bundle id.
2. Either put the project values into your config file (`FIREBASE_PROJECT_ID`, `FIREBASE_SENDER_ID`,
   `FIREBASE_ANDROID_APP_ID`, `FIREBASE_ANDROID_API_KEY`, `FIREBASE_IOS_APP_ID`, `FIREBASE_IOS_API_KEY` — Firebase
   console → Project settings → Your apps), which needs no extra files, **or**, on a developer machine,
   `dart pub global activate flutterfire_cli` then `flutterfire configure`.
   This writes `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist` and the Gradle plugin lines.
   Both files are in `.gitignore`; in CI, write them from secrets before building.
3. iOS: `tool/configure_platforms.py` already adds the push entitlement and background mode. In Xcode check **Push Notifications** and **Background Modes → Remote notifications**, and upload an APNs key to Firebase.
4. ERP: set `CONNECT_PUSH_DRIVER=fcm` and the Firebase service-account credentials as described in the ERP's
   `docs/connect/05-deployment.md`. `GET notifications/preferences` then answers `push_available: true`.

What the app does: after sign-in it asks for permission, sends the token with `POST devices/push`, re-sends it when
Firebase rotates it, opens `data.link` when a notification is tapped, and calls `DELETE devices/push` before sign-out.
The inbox remains the source of truth; push can be late or missing.
