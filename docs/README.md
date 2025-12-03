# HFC App Development Documentation

## Project Overview
This is a Flutter mobile application project called HFC App. The project was created as a cross-platform mobile application using Flutter framework.

## Development Process

### 1. Project Setup
- **Date**: December 2, 2025
- **Environment**: Ubuntu 24.04.3 LTS in a dev container
- **Flutter Version**: 3.24.5 (stable channel)
- **Dart Version**: 3.5.4

### 2. Installation Steps
1. Downloaded Flutter SDK from the official repository
2. Extracted Flutter to `/tmp/flutter/`
3. Added Flutter to system PATH
4. Created new Flutter project with `flutter create . --project-name hfc_app`

### 3. Project Structure
The project follows the standard Flutter project structure:

```
/workspaces/HFC-App/
├── android/          # Android-specific code
├── ios/              # iOS-specific code
├── lib/              # Main Dart source code
│   └── main.dart     # Entry point of the application
├── test/             # Test files
├── web/              # Web-specific assets
├── windows/          # Windows-specific code
├── linux/            # Linux-specific code
├── macos/            # macOS-specific code
├── docs/             # Documentation folder (this file)
├── pubspec.yaml      # Project dependencies and metadata
└── README.md         # Project README
```

### 4. Key Files
- **`lib/main.dart`**: Contains the main application code and UI
- **`pubspec.yaml`**: Manages project dependencies and configuration
- **`test/widget_test.dart`**: Contains widget tests for the application

### 5. Development Environment
- **IDE**: VS Code with Flutter/Dart extensions
- **Platform Support**: Android, iOS, Web, Windows, Linux, macOS
- **Container**: Dev container with all necessary tools pre-installed

### 6. Getting Started
To run the application:
```bash
# Make sure Flutter is in your PATH
export PATH="$PATH:/tmp/flutter/bin"

# Navigate to project directory
cd /workspaces/HFC-App

# Get dependencies
flutter pub get

# Run the application
flutter run
```

### 7. Development Workflow
1. **Code Development**: Primary development in `lib/` directory
2. **Testing**: Use `flutter test` for running unit and widget tests
3. **Hot Reload**: Enabled during development for fast iteration
4. **Build**: Use `flutter build` for production builds

### 8. HC20 SDK Integration
**Date**: December 2, 2025

The app now integrates the HC20 SDK for wearable device connectivity and data collection:

#### Features Implemented:
- **Device Discovery**: Bluetooth scanning for HC20 wearable devices
- **Device Connection**: Connect and authenticate with HC20 devices
- **Real-time Data**: Live streaming of health metrics including:
  - Heart rate monitoring
  - Blood oxygen (SpO2) levels
  - Blood pressure readings
  - Temperature monitoring
  - Step counting
  - Battery status
- **Historical Data**: Retrieve stored health data from the device
- **Cloud Integration**: Automatic upload of HRV and RRI data to Nitto Cloud

#### SDK Dependencies Added:
- `hc20`: Local SDK for wearable device integration
- `permission_handler`: For Bluetooth and location permissions

#### Key Components:
- **HC20 Client**: Main interface for device communication
- **Real-time Streaming**: Live health metrics display
- **History Retrieval**: Access to stored device data
- **Permission Management**: Proper Bluetooth access handling

#### Configuration Required:
Replace the placeholder credentials in `main.dart`:
```dart
clientId: 'your-client-id',      // Obtain from development team
clientSecret: 'your-client-secret'  // Obtain from development team
```

### 9. Next Steps
- Customize the app's UI and functionality in `lib/main.dart`
- Add additional packages as needed in `pubspec.yaml`
- Implement features based on project requirements
- Set up CI/CD pipeline for automated testing and deployment

### 9. Next Steps
- Replace OAuth credentials with actual values from the development team
- Test with real HC20 wearable devices
- Implement background sync for continuous data upload
- Add data visualization and analytics features
- Implement user authentication and data management
- Add proper error handling and retry mechanisms
- Optimize UI for better user experience

### 10. Resources
- [Flutter Documentation](https://docs.flutter.dev/)
- [Dart Documentation](https://dart.dev/guides)
- [Flutter API Reference](https://api.flutter.dev/)
- [Flutter YouTube Channel](https://www.youtube.com/c/flutterdev)

### 11. Notes
- Java version compatibility check needed for Android builds
- All major platforms (Android, iOS, Web, Desktop) are configured
- Project uses stable Flutter channel for production readiness

---
*This documentation was generated during the initial project setup on December 2, 2025*