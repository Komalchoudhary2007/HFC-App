#!/bin/bash

# HFC App - Quick Icon Update Script
# Run this script after updating app_icon.png

echo "🎨 HFC App Icon Regeneration"
echo "=============================="
echo ""

# Check if icon file exists
if [ ! -f "assets/icons/app_icon.png" ]; then
    echo "❌ Error: assets/icons/app_icon.png not found!"
    echo "Please ensure your 1024x1024 icon is at: assets/icons/app_icon.png"
    exit 1
fi

echo "✅ Found app_icon.png"
echo ""

# Clean build
echo "🧹 Cleaning build cache..."
flutter clean
echo ""

# Get dependencies
echo "📦 Getting dependencies..."
flutter pub get
echo ""

# Regenerate icons
echo "🚀 Regenerating app icons..."
flutter pub run flutter_launcher_icons
echo ""

# Show results
echo "✅ Icon generation complete!"
echo ""
echo "📱 Generated icons:"
echo "   • Android: 5 sizes (mdpi to xxxhdpi)"
echo "   • iOS: 21 icon files"
echo "   • Adaptive icons: Purple background (#532A7B)"
echo ""
echo "⚠️  IMPORTANT: To see the new icon on your device:"
echo ""
echo "1. Uninstall the current app from your device"
echo "   (Long press app icon → Uninstall)"
echo ""
echo "2. Run one of these commands:"
echo "   • flutter run                      (Debug build)"
echo "   • flutter build apk --release      (Release APK)"
echo ""
echo "3. Verify the icon appears properly sized (not zoomed)"
echo ""
echo "🎉 Done! Your icon is ready for testing."
