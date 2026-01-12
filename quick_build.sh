#!/bin/bash

# Quick Build Script - For when Flutter/Android SDK are already installed
# ========================================================================

set -e

echo "🚀 Quick Build & Serve Script"
echo "=============================="
echo ""

# Configuration
FLUTTER_DIR="/tmp/flutter"
ANDROID_SDK_DIR="/tmp/android-sdk"
PROJECT_DIR="/workspaces/HFC-App"
SERVER_PORT=8080

# Setup environment
export PATH="$PATH:$FLUTTER_DIR/bin"
export ANDROID_HOME="$ANDROID_SDK_DIR"
export PATH="$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools"

cd "$PROJECT_DIR"

# Check if Flutter is installed
if [ ! -d "$FLUTTER_DIR" ]; then
    echo "❌ Flutter not found! Run ./build_and_serve.sh first"
    exit 1
fi

# Build APK
echo "📦 Building APK..."
flutter clean
flutter pub get
flutter build apk --release

# Copy APK
echo "📋 Copying APK..."
cp build/app/outputs/flutter-apk/app-release.apk app-release.apk

# Update download page
echo "📄 Updating download page..."
CURRENT_DATE=$(date "+%B %d, %Y")
VERSION=$(grep "^version:" pubspec.yaml | awk '{print $2}')
sed -i "s/<p class=\"version\">Version.*<\/p>/<p class=\"version\">Version $VERSION - Latest Build ($CURRENT_DATE)<\/p>/" download.html

# Stop existing server
pkill -f "python3 -m http.server $SERVER_PORT" 2>/dev/null || true
sleep 1

# Start server
echo "🌐 Starting server..."
nohup python3 -m http.server $SERVER_PORT > /dev/null 2>&1 &

sleep 2

echo ""
echo "✅ Done!"
echo ""
echo "📥 Download: http://localhost:$SERVER_PORT/download.html"
echo "📦 APK Size: $(ls -lh app-release.apk | awk '{print $5}')"
echo ""
