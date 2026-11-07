import 'package:flutter/material.dart';

/// Yazı ölçeği. Sistem fontu kullanılır (iOS'ta SF Pro, Android'de Roboto),
/// sadece iki ağırlık var: [regular] ve [semibold].
abstract final class AppTypography {
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight semibold = FontWeight.w600;

  /// Rakamların eşit genişlikte çizilmesi; skor sütunları kaymasın diye.
  static const List<FontFeature> tabularFigures = [
    FontFeature.tabularFigures(),
  ];

  static const TextTheme textTheme = TextTheme(
    // Kazanan ismi.
    displaySmall: TextStyle(
      fontSize: 34,
      height: 40 / 34,
      fontWeight: semibold,
    ),
    // Ana sayfa başlığı.
    headlineSmall: TextStyle(
      fontSize: 28,
      height: 34 / 28,
      fontWeight: semibold,
    ),
    // App bar başlıkları.
    titleLarge: TextStyle(fontSize: 22, height: 28 / 22, fontWeight: semibold),
    // Bölüm başlıkları, kart başlıkları.
    titleMedium: TextStyle(
      fontSize: 17,
      height: 22 / 17,
      fontWeight: semibold,
      letterSpacing: 0,
    ),
    // Kontrollerin üstündeki etiketler.
    titleSmall: TextStyle(
      fontSize: 14,
      height: 20 / 14,
      fontWeight: semibold,
      letterSpacing: 0,
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      height: 22 / 16,
      fontWeight: regular,
      letterSpacing: 0,
    ),
    bodyMedium: TextStyle(
      fontSize: 15,
      height: 20 / 15,
      fontWeight: regular,
      letterSpacing: 0,
    ),
    // Açıklamalar; 12 pt altına inilmez.
    bodySmall: TextStyle(
      fontSize: 13,
      height: 18 / 13,
      fontWeight: regular,
      letterSpacing: 0,
    ),
    // Buton yazıları.
    labelLarge: TextStyle(
      fontSize: 17,
      height: 22 / 17,
      fontWeight: semibold,
      letterSpacing: 0,
    ),
    labelMedium: TextStyle(
      fontSize: 14,
      height: 20 / 14,
      fontWeight: semibold,
      letterSpacing: 0,
    ),
    // Küçük rozetler (ör. "x2").
    labelSmall: TextStyle(
      fontSize: 12,
      height: 16 / 12,
      fontWeight: semibold,
      letterSpacing: 0,
    ),
  );

  /// Büyük ana aksiyon butonlarının yazısı.
  static const TextStyle primaryButton = TextStyle(
    fontSize: 18,
    height: 24 / 18,
    fontWeight: semibold,
    letterSpacing: 0,
  );
}

/// Skor rakamları için yazı stilleri. Hepsi eşit genişlikli rakam kullanır.
///
/// `Theme.of(context).extension<ScoreTextTheme>()!` ile okunur.
@immutable
class ScoreTextTheme extends ThemeExtension<ScoreTextTheme> {
  const ScoreTextTheme({
    required this.total,
    required this.cell,
    required this.entry,
    required this.key,
  });

  factory ScoreTextTheme.fromScheme(ColorScheme scheme) {
    TextStyle style(double size, double lineHeight, FontWeight weight) =>
        TextStyle(
          fontSize: size,
          height: lineHeight / size,
          fontWeight: weight,
          color: scheme.onSurface,
          letterSpacing: 0,
          fontFeatures: AppTypography.tabularFigures,
        );

    return ScoreTextTheme(
      total: style(30, 36, AppTypography.semibold),
      cell: style(20, 26, AppTypography.regular),
      entry: style(18, 24, AppTypography.semibold),
      key: style(22, 28, AppTypography.regular),
    );
  }

  /// Sabit üst satırdaki toplamlar; masanın ortasından okunacak büyüklükte.
  final TextStyle total;

  /// Tablodaki el puanları.
  final TextStyle cell;

  /// El girişindeki sayı alanları ve önizleme.
  final TextStyle entry;

  /// Numerik tuş takımı.
  final TextStyle key;

  @override
  ScoreTextTheme copyWith({
    TextStyle? total,
    TextStyle? cell,
    TextStyle? entry,
    TextStyle? key,
  }) => ScoreTextTheme(
    total: total ?? this.total,
    cell: cell ?? this.cell,
    entry: entry ?? this.entry,
    key: key ?? this.key,
  );

  @override
  ScoreTextTheme lerp(ScoreTextTheme? other, double t) {
    if (other == null) return this;
    return ScoreTextTheme(
      total: TextStyle.lerp(total, other.total, t)!,
      cell: TextStyle.lerp(cell, other.cell, t)!,
      entry: TextStyle.lerp(entry, other.entry, t)!,
      key: TextStyle.lerp(key, other.key, t)!,
    );
  }
}
