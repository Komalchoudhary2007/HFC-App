#!/bin/bash
#run with: bash build_and_serve.sh
# HFC App - Automated Build and Serve Script
# ==========================================
# This script automates Flutter/Android SDK installation, APK building, and server deployment

set -e  # Exit on any error

# Fix bash path issue for Flutter scripts
if [ ! -f /usr/bin/env ]; then
    echo "Warning: /usr/bin/env not found, creating symlink..."
    sudo ln -sf /bin/env /usr/bin/env 2>/dev/null || true
fi

# Ensure bash is available for Flutter scripts
if ! command -v bash &> /dev/null; then
    echo "Error: bash not found in PATH"
    exit 1
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
FLUTTER_DIR="/tmp/flutter"
ANDROID_SDK_DIR="/tmp/android-sdk"
PROJECT_DIR="/workspaces/HFC-App"
SERVER_PORT=8080

# Functions
print_header() {
    echo -e "\n${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

# Check if Flutter is already installed
check_flutter() {
    if [ -d "$FLUTTER_DIR" ] && [ -f "$FLUTTER_DIR/bin/flutter" ]; then
        print_success "Flutter SDK already installed at $FLUTTER_DIR"
        return 0
    else
        return 1
    fi
}

# Install Flutter SDK
install_flutter() {
    print_header "Installing Flutter SDK"
    
    if check_flutter; then
        print_info "Skipping Flutter installation"
    else
        print_info "Cloning Flutter stable channel..."
        cd /tmp
        git clone https://github.com/flutter/flutter.git -b stable --depth 1
        print_success "Flutter SDK installed"
    fi
    
    # Add Flutter to PATH
    export PATH="$PATH:$FLUTTER_DIR/bin"
    
    # Run flutter doctor to download Dart SDK
    print_info "Running flutter doctor..."
    $FLUTTER_DIR/bin/flutter doctor
    print_success "Flutter setup complete"
}

# Check if Android SDK is installed
check_android_sdk() {
    if [ -d "$ANDROID_SDK_DIR/cmdline-tools/latest" ]; then
        print_success "Android SDK already installed at $ANDROID_SDK_DIR"
        return 0
    else
        return 1
    fi
}

# Install Android SDK
install_android_sdk() {
    print_header "Installing Android SDK"
    
    if check_android_sdk; then
        print_info "Skipping Android SDK installation"
    else
        print_info "Creating Android SDK directory..."
        mkdir -p "$ANDROID_SDK_DIR/cmdline-tools"
        cd "$ANDROID_SDK_DIR/cmdline-tools"
        
        print_info "Downloading Android command-line tools..."
        wget -q https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip -O cmdline-tools.zip
        
        print_info "Extracting tools..."
        unzip -q cmdline-tools.zip
        mv cmdline-tools latest
        rm cmdline-tools.zip
        
        print_success "Android SDK command-line tools installed"
    fi
    
    # Setup environment variables
    export ANDROID_HOME="$ANDROID_SDK_DIR"
    export PATH="$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools"
    
    # Accept licenses
    print_info "Accepting SDK licenses..."
    yes | sdkmanager --licenses > /dev/null 2>&1
    
    # Install required SDK packages
    print_info "Installing Android SDK packages..."
    sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0" > /dev/null 2>&1
    
    print_success "Android SDK setup complete"
}

# Increment build number in pubspec.yaml
increment_version() {
    print_header "Incrementing Build Number"
    
    cd "$PROJECT_DIR"
    
    # Read current version from pubspec.yaml
    CURRENT_VERSION=$(grep "^version:" pubspec.yaml | awk '{print $2}')
    
    # Split version into name and build number
    VERSION_NAME=$(echo $CURRENT_VERSION | cut -d'+' -f1)
    BUILD_NUMBER=$(echo $CURRENT_VERSION | cut -d'+' -f2)
    
    # Split version name into major.minor.patch
    MAJOR=$(echo $VERSION_NAME | cut -d'.' -f1)
    MINOR=$(echo $VERSION_NAME | cut -d'.' -f2)
    PATCH=$(echo $VERSION_NAME | cut -d'.' -f3)
    
    # Increment patch version (8.0.10 -> 8.0.11)
    NEW_PATCH=$((PATCH + 1))
    NEW_VERSION_NAME="${MAJOR}.${MINOR}.${NEW_PATCH}"
    
    # Reset build number to 1 for new version
    NEW_BUILD_NUMBER=1
    NEW_VERSION="${NEW_VERSION_NAME}+${NEW_BUILD_NUMBER}"
    
    print_info "Current Version: $CURRENT_VERSION"
    print_info "New Version: $NEW_VERSION"
    
    # Update pubspec.yaml with new version
    sed -i "s/^version: .*/version: $NEW_VERSION/" pubspec.yaml
    
    print_success "Version incremented: $VERSION_NAME → $NEW_VERSION_NAME (build: $NEW_BUILD_NUMBER)"
}

# Update version in download.html
update_download_page() {
    print_header "Updating Download Page"
    
    # Get current date
    CURRENT_DATE=$(date "+%B %d, %Y")
    
    # Read version from pubspec.yaml
    VERSION=$(grep "^version:" "$PROJECT_DIR/pubspec.yaml" | awk '{print $2}')
    
    print_info "Version: $VERSION"
    print_info "Date: $CURRENT_DATE"
    
    # Update download.html with new version and date
    sed -i "s/<p class=\"version\">Version.*<\/p>/<p class=\"version\">Version $VERSION - Latest Build ($CURRENT_DATE)<\/p>/" "$PROJECT_DIR/download.html"
    
    print_success "Download page updated"
}

# Build APK
build_apk() {
    print_header "Building APK"
    
    # Setup environment with Java 21 (required for Gradle 8.11.1)
    export JAVA_HOME="/usr/local/sdkman/candidates/java/21.0.9-ms"
    export ANDROID_HOME="$ANDROID_SDK_DIR"
    export PATH="$JAVA_HOME/bin:$FLUTTER_DIR/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"
    
    # Additional environment variables for Gradle
    export ANDROID_SDK_ROOT="$ANDROID_SDK_DIR"
    
    # Gradle options to prevent daemon crashes in low-memory environments
    export GRADLE_OPTS="-Xmx2048m -Dorg.gradle.jvmargs='-Xmx2048m -XX:MaxMetaspaceSize=512m' -Dorg.gradle.daemon=false"
    
    print_info "Environment Setup:"
    print_info "JAVA_HOME: $JAVA_HOME"
    print_info "ANDROID_HOME: $ANDROID_HOME"
    print_info "Flutter: $FLUTTER_DIR/bin/flutter"
    print_info "Gradle configured with no-daemon mode for stability"
    
    print_info "Using Java version:"
    java -version 2>&1 | head -n 2
    
    cd "$PROJECT_DIR"
    
    # Kill any existing Gradle daemons to free memory
    print_info "Stopping existing Gradle daemons..."
    cd android && ./gradlew --stop 2>/dev/null || true
    cd "$PROJECT_DIR"
    
    # Clean with proper error handling
    print_info "Cleaning project..."
    if ! $FLUTTER_DIR/bin/flutter clean 2>&1; then
        print_error "Flutter clean failed, but continuing..."
    fi
    
    print_info "Getting dependencies..."
    $FLUTTER_DIR/bin/flutter pub get
    
    print_info "Building release APK (this may take several minutes)..."
    print_info "Using no-daemon mode to prevent memory issues..."
    $FLUTTER_DIR/bin/flutter build apk --release
    
    # Verify APK was created
    if [ ! -f "build/app/outputs/flutter-apk/app-release.apk" ]; then
        print_error "APK build failed - file not found"
        exit 1
    fi
    
    # Copy APK to root directory
    print_info "Copying APK to root directory..."
    cp build/app/outputs/flutter-apk/app-release.apk app-release.apk
    
    # Get APK size
    APK_SIZE=$(ls -lh app-release.apk | awk '{print $5}')
    
    print_success "APK built successfully!"
    print_info "APK Location: $PROJECT_DIR/app-release.apk"
    print_info "APK Size: $APK_SIZE"
}

# Stop existing server
stop_server() {
    print_info "Stopping any existing servers on port $SERVER_PORT..."
    pkill -f "python3 -m http.server $SERVER_PORT" 2>/dev/null || true
    sleep 1
}

# Start HTTP server
start_server() {
    print_header "Starting HTTP Server"
    
    stop_server
    
    cd "$PROJECT_DIR"
    
    print_info "Starting server on port $SERVER_PORT..."
    nohup python3 -m http.server $SERVER_PORT > /dev/null 2>&1 &
    
    sleep 2
    
    if pgrep -f "python3 -m http.server $SERVER_PORT" > /dev/null; then
        print_success "Server started successfully!"
        echo ""
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}   🚀 Server is now running!${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo -e "📥 ${BLUE}Download Page:${NC} http://localhost:$SERVER_PORT/download.html"
        echo -e "📦 ${BLUE}Direct APK:${NC}    http://localhost:$SERVER_PORT/app-release.apk"
        echo ""
        echo -e "${YELLOW}Press Ctrl+C to stop the server${NC}"
        echo ""
    else
        print_error "Failed to start server"
        exit 1
    fi
}

# Main execution
main() {
    clear
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════╗"
    echo "║  HFC App - Build & Serve Automation     ║"
    echo "║  Automated Flutter APK Builder           ║"
    echo "╚══════════════════════════════════════════╝"
    echo -e "${NC}\n"
    
    print_info "Starting automated build process..."
    echo ""
    
    # Step 1: Install Flutter
    install_flutter
    
    # Step 2: Install Android SDK
    install_android_sdk
    
    # Step 3: Increment version number
    increment_version
    
    # Step 4: Build APK
    build_apk
    
    # Step 5: Update download page
    update_download_page
    
    # Step 5: Start server
    start_server
    
    # Keep script running to maintain server
    echo -e "\n${GREEN}✓ All tasks completed successfully!${NC}\n"
    
    # Wait for user interrupt
    trap 'echo -e "\n${YELLOW}Stopping server...${NC}"; stop_server; echo -e "${GREEN}Server stopped${NC}"; exit 0' INT
    
    while true; do
        sleep 1
    done
}

# Run main function
main

# export JAVA_HOME="/usr/local/sdkman/candidates/java/21.0.9-ms" && export ANDROID_HOME="/tmp/android-sdk" && export PATH="$JAVA_HOME/bin:/tmp/flutter/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH" && /tmp/flutter/bin/flutter build apk --release 2>&1
# export JAVA_HOME="/usr/local/sdkman/candidates/java/21.0.9-ms" && export ANDROID_HOME="/tmp/android-sdk" && export PATH="$JAVA_HOME/bin:/tmp/flutter/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH" && cd /workspaces/HFC-App && /tmp/flutter/bin/flutter build apk --release 2>&1
# flutter build apk --release 2>&1 | tail -50