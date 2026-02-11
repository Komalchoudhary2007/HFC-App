#!/bin/bash

# HFC App Icon Setup Script
# This script sets up the app icon for both Android and iOS

echo "🎨 HFC App Icon Setup"
echo "====================="

# Check if app_icon.png exists in Downloads
if [ -f ~/Downloads/app_icon.png ]; then
    echo "✅ Found app_icon.png in Downloads"
    echo "📁 Copying to assets/icons/"
    cp ~/Downloads/app_icon.png ./assets/icons/app_icon.png
    echo "✅ Icon file copied successfully"
else
    echo "⚠️  app_icon.png not found in Downloads folder"
    echo "Please ensure the 1024x1024 PNG file is in your Downloads folder"
    echo "or copy it manually to: ./assets/icons/app_icon.png"
    exit 1
fi

# Install dependencies
echo ""
echo "📦 Installing dependencies..."
flutter pub get

# Generate icons
echo ""
echo "🚀 Generating app icons for Android and iOS..."
flutter pub run flutter_launcher_icons

echo ""
echo "✅ Icon generation complete!"
echo ""
echo "📱 Next steps:"
echo "1. Uninstall the current app from your device"
echo "2. Run: flutter clean"
echo "3. Run: flutter run"
echo "4. Check the app icon on your device home screen"
echo ""
echo "🎉 Done!"
