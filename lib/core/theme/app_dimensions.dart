import 'package:flutter/widgets.dart';

/// 4/8 pt boşluk sistemi. Widget'larda sabit sayı yerine bunlar kullanılır.
abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  /// Ekran kenar boşluğu.
  static const double screen = md;
}

/// Köşe yuvarlaklıkları.
abstract final class AppRadius {
  /// Tuş, etiket, giriş alanı.
  static const double sm = 8;

  /// Buton, kart, segmentli seçim.
  static const double md = 12;

  /// Bottom sheet ve diyalog.
  static const double lg = 20;
}

/// Sabit boyutlar.
abstract final class AppSizes {
  /// En küçük dokunma alanı (48x48 dp).
  static const double minTouchTarget = 48;

  /// Ana aksiyon butonu yüksekliği (Oyunu Başlat, El Ekle, Kaydet).
  static const double primaryButtonHeight = 56;

  /// Numerik tuş takımındaki tuş yüksekliği.
  static const double keypadKeyHeight = 48;

  static const double icon = 24;
  static const double iconSmall = 16;
}

/// Animasyon süreleri. Hepsi 150-250 ms aralığında, sadece geçiş için.
abstract final class AppDurations {
  static const Duration short = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 200);
  static const Duration long = Duration(milliseconds: 250);

  /// Sistem "azaltılmış hareket" ayarı açıksa animasyonu kapatır.
  static Duration resolve(BuildContext context, Duration duration) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
}
