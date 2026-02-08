# Event Pass + QR Check-in – Deploy Notes

## 1. Flutter dependencies

```bash
cd /path/to/jbgods
flutter pub get
```

Uses: `qr_flutter`, `mobile_scanner`.

## 2. Firestore rules and index

Deploy rules and the composite index for the checked-in query:

```bash
firebase deploy --only firestore:rules
firebase deploy --only firestore:indexes
```

Index required: `event_registrations` with fields `eventId` (asc), `checkedIn` (asc), `checkedInAt` (desc). It is already in `firestore.indexes.json`.

## 3. Cloud Function

Deploy the callable function:

```bash
cd functions
npm install
cd ..
firebase deploy --only functions:checkInEventPass
```

Or deploy all functions:

```bash
firebase deploy --only functions
```

## 4. iOS (mobile_scanner)

For the Scan Pass screen you need camera usage in `ios/Runner/Info.plist`:

- `NSCameraUsageDescription` – e.g. "Scan event pass QR codes".

If it already exists (e.g. for another feature), no change is needed.

## 5. Android (mobile_scanner)

Camera permission is usually configured by the plugin. If scanning fails, ensure `android/app/src/main/AndroidManifest.xml` includes camera permission.

## Summary

- **event_registrations** – Created when a user completes event payment (same doc id as `registrations`). Contains `passCode`, `checkedIn`, `checkedInAt`, `checkedInByUid`. Only the Cloud Function updates check-in fields.
- **My Pass** – Route `/event-pass/:registrationId`. Shows event details and QR code payload `{"rid":"<id>","code":"<passCode>"}`.
- **Scan Pass** – Route `/scan-pass/:eventId`. Shown only to event creator or master. Calls `checkInEventPass({rid, code})`.
- **Checked-in list** – On the Events tab, for each event card where the user is creator or master: “Scan Pass” button and live list of checked-in users.
