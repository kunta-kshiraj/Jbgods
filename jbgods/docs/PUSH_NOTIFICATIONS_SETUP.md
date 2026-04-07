# Push Notifications – Setup & App Store Connect

This app sends **push notifications** to users (members, admins, skating rink owners, masters) for:

1. **New event posted** – when a new event is created  
2. **New update posted** – when a new update is posted  
3. **New message in chat** – when someone sends a message in Announcements/Chat  

---

## What’s already done in the app

- **Flutter:** `firebase_messaging` is used; FCM token is saved to Firestore `users/{uid}.fcmToken` on login; notification tap opens the right screen (Events, Home, or Chat).
- **Cloud Functions:** When a document is created in `events`, `updates`, or `messages`, a function sends FCM messages to all app users (member, admin, owner, master) who have an `fcmToken`.

---

## 1. Firebase Console (one-time)

1. **Cloud Messaging**
   - Firebase Console → Project Settings → Cloud Messaging.
   - If you use **APNs (Apple)** for iOS, upload your APNs key or certificate (see “App Store Connect” below first).

2. **Deploy Functions**
   - From the project root (where `firebase.json` is):
     ```bash
     firebase deploy --only functions
     ```
   - Required functions: `onEventCreated`, `onUpdateCreated`, `onMessageCreated` (they send FCM).

---

## 2. iOS – Xcode (one-time per app)

1. **Push capability**
   - Open `ios/Runner.xcworkspace` in Xcode.
   - Select the **Runner** target → **Signing & Capabilities**.
   - Click **+ Capability** → add **Push Notifications**.

2. **Background Modes (optional but recommended)**
   - In the same **Signing & Capabilities** tab, add **Background Modes** if not already present.
   - Enable **Remote notifications** so the app can receive pushes in the background.

3. **APNs key in Firebase**
   - You’ll create an APNs key in App Store Connect / Apple Developer (see below).
   - In Firebase Console → Project Settings → Cloud Messaging → **Apple app configuration** → upload the **APNs Authentication Key** (.p8) and enter Key ID and Team ID.

---

## 3. App Store Connect – What you need to do

Do these in **App Store Connect** and **Apple Developer** so iOS push works.

### 3.1 Create an APNs key (Apple Developer)

1. Go to [Apple Developer](https://developer.apple.com/account/) → **Certificates, Identifiers & Profiles** → **Keys**.
2. Click **+** to create a new key.
3. Name it (e.g. “JB Gods Push”).
4. Enable **Apple Push Notifications service (APNs)** → Continue → Register.
5. **Download the .p8 file once** (you can’t download it again). Keep it safe.
6. Note:
   - **Key ID** (e.g. `ABC123XYZ`)
   - **Team ID** (in the top right or in Membership details)
   - **Bundle ID** of your app (e.g. `com.yourcompany.jbgods`)

### 3.2 Upload APNs key to Firebase

1. **Firebase Console** → your project → **Project settings** (gear) → **Cloud Messaging**.
2. Under **Apple app configuration**, select your iOS app (by bundle ID).
3. Upload the **APNs Authentication Key**:
   - **APNs Auth Key:** upload the `.p8` file.
   - **Key ID:** from step 3.1.
   - **Team ID:** from step 3.1.
   - **Bundle ID:** your app’s bundle ID.
4. Save.

### 3.3 App Store Connect – App ID and provisioning

1. **Identifiers**
   - Apple Developer → **Identifiers** → select your app’s **App ID** (same bundle ID as the app).
   - Ensure **Push Notifications** is **Enabled** (under Capabilities). If not, enable it and save.

2. **Provisioning profiles**
   - After enabling Push on the App ID, regenerate or create a new **Provisioning Profile** for that App ID (Development and Distribution) and use it in Xcode so the app is built with push entitlement.

### 3.4 App Store Connect – App submission (when you submit the app)

1. **App privacy**
   - In App Store Connect → your app → **App Privacy**.
   - If you collect or use device tokens / push identifiers, declare it as needed (e.g. “Device ID” or “Other diagnostic data” if you only use it for sending pushes). Follow Apple’s current guidelines.

2. **App Store listing**
   - No special “push” section is required; the permission is requested in the app at runtime (we request notification permission in code).

3. **TestFlight / production**
   - Push works in **Development** (sandbox) and **Production**:
     - Development builds use the sandbox APNs environment.
     - Archive and upload to App Store Connect; TestFlight and App Store builds use production APNs.
   - Firebase Cloud Messaging uses the key you uploaded; it works for both once the key is in Firebase.

### 3.5 Summary checklist (App Store Connect / Apple)

- [ ] Create **APNs key** (.p8) in Apple Developer and note Key ID and Team ID.  
- [ ] Upload **APNs key** to Firebase Console → Cloud Messaging → Apple app config.  
- [ ] Ensure **App ID** has **Push Notifications** capability enabled.  
- [ ] Add **Push Notifications** (and optionally **Background Modes → Remote notifications**) in Xcode for the Runner target.  
- [ ] Use a **Provisioning Profile** that includes Push Notifications.  
- [ ] When submitting the app, complete **App Privacy** as needed for push/identifiers.  

---

## 4. Android

- No extra steps in App Store Connect (that’s for Apple).
- Ensure `google-services.json` is in `android/app/` and the app has internet permission (already typical for Firebase).
- FCM works for Android once the project uses Firebase and the functions are deployed.

---

## 5. Testing push

1. **Get a device token**
   - Run the app on a physical device (push is unreliable on simulators), sign in, and allow notifications when prompted.  
   - The app saves the FCM token to Firestore `users/{uid}.fcmToken`.

2. **Trigger a push**
   - Create a new **event**, or **update**, or send a **chat message** (as a user who can do that).  
   - Within a few seconds, all app users (with valid FCM tokens) should receive the corresponding push.

3. **Tap behavior**
   - **New event** → opens Events tab.  
   - **New update** → opens Home.  
   - **New message** → opens Chat.

---

## 6. Troubleshooting

- **iOS: no push received**
  - Confirm Push Notifications and (if used) Remote notifications are enabled in Xcode.
  - Confirm the APNs key is uploaded in Firebase and the bundle ID matches.
  - Use a **physical device** and a **Development** or **Production** build that matches the APNs environment.
- **Android: no push**
  - Check that `google-services.json` is present and the app is signed (e.g. release or a proper debug keystore).
- **Token not in Firestore**
  - User must be signed in; the app saves the token after login. Check Firestore `users/{uid}` for `fcmToken`.
