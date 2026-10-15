# WorkLife administrator access

The admin dashboard is part of the existing Flutter app. A verified account
with the Firebase Authentication custom claim `admin: true` is routed to the
dashboard after sign-in. The dashboard calls the Cloud Functions deployed in
`asia-southeast1`; it does not directly list or edit the protected user records
from the client.

## Access model

- Only a trusted operator using the Firebase Admin SDK can grant or revoke the
  `admin` custom claim. No callable function or client screen can grant a role.
- Every admin callable checks the verified Firebase ID token for both
  `admin: true` and a verified email.
- Firestore rejects attempts by clients to add or modify `admin`, `isAdmin`, or
  `role` or `accountDisabled` fields in a user document. Each active user has
  owner-only access to their profile and subcollections. Disabling an account
  revokes refresh tokens and blocks subsequent Firestore requests. Admin audit
  records are read-only to verified admins and writable only by the Admin SDK.
- Admin details expose account/profile basics and record counts, not the user's
  personal-life or hobby selections. The available account action disables or
  re-enables a regular account. Admin accounts and the signed-in admin cannot
  be disabled from the dashboard.

## Deploy to the verified Firebase project

The checked-in `.firebaserc`, Android configuration, and Dart options identify
`worklife-bb9e9`. Before deployment, sign in to an authorized Firebase CLI
account, then run from the project root:

```powershell
firebase use worklife-bb9e9
firebase deploy --only functions,firestore:rules,storage
```

Review the CLI's target project before accepting deployment. Cloud Functions
use Node.js 22 and the Admin SDK's project service identity; no service-account
key is stored in this repository.

## Grant the first administrator

Use a trusted operator workstation with Application Default Credentials that
have Firebase Authentication user-management permission on `worklife-bb9e9`.
For a gcloud-authenticated operator, configure ADC and run:

```powershell
gcloud auth application-default login
npm --prefix functions run set-admin -- --email admin@example.com
```

The target account must already exist and have a verified email. To revoke the
claim, append `--revoke`. The account must sign in again (or force-refresh its
ID token) before the dashboard recognizes the changed claim.

Never add service-account JSON files, private keys, or privileged credentials
to the app or this repository.
