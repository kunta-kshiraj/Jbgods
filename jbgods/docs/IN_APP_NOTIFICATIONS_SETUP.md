# In-App Notifications – Step-by-Step Setup

Follow these steps in order.

---

## 1. Prerequisites

- **Firebase CLI** installed and logged in:
  ```bash
  npm install -g firebase-tools
  firebase login
  ```
- **Flutter** project is in the `jbgods` folder (this app).
- **Firebase project** is already set up for this app (Auth, Firestore, Functions).

---

## 2. Deploy Firestore Rules

From the **project root** (the folder that contains `firestore.rules` and `firebase.json`):

```bash
cd /Users/kshirajkunta/Documents/Project_Jbgods/Jbgods/jbgods
firebase deploy --only firestore:rules
```

- This updates rules for `notifications` (and any other rules in `firestore.rules`).
- Confirm in the Firebase Console → Firestore → Rules that the deploy succeeded.

---

## 3. Deploy Firestore Indexes

From the same folder:

```bash
firebase deploy --only firestore:indexes
```

- This creates the composite index for `notifications`: `userId` (asc) + `createdAt` (desc).
- If the index is still building, Firebase Console → Firestore → Indexes will show “Building…”. Wait until it is “Enabled” before relying on the notifications list.

---

## 4. Deploy Cloud Functions

From the **functions** folder (or project root with `--project` if needed):

```bash
cd /Users/kshirajkunta/Documents/Project_Jbgods/Jbgods/jbgods/functions
npm install
cd ..
firebase deploy --only functions
```

Or from project root in one go:

```bash
cd /Users/kshirajkunta/Documents/Project_Jbgods/Jbgods/jbgods
firebase deploy --only functions
```

- This deploys the notification triggers:
  - `onRequestCreated` – member request → masters
  - `onOwnerRequestCreated` – owner request → masters
  - `onUpdateCreated` – new update → masters, admins, members, owners
  - `onEventCreated` – new event → masters, admins, members, owners
  - `onReportCreated` – new report → masters
  - `onRinkListingCreated` – admin rink listing pending → masters
  - `onMessageCreated` – new chat message → admins, members, owners (except author)

- Check Firebase Console → Functions to see all functions and that they are deployed without errors.

---

## 5. Run the Flutter App

No extra config is needed in the app for in-app notifications; the code is already in place.

```bash
cd /Users/kshirajkunta/Documents/Project_Jbgods/Jbgods/jbgods
flutter pub get
flutter run
```

- Use a device or simulator where you can sign in as different roles (member, admin, master) to test.

---

## 6. Verify Behaviour (Optional)

1. **Masters**
   - Create a member request (or owner request), a report, or an admin rink listing; masters should see a new notification.
   - Create an update or event; masters should also get that notification.
2. **Admins / normal users**
   - Have an admin or owner post a chat message; other admins, members, and owners should get a “New chat message” notification.
   - Create an update or event; admins and normal users should get the corresponding notification.
3. **In the app**
   - Open **Home** → tap the **bell** icon → you should see the notifications list.
   - Open **burger menu** → **Notifications** → same screen.
   - Tap a notification → it should mark as read and navigate (e.g. Requests, Reports, Chat, Home, Rinks) as designed.

---

## Quick reference – one-time full deploy

From project root:

```bash
cd /Users/kshirajkunta/Documents/Project_Jbgods/Jbgods/jbgods
firebase deploy --only firestore:rules,firestore:indexes,functions
```

Then run the app:

```bash
flutter run
```

---

## Troubleshooting

- **“Missing index” in the app**  
  Run `firebase deploy --only firestore:indexes` and wait until the index is **Enabled** in Firestore → Indexes.

- **No notifications when something happens**  
  - Confirm functions are deployed: Firebase Console → Functions.
  - Check Functions logs: Firebase Console → Functions → select function → Logs.

- **Permission denied on notifications**  
  - Ensure `firestore:rules` were deployed and that the rules include the `notifications` block from `firestore.rules`.
