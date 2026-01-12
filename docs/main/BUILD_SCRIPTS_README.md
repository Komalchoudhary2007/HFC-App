# 🚀 HFC App - Automated Build Scripts

Two powerful scripts to automate your entire build and deployment process!

---

## 📜 Available Scripts

### 1. `build_and_serve.sh` - Full Automation (First Time Setup)
**Use this when:**
- Running for the first time
- Flutter/Android SDK not installed
- Want complete automated setup

**What it does:**
1. ✅ Installs Flutter SDK (if not present)
2. ✅ Installs Android SDK (if not present)
3. ✅ Accepts all licenses
4. ✅ Builds release APK
5. ✅ Updates download.html with version/date
6. ✅ Starts HTTP server on port 8080
7. ✅ Keeps server running

**Usage:**
```bash
./build_and_serve.sh
```

**Features:**
- Smart checks (skips installation if already present)
- Colored output for easy tracking
- Error handling
- Auto-updates download page
- Keeps server running until you press Ctrl+C

---

### 2. `quick_build.sh` - Fast Rebuild
**Use this when:**
- Flutter/Android SDK already installed
- Just need to rebuild APK
- Made code changes and want to test

**What it does:**
1. ✅ Cleans project
2. ✅ Gets dependencies
3. ✅ Builds release APK
4. ✅ Updates download.html
5. ✅ Restarts server

**Usage:**
```bash
./quick_build.sh
```

**Speed:** ~3-5 minutes (vs 10-15 minutes for full setup)

---

## 🎯 Quick Start Guide

### First Time Setup:
```bash
cd /workspaces/HFC-App
./build_and_serve.sh
```

Wait for the script to complete, then open:
- **Download Page:** http://localhost:8080/download.html
- **Direct APK:** http://localhost:8080/app-release.apk

### Subsequent Builds:
```bash
cd /workspaces/HFC-App
./quick_build.sh
```

---

## 📋 What Gets Installed

### Flutter SDK Location:
```
/tmp/flutter
```

### Android SDK Location:
```
/tmp/android-sdk
```

### APK Output Location:
```
/workspaces/HFC-App/app-release.apk
```

---

## 🔧 Manual Commands

If you prefer manual control:

### Build APK Only:
```bash
export PATH="$PATH:/tmp/flutter/bin"
export ANDROID_HOME="/tmp/android-sdk"
export PATH="$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools"
cd /workspaces/HFC-App
flutter build apk --release
```

### Start Server Only:
```bash
cd /workspaces/HFC-App
python3 -m http.server 8080
```

### Stop Server:
```bash
pkill -f "python3 -m http.server 8080"
```

---

## 🐛 Troubleshooting

### "Flutter not found"
Run the full setup script:
```bash
./build_and_serve.sh
```

### "Port 8080 already in use"
Stop existing server:
```bash
pkill -f "python3 -m http.server 8080"
```
Then run the script again.

### "Permission denied"
Make scripts executable:
```bash
chmod +x build_and_serve.sh quick_build.sh
```

### Build fails with Gradle errors
Clean and rebuild:
```bash
cd /workspaces/HFC-App
flutter clean
./quick_build.sh
```

---

## 📊 Build Times

| Task | Time |
|------|------|
| Flutter SDK Download | ~2-3 min |
| Android SDK Setup | ~2-3 min |
| First APK Build | ~5-10 min |
| Subsequent Builds | ~3-5 min |

**Total first-time setup:** ~10-15 minutes
**Quick rebuild:** ~3-5 minutes

---

## ✨ Features

### Automatic Version Detection
Scripts automatically read version from `pubspec.yaml` and update `download.html`

### Smart Caching
If SDKs are already installed, scripts skip installation and proceed to building

### Auto-Update Download Page
Download page automatically shows:
- Current version number
- Build date
- APK size

### Persistent Server
Server continues running until you stop it with Ctrl+C

---

## 🎨 Color-Coded Output

- 🟢 **Green** = Success
- 🔵 **Blue** = Information
- 🟡 **Yellow** = Warning
- 🔴 **Red** = Error

---

## 📦 Server URLs

Once the server is running, access your app at:

| Resource | URL |
|----------|-----|
| Download Page | http://localhost:8080/download.html |
| Update Page | http://localhost:8080/update.html |
| Direct APK | http://localhost:8080/app-release.apk |

**From other devices on network:**
Replace `localhost` with your machine's IP address:
```
http://YOUR_IP:8080/download.html
```

---

## 💡 Pro Tips

1. **Keep terminal open** - Server runs in foreground with `build_and_serve.sh`
2. **Use quick_build.sh** - For faster rebuilds after code changes
3. **Check logs** - Scripts show detailed progress with colored output
4. **Test locally first** - Download APK on same machine before sharing

---

## 🔐 Security Note

These scripts use `/tmp/` directory for SDKs. This is:
- ✅ Perfect for development/testing
- ✅ Automatically cleaned on reboot
- ⚠️ Not suitable for production

For production, consider installing SDKs to permanent locations.

---

## 📝 Script Locations

```
/workspaces/HFC-App/
├── build_and_serve.sh    # Full automation script
├── quick_build.sh         # Fast rebuild script
├── app-release.apk        # Built APK (after running script)
├── download.html          # Download page (auto-updated)
└── BUILD_SCRIPTS_README.md # This file
```

---

## 🎯 Need Help?

If scripts fail:
1. Check error messages (color-coded)
2. Ensure internet connection is stable
3. Verify disk space (`df -h`)
4. Try full setup: `./build_and_serve.sh`

---

**Happy Building! 🚀**
