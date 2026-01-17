#!/bin/bash

# HFC App - Automated Build and Serve Script
# ==========================================
# This script automates Flutter/Android SDK installation, APK building, and server deployment

set -e  # Exit on any error

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
    flutter doctor
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

# Install Java 21
install_java() {
    print_header "Installing Java 21"
    
    if java -version 2>&1 | grep -q "openjdk version \"21"; then
        print_success "Java 21 already installed"
    else
        print_info "Installing OpenJDK 21..."
        export DEBIAN_FRONTEND=noninteractive
        sudo apt-get update -qq > /dev/null 2>&1
        sudo apt-get install -y openjdk-21-jdk > /dev/null 2>&1
        print_success "Java 21 installed"
    fi
    
    # Set Java 21 as default
    export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
    export PATH="$JAVA_HOME/bin:$PATH"
    print_info "Java version: $(java -version 2>&1 | head -n 1)"
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
    export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
    export ANDROID_HOME="$ANDROID_SDK_DIR"
    export PATH="$JAVA_HOME/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"
    
    # Accept licenses
    print_info "Accepting SDK licenses..."
    yes | sdkmanager --licenses > /dev/null 2>&1
    
    # Install required SDK packages
    print_info "Installing Android SDK packages..."
    sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0" > /dev/null 2>&1
    
    print_success "Android SDK setup complete"
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
    
    # Setup environment
    export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
    export ANDROID_HOME="$ANDROID_SDK_DIR"
    export PATH="$JAVA_HOME/bin:$FLUTTER_DIR/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"
    
    cd "$PROJECT_DIR"
    
    print_info "Cleaning project..."
    flutter clean
    
    print_info "Getting dependencies..."
    flutter pub get
    
    print_info "Building release APK (this may take several minutes)..."
    flutter build apk --release
    
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
    
    # Step 2: Install Java 21
    install_java
    
    # Step 3: Install Android SDK
    install_android_sdk
    
    # Step 4: Build APK
    build_apk
    
    # Step 5: Update download page
    update_download_page
    
    # Step 6: Start server
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
