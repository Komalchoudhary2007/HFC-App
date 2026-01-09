# 🚀 HFC App Login System - Quick Setup

## ✅ Pre-Flight Checklist

### 1. Dependencies Installation
```bash
cd /workspaces/HFC-App
flutter pub get
```

**Expected output:**
- ✅ Resolving dependencies...
- ✅ Got dependencies!

---

### 2. Verify Files Created

Check that all new files exist:

**Models:**
- [ ] `lib/models/user_model.dart`

**Services:**
- [ ] `lib/services/storage_service.dart`
- [ ] `lib/services/api_service.dart`
- [ ] `lib/services/auth_service.dart`

**Pages:**
- [ ] `lib/pages/login_page.dart`
- [ ] `lib/pages/register_page.dart`

**Documentation:**
- [ ] `docs/LOGIN_SYSTEM_GUIDE.md`
- [ ] `lib/api_usage_examples.dart`

**Updated Files:**
- [ ] `pubspec.yaml` (new dependencies added)
- [ ] `lib/main.dart` (authentication routing added)

---

### 3. Build & Run

#### Option A: Run in Debug Mode
```bash
flutter run
```

#### Option B: Build APK
```bash
flutter build apk --release
```

#### Option C: Install on Connected Device
```bash
flutter install
```

---

### 4. Test Login Flow

#### Step 1: Launch App
- App should open to **Login Page**

#### Step 2: Test Login (Development)
1. Enter phone: `9999999999`
2. Click **"Send OTP"**
3. Enter OTP: `123456`
4. Click **"Verify OTP & Login"**
5. ✅ Should navigate to HC20 home page

#### Step 3: Verify User Display
- Top-right corner should show **user avatar** with first letter
- Click avatar → Should show:
  - User name
  - Phone number
  - Refresh Profile option
  - Logout option

#### Step 4: Test Device Connection
1. Click **"Start Scanning"**
2. Select HC20 device
3. Device connects
4. ✅ Green indicator: **"Device linked to your account"**
5. Health data starts streaming

#### Step 5: Test Logout
1. Click **user avatar**
2. Select **"Logout"**
3. Confirm logout
4. ✅ Should navigate back to login page
5. Device should disconnect

---

### 5. Verify API Configuration

Check API base URL in `lib/services/api_service.dart`:

```dart
static const String baseUrl = 'https://api.hireforcare.com';
```

**For local testing:**
```dart
static const String baseUrl = 'http://localhost:4000';
```

---

### 6. Common Issues & Fixes

#### Issue: Flutter not found
**Fix:**
```bash
# Install Flutter or add to PATH
export PATH="$PATH:/path/to/flutter/bin"
```

#### Issue: Dependencies not resolving
**Fix:**
```bash
flutter clean
flutter pub get
```

#### Issue: Android build fails
**Fix:**
```bash
cd android
./gradlew clean
cd ..
flutter build apk
```

#### Issue: "Connection refused" when testing
**Fix:**
- Check if backend API is running
- Verify `baseUrl` in `api_service.dart`
- Check device internet connection

#### Issue: OTP not received in production
**Fix:**
- Verify backend SMS service is configured
- Check API logs for errors
- Use test credentials for development

---

### 7. Production Checklist

Before deploying to production:

- [ ] Change `baseUrl` to production URL
- [ ] Remove test credentials display from UI
- [ ] Enable ProGuard/R8 for release builds
- [ ] Test on multiple devices
- [ ] Test with real phone numbers
- [ ] Verify SMS OTP delivery
- [ ] Test network error scenarios
- [ ] Test token expiration handling
- [ ] Enable crash reporting
- [ ] Set up analytics

---

### 8. Testing Scenarios

Test all these scenarios before release:

**Authentication:**
- [ ] Send OTP to valid phone
- [ ] Verify OTP successfully
- [ ] Login with existing account
- [ ] Register new account
- [ ] Invalid OTP handling
- [ ] Network error during login
- [ ] App restart (should stay logged in)
- [ ] Logout functionality

**Device Management:**
- [ ] Scan for devices
- [ ] Connect to device
- [ ] Device association with user
- [ ] Data streaming
- [ ] Device disconnection
- [ ] Reconnection handling
- [ ] Multiple device support

**UI/UX:**
- [ ] Loading indicators work
- [ ] Error messages display correctly
- [ ] Success messages show
- [ ] User avatar displays
- [ ] Profile menu works
- [ ] Responsive to screen sizes
- [ ] Back button handling

---

### 9. Quick Commands Reference

```bash
# Install dependencies
flutter pub get

# Run app
flutter run

# Build release APK
flutter build apk --release

# Build app bundle for Play Store
flutter build appbundle --release

# Clean build artifacts
flutter clean

# Update dependencies
flutter pub upgrade

# Analyze code for issues
flutter analyze

# Format code
flutter format .

# Run tests (when tests are added)
flutter test
```

---

### 10. Next Steps

After successful setup:

1. **Test thoroughly** with test credentials
2. **Configure production** API endpoints
3. **Remove debug info** from UI
4. **Add error tracking** (Sentry, Firebase Crashlytics)
5. **Set up analytics** (Firebase Analytics, Mixpanel)
6. **Implement token refresh** for long sessions
7. **Add offline support** for cached data
8. **Create profile page** for user settings
9. **Add multiple device** management
10. **Submit to app stores**

---

## 🎉 You're Ready!

All components are in place:
- ✅ OTP authentication system
- ✅ User registration
- ✅ Secure token storage
- ✅ Device association
- ✅ Health data tracking
- ✅ Complete UI/UX

**Run `flutter pub get` and start testing!**

---

## 📚 Documentation

- **Full Guide**: `docs/LOGIN_SYSTEM_GUIDE.md`
- **API Examples**: `lib/api_usage_examples.dart`
- **API Documentation**: See provided API documentation
- **HC20 SDK**: `hc20_1.0.4/README.md`

---

## 🆘 Need Help?

1. Check `docs/LOGIN_SYSTEM_GUIDE.md` for detailed explanations
2. Review code comments in each file
3. Test with provided examples in `api_usage_examples.dart`
4. Verify API endpoints are accessible
5. Check Flutter console for error messages

---

**Happy Coding! 🚀**
