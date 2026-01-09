# 📱 Building HFC App APK with Login System

## ⚠️ IMPORTANT NOTICE

**The APK currently available for download does NOT include the new login system!**

- **Old Build Date**: December 30, 2025
- **Login System Added**: January 5, 2026
- **To test login features**: You must rebuild the APK

---

## 🚀 Quick Build Instructions

### Prerequisites
- Flutter SDK installed ([Install Guide](https://docs.flutter.dev/get-started/install))
- Android SDK/Android Studio (for building APK)
- Git (to clone repository)

### Step-by-Step Build Process

#### 1. Install Flutter SDK
```bash
# macOS/Linux
git clone https://github.com/flutter/flutter.git -b stable
export PATH="$PATH:`pwd`/flutter/bin"

# Windows
# Download from: https://docs.flutter.dev/get-started/install/windows
```

#### 2. Verify Installation
```bash
flutter doctor
# Fix any issues shown
```

#### 3. Get Dependencies
```bash
cd /workspaces/HFC-App
flutter pub get
```

#### 4. Build Release APK
```bash
flutter build apk --release
```

#### 5. Find Your APK
The built APK will be at:
```
build/app/outputs/flutter-apk/app-release.apk
```

---

## 📦 Build Output

After successful build:
```
✓ Built build/app/outputs/flutter-apk/app-release.apk (47.0 MB)
```

Transfer this file to your phone to test the login system!

---

## 🔐 Testing the Login System

Once you install the new build:

### 1. First Launch
- App opens to **Login Page** (not HC20 page anymore)

### 2. Test Login (Development)
```
Phone: 9999999999
OTP:   123456
```

### 3. Login Flow
1. Enter phone number
2. Click "Send OTP"
3. Enter OTP (123456)
4. Click "Verify OTP & Login"
5. ✅ Success → Navigate to HC20 page

### 4. Features to Test
- ✅ User registration
- ✅ OTP verification
- ✅ User avatar in AppBar
- ✅ Profile menu
- ✅ Device association
- ✅ Logout functionality
- ✅ Session persistence (close/reopen app)

---

## 🐛 Troubleshooting Build Issues

### Issue: "Flutter not found"
```bash
# Add Flutter to PATH
export PATH="$PATH:/path/to/flutter/bin"

# Or permanently (Linux/macOS)
echo 'export PATH="$PATH:/path/to/flutter/bin"' >> ~/.bashrc
source ~/.bashrc
```

### Issue: "SDK licenses not accepted"
```bash
flutter doctor --android-licenses
# Accept all licenses
```

### Issue: "Gradle build failed"
```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
flutter build apk --release
```

### Issue: "Out of memory"
```bash
# Increase Java heap size
export GRADLE_OPTS="-Xmx4096m"
flutter build apk --release
```

### Issue: "Permission denied"
```bash
chmod +x android/gradlew
flutter build apk --release
```

---

## 🎯 Alternative: Build APK Bundle

For Google Play Store submission:
```bash
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab`

---

## 📊 Build Variants

### Debug Build (Faster, for testing)
```bash
flutter build apk --debug
# ~60 MB, includes debugging tools
```

### Release Build (Optimized)
```bash
flutter build apk --release
# ~47 MB, optimized and minified
```

### Split APKs (Smaller files)
```bash
flutter build apk --split-per-abi
# Creates separate APKs for different architectures
# arm64-v8a, armeabi-v7a, x86_64
```

---

## 🔧 Advanced Build Options

### Build with specific flavor
```bash
flutter build apk --release --flavor production
```

### Build with custom build number
```bash
flutter build apk --release --build-number=22
```

### Build with custom app name
```bash
flutter build apk --release --build-name=1.11.0
```

### Analyze build size
```bash
flutter build apk --release --analyze-size
```

---

## 📱 Installation Methods

### Method 1: Direct Install via USB
```bash
flutter install
# Phone must be connected via USB with debugging enabled
```

### Method 2: Transfer via File
1. Copy APK to phone (USB/Email/Cloud)
2. Open APK file on phone
3. Allow installation from unknown sources
4. Install

### Method 3: Serve via HTTP (Current Method)
1. Run: `python3 serve_apk_download.py`
2. Access: `http://localhost:8080`
3. Download on phone
4. Install

---

## ✅ Build Checklist

Before building:
- [ ] Flutter SDK installed
- [ ] Android SDK installed
- [ ] Dependencies fetched (`flutter pub get`)
- [ ] No errors (`flutter analyze`)
- [ ] API URL configured (production/development)
- [ ] Test credentials removed from UI (for production)

After building:
- [ ] APK file exists in `build/app/outputs/flutter-apk/`
- [ ] APK size reasonable (~45-50 MB)
- [ ] Test installation on device
- [ ] Test all features
- [ ] Verify login system works

---

## 🎉 Success!

Once built successfully:
1. ✅ APK with login system created
2. ✅ Ready for installation
3. ✅ All new features included
4. ✅ Test credentials work (9999999999 / 123456)

---

## 📚 Additional Resources

- [Flutter Build Docs](https://docs.flutter.dev/deployment/android)
- [Android Signing](https://docs.flutter.dev/deployment/android#signing-the-app)
- [Play Store Release](https://docs.flutter.dev/deployment/android#reviewing-the-app-manifest)
- [App Bundle](https://developer.android.com/guide/app-bundle)

---

## 🆘 Need Help?

1. Check `flutter doctor` output
2. Review build errors in terminal
3. Check Flutter console logs
4. Verify all dependencies installed
5. Try `flutter clean` and rebuild

---

**Build Time**: ~3-5 minutes (depending on machine)  
**APK Size**: ~47 MB  
**Target Android**: API 21+ (Android 5.0+)

**Happy Building! 🚀**
