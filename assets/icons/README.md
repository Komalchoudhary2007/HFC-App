# Icons Folder

Place your icon assets here:

- `heart.png` - Heart rate icon
- `spo2.png` - SpO2 icon
- `temperature.png` - Temperature icon
- `battery.png` - Battery icon
- `steps.png` - Steps counter icon
- `blood_pressure.png` - Blood pressure icon

## Usage in Flutter

```dart
// To use an icon in your Flutter code:
Image.asset(
  'assets/icons/heart.png',
  width: 24,
  height: 24,
  color: Colors.red, // Optional tint color
)
```

## Recommended Icon Sizes

- Small icons: 24x24 dp
- Medium icons: 48x48 dp  
- Large icons: 72x72 dp

Create multiple resolution variants:
- `icon.png` (1x)
- `icon@2x.png` (2x)
- `icon@3x.png` (3x)
