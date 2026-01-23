# Images Folder

Place your image assets here:

- `logo.png` - App logo
- `logo@2x.png` - High resolution logo (iOS)
- `logo@3x.png` - Extra high resolution logo (iOS)
- `app_icon.png` - Application icon
- `splash_screen.png` - Splash screen image
- `hc20_device.png` - HC20 device image
- `placeholder.png` - Placeholder images

## Usage in Flutter

```dart
// To use an image in your Flutter code:
Image.asset('assets/images/logo.png')

// With explicit dimensions:
Image.asset(
  'assets/images/logo.png',
  width: 200,
  height: 100,
)

// As a background:
Container(
  decoration: BoxDecoration(
    image: DecorationImage(
      image: AssetImage('assets/images/splash_screen.png'),
      fit: BoxFit.cover,
    ),
  ),
)
```

## Image Optimization Tips

1. **PNG** for logos and images with transparency
2. **JPEG** for photos
3. **WebP** for smaller file sizes (Flutter supports WebP)
4. Use appropriate resolution (avoid huge images)
5. Compress images before adding to project
