# SafeVault

A secure document vault for families, built with **Flutter**. Store important
documents (bank accounts, insurance, investments, property, ID), assign trusted
**nominees**, and get reminders to keep the vault up to date.

## Features

| Feature | How it's built |
|---|---|
| Email + Google sign-in | Firebase Authentication, `google_sign_in` |
| Documents & nominees | Cloud Firestore (`users/{uid}/documents`, `users/{uid}/nominees`) |
| File upload (PDF / image) | Firebase Storage + `file_picker` |
| Biometric app lock | `local_auth` (re-locks after 30 s in background) |
| Encrypted offline cache | Hive, AES-256 key stored in `flutter_secure_storage` (Keystore / Keychain) |
| Auth & document flows | **BLoC** (`AuthBloc`, `DocumentsBloc`, `NomineesCubit`) |
| Settings & theme | **Riverpod** (`NotifierProvider`), saved in Hive |
| Backend API | **FastAPI**, called with **Dio** + JWT interceptor |
| Reminder push notifications | Firebase Cloud Messaging (FCM) |
| Security rules | `firestore.rules`, `storage.rules`: users only see their own data |
| Tests | Unit, bloc and widget tests (`bloc_test`, `mocktail`); pytest for the backend |

## Architecture (clean architecture, feature-first)

```
lib/
├── main.dart                 # init Firebase, Hive (encrypted), Riverpod
├── app.dart                  # MaterialApp, AuthGate, VaultShell
├── core/
│   ├── config/               # API URL, Hive box names
│   ├── errors/               # Failure classes (friendly error messages)
│   ├── network/              # Dio ApiClient + AuthInterceptor (Bearer JWT)
│   ├── services/             # BiometricService, NotificationService (FCM)
│   ├── storage/              # SecureKeyStore (flutter_secure_storage)
│   ├── theme/                # Material 3 light/dark themes
│   └── providers.dart        # Riverpod providers = dependency injection
└── features/
    ├── auth/      domain/ → data/ → presentation/ (bloc, pages)
    ├── vault/     domain/ → data/ → presentation/ (bloc, pages)
    ├── settings/  presentation/ (Riverpod controller + page)
    └── lock/      presentation/ (LockGate)
backend/                      # FastAPI + SQLite + Firebase Admin
```

- **domain**: plain Dart models and abstract repositories (no Firebase).
- **data**: Firebase/Hive implementations of the repositories.
- **presentation**: BLoCs and widgets. They only talk to the domain layer, so
  tests can replace the repositories with mocks.

How a request flows: `UI → event → DocumentsBloc → VaultRepository →
Firestore → stream → new state → UI rebuilds`.

---

# Setup on Windows (step by step)

Allow **3–4 hours** the first time, mostly downloads.

## 1. Install the tools

1. **Git**: https://git-scm.com/download/win (keep default options).
2. **Flutter SDK**: https://docs.flutter.dev/get-started/install/windows/mobile
   - Download the zip, extract to `C:\src\flutter` (NOT inside Program Files).
   - Search Windows for *"Edit environment variables for your account"*, edit
     **Path**, add `C:\src\flutter\bin`.
3. **Android Studio**: https://developer.android.com/studio
   - Open it once and finish the setup wizard (installs the Android SDK).
   - *More Actions → SDK Manager → SDK Tools*: tick **Android SDK
     Command-line Tools**, click Apply.
   - *More Actions → Virtual Device Manager*: create a Pixel phone emulator.
   - *Plugins*: install **Flutter** (also installs Dart).
4. Open a **new** Command Prompt and run:
   ```
   flutter doctor
   flutter doctor --android-licenses     (press y for all)
   ```
   Fix anything with a red ✗ (Visual Studio / Chrome warnings can be ignored).

## 2. Create the platform folders

Unzip this project, e.g. to `C:\projects\safevault`, then:

