import 'package:flutter/material.dart';

/// "Çuha" paleti: nötr zemin, tek vurgu rengi masa çuhası yeşili.
///
/// Değerler `docs/plan.md` 6. bölümdeki tabloyla aynıdır. Widget'lar renkleri
/// buradan değil, `Theme.of(context).colorScheme` üzerinden okur.
/// İkinci bir vurgu rengi olmaması için `secondary` ve `tertiary` de vurgu
/// rengine bağlanmıştır.
abstract final class AppColors {
  static const ColorScheme light = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF1D6B48),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFD6EDDF),
    onPrimaryContainer: Color(0xFF0E3B26),
    secondary: Color(0xFF1D6B48),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFD6EDDF),
    onSecondaryContainer: Color(0xFF0E3B26),
    tertiary: Color(0xFF1D6B48),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFD6EDDF),
    onTertiaryContainer: Color(0xFF0E3B26),
    error: Color(0xFFB3261E),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFF9DEDC),
    onErrorContainer: Color(0xFF410E0B),
    surface: Color(0xFFF5F6F4),
    onSurface: Color(0xFF17201B),
    onSurfaceVariant: Color(0xFF57615B),
    surfaceDim: Color(0xFFE2E6E2),
    surfaceBright: Color(0xFFFFFFFF),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFFFFFFF),
    surfaceContainer: Color(0xFFF0F2EF),
    surfaceContainerHigh: Color(0xFFEAEDEA),
    surfaceContainerHighest: Color(0xFFE2E6E2),
    outline: Color(0xFF7A847E),
    outlineVariant: Color(0xFFDCE0DC),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF101311),
    inverseSurface: Color(0xFF2A302C),
    onInverseSurface: Color(0xFFF0F2F0),
    inversePrimary: Color(0xFF8FDCB0),
    surfaceTint: Color(0x00000000),
  );

  static const ColorScheme dark = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF6FCF97),
    onPrimary: Color(0xFF062A17),
    primaryContainer: Color(0xFF1D3829),
    onPrimaryContainer: Color(0xFFC2EBD3),
    secondary: Color(0xFF6FCF97),
    onSecondary: Color(0xFF062A17),
    secondaryContainer: Color(0xFF1D3829),
    onSecondaryContainer: Color(0xFFC2EBD3),
    tertiary: Color(0xFF6FCF97),
    onTertiary: Color(0xFF062A17),
    tertiaryContainer: Color(0xFF1D3829),
    onTertiaryContainer: Color(0xFFC2EBD3),
    error: Color(0xFFF2B8B5),
    onError: Color(0xFF601410),
    errorContainer: Color(0xFF8C1D18),
    onErrorContainer: Color(0xFFF9DEDC),
    surface: Color(0xFF101311),
    onSurface: Color(0xFFE6EAE7),
    onSurfaceVariant: Color(0xFF9BA49E),
    surfaceDim: Color(0xFF101311),
    surfaceBright: Color(0xFF2A2F2B),
    surfaceContainerLowest: Color(0xFF0B0D0C),
    surfaceContainerLow: Color(0xFF191D1A),
    surfaceContainer: Color(0xFF1E2220),
    surfaceContainerHigh: Color(0xFF232824),
    surfaceContainerHighest: Color(0xFF2A2F2B),
    outline: Color(0xFF6E7871),
    outlineVariant: Color(0xFF2C322E),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFFE6EAE7),
    onInverseSurface: Color(0xFF1E2320),
    inversePrimary: Color(0xFF1D6B48),
    surfaceTint: Color(0x00000000),
  );

  /// Bottom sheet ve diyalog arkasındaki perdenin opaklığı.
  static const double scrimOpacity = 0.45;
}
