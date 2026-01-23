# HFC App

A Flutter mobile application project for cross-platform development.

## 🚀 Getting Started

This Flutter project has been set up and is ready for development.

### Prerequisites
- Flutter SDK (v3.24.5 or later)
- Dart SDK (v3.5.4 or later)
- Android Studio / VS Code with Flutter extensions

### Running the App

1. **Install dependencies:**
   ```bash
   flutter pub get
   ```

2. **Run on web (currently running):**
   ```bash
   flutter run -d web-server --web-port=8080
   ```
   Access at: http://localhost:8080

3. **Run on other platforms:**
   ```bash
   flutter run    # Auto-detect device
   flutter run -d android    # Android
   flutter run -d ios        # iOS
   ```

## 📁 Project Structure

- `lib/` - Main application source code
- `test/` - Unit and widget tests
- `docs/` - Detailed documentation
- Platform-specific folders: `android/`, `ios/`, `web/`, etc.

## 📖 Documentation

For detailed development process and architecture information, see [`docs/README.md`](docs/README.md).

## 🛠 Development

- **Hot Reload**: Press `r` in terminal while app is running
- **Hot Restart**: Press `R` in terminal while app is running
- **Quit**: Press `q` in terminal

## 📱 Platform Support

- ✅ Android
- ✅ iOS  
- ✅ Web
- ✅ Windows
- ✅ Linux
- ✅ macOS

---

Built with ❤️ using Flutter

Git Commands
See all modified files: git status
See changes in all files: git diff
See staged changes: git diff --staged

git diff android/app/src/main/kotlin/com/example/hfc_app/AppRestartWorker.kt

## 📱 Connect Android Phone Wirelessly

### Prerequisites
- Phone and Mac on same Wi-Fi network
- Enable "Developer options" on phone
- Enable "Wireless debugging" in Developer options

### Step-by-Step Connection Process

#### Step 1: Add adb to PATH (run once per terminal session)
```bash
export PATH="/Users/developer/Library/Android/sdk/platform-tools:$PATH"
```

#### Step 2: Get pairing info from phone
1. Open phone → Settings → Developer options → Wireless debugging
2. Tap "Pair device with pairing code"
3. Note down:
   - **IP address & pairing port** (e.g., 192.168.1.8:34735)
   - **Pairing code** (6-digit code, e.g., 892169)

#### Step 3: Pair the phone (first time or after reboot)
```bash
# Replace IP:PORT and PAIRING_CODE with values from Step 2
adb pair 192.168.1.8:34735
# Enter pairing code when prompted: 892169
```

#### Step 4: Get connection port from phone
1. Go back to "Wireless debugging" main screen (not pairing screen)
2. Note the **IP address & port** shown at top (e.g., 192.168.1.8:45779)
   - ⚠️ This port is DIFFERENT from the pairing port!

#### Step 5: Connect to phone
```bash
# Replace IP:PORT with connection port from Step 4
adb connect 192.168.1.8:45779
```

#### Step 6: Verify connection
```bash
adb devices -l
# Should show: 192.168.1.8:45779    device ...
```

#### Step 7: Verify Flutter sees the device
```bash
flutter devices
# Should list your phone model (e.g., M2003J15SC)
```

#### Step 8: Run the app on phone
```bash
flutter run -d 192.168.1.8:45779
```

### 🔄 Reconnect After Lost Connection

When the terminal disconnects (you closed terminal, pressed 'q', or Mac went to sleep), the app keeps running on your phone but you can't see logs anymore.

**Option 1: Restart app with logs (RECOMMENDED)**
```bash
export PATH="/Users/developer/Library/Android/sdk/platform-tools:$PATH"
flutter run -d 192.168.1.12:45383
```
This will restart the app in debug mode and show logs immediately.

**Option 2: Attach to running app (only works if app was started with `flutter run`)**
```bash
flutter attach -d 192.168.1.12:45383
```
⚠️ **Note**: This only works if the app is running in debug mode. If you opened the app from the phone's app drawer, it runs in release mode and `flutter attach` won't work.

**Option 3: Just use the app (no logs needed)**
- The app is already installed and working
- Open it from your phone's app drawer
- Background services work even without logs showing
- Use Option 1 above when you need to see logs again

### Quick Reconnect (after phone stays on same Wi-Fi)
If phone was already paired and still on same network:
```bash
export PATH="/Users/developer/Library/Android/sdk/platform-tools:$PATH"
adb connect 192.168.1.8:45779
flutter run -d 192.168.1.8:45779
```

### Troubleshooting
- **Connection refused**: Restart "Wireless debugging" on phone, ports may have changed
- **Can't find adb**: Run Step 1 again or install platform-tools: `brew install android-platform-tools`
- **Protocol fault when pairing**: Make sure you're using the **pairing port** (from "Pair device" screen)
- **Flutter doesn't see device**: Make sure you're using the **connection port** (from main Wireless debugging screen)

### Alternative: USB Connection
```bash
# 1. Connect phone via USB cable
adb devices

# 2. Switch to TCP/IP mode
adb tcpip 5555

# 3. Disconnect USB and connect wirelessly
adb connect 192.168.1.8:5555

# 4. Run app
flutter run -d 192.168.1.8:5555
```