```
cd C:\projects\safevault
flutter create . --org com.pooja --platforms android,ios
flutter pub get
```

`flutter create .` only adds the missing `android/` and `ios/` folders; it does
not overwrite the code in `lib/`.

## 3. Android changes (required)

**a) MainActivity**: `android/app/src/main/kotlin/com/pooja/safevault/MainActivity.kt`
(biometric needs `FlutterFragmentActivity`):

```kotlin
package com.pooja.safevault

import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity()
```

**b) AndroidManifest**: `android/app/src/main/AndroidManifest.xml`.
Add above the `<application` line:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.USE_BIOMETRIC"/>
```

To call the backend on your laptop over plain `http` while testing, add this
attribute inside the `<application ...>` tag:
`android:usesCleartextTraffic="true"`. Remove it when you deploy the backend
with https.

**c) minSdk**: in `android/app/build.gradle.kts` (or `build.gradle`), inside
`defaultConfig`, set:

```
minSdk = 23
```

## 4. Firebase setup

1. Go to https://console.firebase.google.com, **Add project** → `safevault`.
2. **Build → Authentication → Get started**: enable **Email/Password** and **Google**.
3. **Build → Firestore Database → Create database** (production mode, region
   `asia-south1` Mumbai). Open the **Rules** tab, paste `firestore.rules`, Publish.
4. **Build → Storage → Get started**. Paste `storage.rules` in **Rules**, Publish.
   (If Storage asks you to upgrade to the Blaze plan, you can skip file upload
   for now. Everything else works on the free plan.)
5. Install the FlutterFire CLI and connect the app:
   ```
   npm install -g firebase-tools        (needs Node.js: https://nodejs.org)
   firebase login
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```
   Choose your project and **android** (and ios). This replaces
   `lib/firebase_options.dart` with your real settings.
   If `flutterfire` isn't found, add `%LOCALAPPDATA%\Pub\Cache\bin` to Path.
6. **Google sign-in needs your SHA-1 key:**
   ```
   cd android
   gradlew signingReport
   ```
   Copy the `SHA1` under `Variant: debug`. Firebase console → Project settings
   → your Android app → **Add fingerprint**. Then run `flutterfire configure`
   again.

## 5. Run the app

Start the emulator from Android Studio, then:

```
flutter run
```

Check that everything is correct:

```
flutter analyze
flutter test
```

## 6. Run the backend (for reminders)

```
cd backend
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
pytest
```

Firebase console → Project settings → **Service accounts** → *Generate new
private key*. Save it as `backend\serviceAccountKey.json` (it's git-ignored,
**never** upload it). Then:

```
set GOOGLE_APPLICATION_CREDENTIALS=serviceAccountKey.json
set CRON_KEY=any-long-secret
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

- The emulator reaches it at `http://10.0.2.2:8000` (the app's default).
- On a real phone (same Wi-Fi), use your laptop's IP (run `ipconfig`):
  `flutter run --dart-define=API_BASE_URL=http://192.168.1.5:8000`
- API docs: http://localhost:8000/docs
- To send due reminders: `curl -X POST -H "X-Cron-Key: any-long-secret" http://localhost:8000/reminders/send-due`

## 7. Build the APK and publish on GitHub

```
flutter build apk --release
```

The APK is at `build\app\outputs\flutter-apk\app-release.apk`.

```
git init
git add .
git commit -m "SafeVault: Flutter secure document vault"
git branch -M main
git remote add origin https://github.com/Poojakk112/safevault.git
git push -u origin main
```

(Create the empty `safevault` repo on GitHub first.) On GitHub, open
**Releases → Draft a new release**, tag `v1.0.0`, attach `app-release.apk`,
and add screenshots to this README.

---

## Possible improvements

- End-to-end (zero-knowledge) encryption of files before upload.
- Nominee access requests with verification.
- Kannada / Hindi localisation.
- Publish on Play Store (`flutter build appbundle`).
