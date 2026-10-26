# How to explain SafeVault in an interview

## 30-second pitch
"SafeVault is a Flutter app where families store important documents, like bank,
insurance and property papers, and assign trusted nominees. I used Firebase Auth
for email and Google login, Firestore and Storage for data and files, BLoC for
the login and document flows, and Riverpod for settings and theme. Tokens and the
encryption key live in flutter_secure_storage, the offline cache is an
AES-encrypted Hive box, there's a biometric lock, and a small FastAPI backend
sends reminder push notifications through FCM."

## Likely questions

**Why BLoC and Riverpod together?**
BLoC for flows with many steps and states (login, saving, offline then live
data), because events and states make them easy to test. Riverpod for simple
shared values like theme and settings, and as dependency injection
(`providers.dart`). In a team I'd follow one standard.

**How does offline work?**
`DocumentsBloc` first shows the copy saved in Hive, then listens to the
Firestore stream. Each Firestore update is saved back to Hive.

**How is the local data protected?**
On first launch I generate a random 256-bit key, store it in
flutter_secure_storage (Android Keystore / iOS Keychain), and open the Hive box
with `HiveAesCipher(key)`.

**How does the backend know who's calling?**
The Dio `AuthInterceptor` adds the Firebase ID token (a JWT) as
`Authorization: Bearer ...`. FastAPI verifies it with the Firebase Admin SDK
and gets the user's uid.

**How do push notifications work?**
The app gets its FCM token and sends it to `POST /devices`. A cron job calls
`/reminders/send-due`, and the backend sends the message to the saved tokens
through FCM.

**How do you stop users seeing each other's data?**
All data is under `users/{uid}`, and Firestore/Storage security rules only allow
`request.auth.uid == uid`.

**What did you test?**
AuthBloc and DocumentsBloc with `bloc_test` + `mocktail` (mock repositories),
the Dio interceptor with a fake HTTP adapter, model serialisation, the settings
controller with a temporary Hive box, a LoginPage widget test, and the FastAPI
endpoints with pytest.

**What would you improve?**
True zero-knowledge encryption (encrypt files on the device before upload),
nominee verification, Kannada localisation, and a Play Store release.
