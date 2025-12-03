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