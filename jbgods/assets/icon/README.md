# App Icon Setup Instructions

## To set up your red rose app icon:

1. **Save your rose logo image** as `app_icon.png` in this directory (`assets/icon/app_icon.png`)

2. **Image requirements:**
   - Format: PNG
   - Size: 1024x1024 pixels (square)
   - Background: Transparent or white
   - The red rose with black outlines should be clearly visible

3. **After adding the image, run:**
   ```bash
   flutter pub get
   flutter pub run flutter_launcher_icons:main
   ```

4. **This will generate:**
   - iOS app icons in `ios/Runner/Assets.xcassets/AppIcon.appiconset/`
   - Android app icons in `android/app/src/main/res/`
   - Web, Windows, and macOS icons

## Current Status:
- ✅ Flutter launcher icons package installed
- ✅ Configuration added to pubspec.yaml
- ⏳ Waiting for your rose logo image

Replace this README with your `app_icon.png` file when ready!
