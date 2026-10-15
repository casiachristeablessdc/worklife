# WorkLife

WorkLife is a Flutter app for balancing work routines with personal time. It
uses Firebase Authentication, Cloud Firestore, Firebase Storage, and callable
Cloud Functions.

## App features

- Email/password and Google sign-in, onboarding, and profile management.
- Work routines, schedules, activities, goals, daily check-ins, and insights.
- Profile photos stored in Firebase Storage.
- An administrator dashboard inside the app for verified accounts granted the
  trusted Firebase `admin` custom claim.

## Development

```powershell
flutter pub get
flutter run
```

The checked-in Firebase configuration targets `worklife-bb9e9`. Firebase
features require valid Firebase project access and the deployed rules and
Cloud Functions. Admin deployment and first-admin setup are documented in
[ADMIN_SETUP.md](ADMIN_SETUP.md).

The Firestore data layout is `users/{uid}` with per-user `activities`,
`checkIns`, `goals`, and `schedule` subcollections. Client access is owner
scoped; administrator operations run through authenticated Cloud Functions.
