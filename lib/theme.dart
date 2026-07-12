import 'package:flutter/material.dart';

/// Palette ported 1:1 from the original HTML `:root` custom properties.
class AppColors {
  static const bg = Color(0xFFF3F5F8);
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF023047);
  static const muted = Color(0xFF68788A);
  static const line = Color(0xFFE2E8EF);
  static const danger = Color(0xFFD64545);
  static const amber = Color(0xFFB87A00);

  /// Board color palette (COLORS array in the HTML).
  static const boardPalette = <Color>[
    Color(0xFF2E86AB),
    Color(0xFFE76F51),
    Color(0xFF588157),
    Color(0xFF7B5EA7),
    Color(0xFFC95D8A),
    Color(0xFFB8860B),
    Color(0xFF3C7C74),
    Color(0xFF5A6B8C),
  ];

  /// Parse a `#RRGGBB` string (as stored in JSON) into a [Color].
  static Color fromHex(String hex) {
    var h = hex.replaceAll('#', '');
    if (h.length == 6) h = 'FF$h';
    return Color(int.parse(h, radix: 16));
  }

  /// Serialize a [Color] back to `#RRGGBB`.
  static String toHex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

class AppRadius {
  static const card = 18.0;
  static const sheet = 24.0;
}

/// Soft two-layer shadow matching `--shadow`.
const List<BoxShadow> kCardShadow = [
  BoxShadow(color: Color(0x0D16222F), blurRadius: 2, offset: Offset(0, 1)),
  BoxShadow(color: Color(0x0F16222F), blurRadius: 20, offset: Offset(0, 6)),
];

/// Bundled font families (declared in pubspec.yaml).
const String kBodyFont = 'Assistant';
const String kDisplayFont = 'SecularOne';

ThemeData buildTheme() {
  final base = ThemeData(useMaterial3: true, brightness: Brightness.light);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.ink,
      surface: AppColors.surface,
      error: AppColors.danger,
    ),
    textTheme: base.textTheme.apply(
      fontFamily: kBodyFont,
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
  );
}

/// Secular One display style (used for big headers).
TextStyle displayStyle({double size = 30, Color? color}) => TextStyle(
      fontFamily: kDisplayFont,
      fontSize: size,
      height: 1.15,
      color: color ?? AppColors.ink,
    );
