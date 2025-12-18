# HC20 SDK Testing - Quick Start Guide

## 🎯 Goal
Test the new SDK (`hc20_new` v1.0.2) with your existing configuration **WITHOUT BREAKING ANY FUNCTIONALITY**.

---

## 📋 What You Need to Know

### Current Setup:
- **Current SDK**: `hc20` v1.0.0 (Stable)
- **New SDK**: `hc20_new` v1.0.2 (To Test)
- **Location**: Both SDKs are in your workspace

### Key Differences in New SDK:
1. ✅ Auto-enables sensors on connection (no manual button press)
2. ✅ Auto-starts background sync (raw data uploads automatically)
3. ✅ Development/Production API toggle
4. ✅ Better historical data handling
5. ✅ Simplified authentication

---

## 🚀 How to Test (3 Simple Steps)

### Step 1: Switch to New SDK

**Option A - Automated (Easiest):**
```bash
cd /workspaces/HFC-App
./switch_sdk.sh
```

**Option B - Manual:**
1. Open `pubspec.yaml`
2. Find this line:
   ```yaml
   hc20:
     path: ./hc20
   ```
3. Change it to:
   ```yaml
   hc20:
     path: ./hc20_new
   ```
4. Save the file

### Step 2: Update Dependencies
```bash
flutter pub get
flutter clean
```

### Step 3: Run and Test
```bash
flutter run
```

---

## ✅ What to Test

### Must Test These Features:
1. **Connect Device**
   - Scan for HC20 device
   - Connect successfully
   - Watch: Sensors should enable automatically (NEW!)

2. **Real-Time Data**
   - Heart Rate updates
   - SpO2 updates
   - Blood Pressure updates
   - Temperature updates
   - Battery level
   - Steps counter

3. **Background Features (NEW!)**
   - Check logs: "RawManager started successfully"
   - Check logs: "Sensors enabled automatically"
   - Data should flow immediately without pressing buttons

4. **Historical Data**
   - Go to "All Data" page
   - Retrieve historical readings
   - Verify data displays correctly

5. **Webhooks**
   - Check webhook success count
   - Verify data reaches backend

6. **Device Lifecycle**
   - Disconnect and reconnect
   - Check data resumes correctly

---

## 🔄 Rollback if Needed

If anything goes wrong, restore the old SDK:

```bash
cd /workspaces/HFC-App
cp pubspec.yaml.backup pubspec.yaml
flutter pub get
flutter clean
flutter run
```

That's it! Your app is back to the stable version.

---

## 📊 Expected Behavior

### OLD SDK (v1.0.0):
1. Connect device
2. Manually press "Enable Sensors"
3. Data starts flowing
4. Background sync OFF
5. Raw data upload OFF

### NEW SDK (v1.0.2):
1. Connect device
2. **Sensors enable automatically** ⚡
3. Data starts flowing immediately
4. **Background sync ON** ⚡
5. **Raw data uploads automatically** ⚡

---

## 🐛 Common Issues and Fixes

### Issue: "Sensors don't auto-enable"
**Fix**: Check Bluetooth permissions, try manual enable as fallback

### Issue: "Background sync not starting"
**Fix**: Check internet connection, verify cloud credentials

### Issue: "App crashes"
**Fix**: Run `flutter clean && flutter run`

### Issue: "Historical data fails"
**Fix**: Verify device has data stored, check date parameters

---

## 📝 Important Files Created

1. **`pubspec.yaml.backup`** - Your current stable configuration (auto-created)
2. **`switch_sdk.sh`** - Automated SDK switcher script
3. **`SDK_TESTING_GUIDE.md`** - Quick reference guide
4. **`TESTING_DOCUMENTATION.md`** - Comprehensive testing docs
5. **`lib/sdk_config.dart`** - SDK configuration helper

---

## 🎓 Pro Tips

1. **Always test in development first** before production
2. **Keep the backup file** - it's your safety net
3. **Check logs** - they tell you what's happening
4. **Test thoroughly** - follow the checklist
5. **Rollback is instant** - don't hesitate if issues arise

---

## 📞 Need More Help?

- **Full Testing Guide**: See `TESTING_DOCUMENTATION.md`
- **SDK Changes**: See `hc20_new/CHANGELOG.md`
- **Integration Guide**: See `docs/hc20-integration.md`

---

## ✨ Summary

Your current app is **100% safe**. We've:
- ✅ Created backups
- ✅ Provided easy switching mechanism
- ✅ Documented all changes
- ✅ Created rollback procedures
- ✅ Comprehensive testing checklist

**You can test the new SDK risk-free and rollback instantly if needed!**

---

**Ready to test? Run: `./switch_sdk.sh`**
