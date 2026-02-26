# HFC App Documentation

**Last Updated**: Feb 16, 2026  
**Project**: HC20 Wearable Health Monitoring App

Complete documentation for the HFC stress management system for special needs parents with HC20 wearable integration.

---

## 📚 DOCUMENTATION STRUCTURE

This documentation is organized into **8 main categories** for easy navigation:

```
docs/
├── 00-START-HERE/              ⭐ Read these first!
├── 01-Analysis/                🔍 Root cause analysis & deep dives
├── 02-Implementation-History/  📝 What we built & when
├── 03-Architecture/            🏗️ System design & structure
├── 04-Testing/                 🧪 Test guides & results
├── 05-Setup-Guides/            ⚙️ Installation & configuration
├── 06-Reference/               📖 Quick references & guides
├── 07-Legacy/                  📦 Archived/historical docs
└── logs/                       📊 Test logs & debug output
```

---

## ⭐ START HERE (New Developers)

### **00-START-HERE/** - Essential Documents

| Document | Purpose | Read Time |
|----------|---------|-----------|
| **[README_DOCUMENTATION.md](./00-START-HERE/README_DOCUMENTATION.md)** | Complete navigation guide | 10 min |
| **[CODE_CHANGES_MASTER_LOG.md](./00-START-HERE/CODE_CHANGES_MASTER_LOG.md)** | Change history with impact analysis | 20 min |
| **[KNOWN_ISSUES_TRACKER.md](./00-START-HERE/KNOWN_ISSUES_TRACKER.md)** | Current bugs & improvements | 15 min |
| **[DATA_CONSUMPTION_ANALYSIS.md](./00-START-HERE/DATA_CONSUMPTION_ANALYSIS.md)** | 🔥 Why app uses 26MB/day + fixes | 25 min |
| **[PERFORMANCE_OPTIMIZATION_RECOMMENDATIONS.md](./00-START-HERE/PERFORMANCE_OPTIMIZATION_RECOMMENDATIONS.md)** | Speed improvements | 15 min |
| **[SDK_CODE_MODIFICATIONS.md](./00-START-HERE/SDK_CODE_MODIFICATIONS.md)** | SDK changes (none currently) | 10 min |

**For New Developers**: Read first 3 documents (~45 min total)

---

## 🎯 Project Overview

This is a Flutter mobile application integrated with HC20 wearable device for the **7-month Proof of Concept study** to help parents of special needs children manage stress through continuous monitoring and psychologist-led interventions.

## 🔍 Quick Navigation by Task

### I need to...

**Understand what changed recently**  
→ [CODE_CHANGES_MASTER_LOG.md](./00-START-HERE/CODE_CHANGES_MASTER_LOG.md)

**Fix a bug**  
→ [KNOWN_ISSUES_TRACKER.md](./00-START-HERE/KNOWN_ISSUES_TRACKER.md) → Pick top issue  
→ [01-Analysis/](./01-Analysis/) → Find related analysis  

**Make the app faster**  
→ [PERFORMANCE_OPTIMIZATION_RECOMMENDATIONS.md](./00-START-HERE/PERFORMANCE_OPTIMIZATION_RECOMMENDATIONS.md)

**Understand system architecture**  
→ [BLE_CONNECTION_LIFECYCLE.md](./03-Architecture/BLE_CONNECTION_LIFECYCLE.md)  
→ [HC20_CONNECTION_MANAGEMENT_EXPLAINED.md](./03-Architecture/HC20_CONNECTION_MANAGEMENT_EXPLAINED.md)

**Test a feature**  
→ [QUICK_TESTING_GUIDE.md](./04-Testing/QUICK_TESTING_GUIDE.md)  
→ [RECONNECTION_FIXES_QUICK_TEST.md](./04-Testing/RECONNECTION_FIXES_QUICK_TEST.md)

**Look up a method or pattern**  
→ [MAIN_DART_METHODS_INVENTORY.md](./06-Reference/MAIN_DART_METHODS_INVENTORY.md)  
→ [HC20_SDK_QUICK_REFERENCE.md](./06-Reference/HC20_SDK_QUICK_REFERENCE.md)

**Setup development environment**  
→ [05-Setup-Guides/](./05-Setup-Guides/)  
→ [QUICK_START.md](./07-Legacy/done-implementation/QUICK_START.md)

---

## 📁 Folder Details

### 00-START-HERE/ (5 files)
Core strategic documents - start here for complete project understanding.

### 01-Analysis/ (20 files)
Deep technical analysis of reconnection issues, performance problems, and system behavior.

### 02-Implementation-History/ (36 files)
Complete implementation timeline - every fix, feature, and phase completion documented.

### 03-Architecture/ (9 files)
System design documents, flow diagrams, and architectural decisions.

### 04-Testing/ (11 files)
Test protocols, results, and verification guides for all major features.

### 05-Setup-Guides/ (2 files)
Installation and configuration guides for app setup.

### 06-Reference/ (20 files + subdirs)
Quick reference guides, SDK documentation, method inventories, and implementation patterns.

**Subdirectories**:
- `future-implementations/` - Planned features & improvements
- `main/` - Main app documentation

### 07-Legacy/ (28 files + subdirs)
Archived historical documents, completed phase docs, and old analysis.

**Subdirectories**:
- `done-implementation/` - Completed docs (QUICK_START, API_DOCUMENTATION, etc.)

---

## 🚀 Getting Started

### For New Developers (75 min):
1. Read [README_DOCUMENTATION.md](./00-START-HERE/README_DOCUMENTATION.md) (10 min)
2. Read [CODE_CHANGES_MASTER_LOG.md](./00-START-HERE/CODE_CHANGES_MASTER_LOG.md) (20 min)
3. Read [KNOWN_ISSUES_TRACKER.md](./00-START-HERE/KNOWN_ISSUES_TRACKER.md) (15 min)
4. Skim [03-Architecture/](./03-Architecture/) (30 min)

### For Bug Fixes:
1. Pick issue from [KNOWN_ISSUES_TRACKER.md](./00-START-HERE/KNOWN_ISSUES_TRACKER.md)
2. Read related analysis in [01-Analysis/](./01-Analysis/)
3. Check similar fixes in [02-Implementation-History/](./02-Implementation-History/)
4. Test using guides in [04-Testing/](./04-Testing/)

### For Performance Work:
1. Read [PERFORMANCE_OPTIMIZATION_RECOMMENDATIONS.md](./00-START-HERE/PERFORMANCE_OPTIMIZATION_RECOMMENDATIONS.md)
2. Pick from "Quick Wins" section
3. Check analysis in [01-Analysis/](./01-Analysis/)
4. Implement & benchmark

---

## 📊 Documentation Statistics

- **Total Documents**: ~130+ files
- **Core Strategic**: 5 files (00-START-HERE)
- **Analysis**: 20 files
- **Implementation History**: 36 files
- **Architecture**: 9 files
- **Testing**: 11 files
- **Setup**: 2 files
- **Reference**: 20 files + subdirs
- **Legacy**: 28 files + subdirs

**Most Important**: 5 files in [00-START-HERE/](./00-START-HERE/) (~1,800 lines total)

---

## ✅ Version History

**Documentation Version**: 2.0  
**Last Major Reorganization**: Feb 16, 2026  
**Previous Structure**: Flat directory (130+ files in root)  
**Current Structure**: 8 organized categories

**Change Log**:
- v2.0 (Feb 16, 2026): Major reorganization into categories
- v1.0 (Feb 15, 2026): Created strategic documentation set

---

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