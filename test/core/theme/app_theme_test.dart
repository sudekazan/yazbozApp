import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yazboz/core/theme/app_colors.dart';
import 'package:yazboz/core/theme/app_dimensions.dart';
import 'package:yazboz/core/theme/app_theme.dart';
import 'package:yazboz/core/theme/app_typography.dart';

/// WCAG 2.x kontrast oranı.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  const schemes = {'açık': AppColors.light, 'koyu': AppColors.dark};

  for (final MapEntry(key: name, value: s) in schemes.entries) {
    group('$name tema kontrastı (WCAG AA)', () {
      // Yazı çiftleri en az 4.5:1 olmalı.
      final textPairs = <String, (Color, Color)>{
        'yazı / zemin': (s.onSurface, s.surface),
        'yazı / kart': (s.onSurface, s.surfaceContainerLow),
        'yazı / ikincil yüzey': (s.onSurface, s.surfaceContainerHigh),
        'soluk yazı / zemin': (s.onSurfaceVariant, s.surface),
        'soluk yazı / kart': (s.onSurfaceVariant, s.surfaceContainerLow),
        'soluk yazı / ikincil yüzey': (
          s.onSurfaceVariant,
          s.surfaceContainerHigh,
        ),
        'buton yazısı / vurgu': (s.onPrimary, s.primary),
        'vurgu yazı / zemin': (s.primary, s.surface),
        'vurgu yazı / kart': (s.primary, s.surfaceContainerLow),
        'seçili yazı / seçili zemin': (
          s.onPrimaryContainer,
          s.primaryContainer,
        ),
        'hata / kart': (s.error, s.surfaceContainerLow),
        'bildirim yazısı': (s.onInverseSurface, s.inverseSurface),
        'bildirim aksiyonu': (s.inversePrimary, s.inverseSurface),
      };
      for (final MapEntry(key: label, value: (fg, bg)) in textPairs.entries) {
        test(label, () {
          expect(contrast(fg, bg), greaterThanOrEqualTo(4.5));
        });
      }

      // Dokunulan öğelerin kenarlığı en az 3:1 olmalı.
      test('kenarlık / zemin ve kart', () {
        expect(contrast(s.outline, s.surface), greaterThanOrEqualTo(3));
        expect(
          contrast(s.outline, s.surfaceContainerLow),
          greaterThanOrEqualTo(3),
        );
      });
    });
  }

  group('Tek vurgu rengi', () {
    for (final MapEntry(key: name, value: s) in schemes.entries) {
      test('$name temada secondary ve tertiary vurguyla aynı', () {
        expect(s.secondary, s.primary);
        expect(s.tertiary, s.primary);
        expect(s.secondaryContainer, s.primaryContainer);
      });
    }
  });

  group('Tipografi', () {
    test('en fazla iki font ağırlığı kullanılır', () {
      const t = AppTypography.textTheme;
      final styles = [
        t.displaySmall,
        t.headlineSmall,
        t.titleLarge,
        t.titleMedium,
        t.titleSmall,
        t.bodyLarge,
        t.bodyMedium,
        t.bodySmall,
        t.labelLarge,
        t.labelMedium,
        t.labelSmall,
        AppTypography.primaryButton,
      ];
      final weights = styles.map((s) => s!.fontWeight).toSet();
      expect(
        weights,
        everyElement(isIn([AppTypography.regular, AppTypography.semibold])),
      );
    });

    test('hiçbir yazı 12 pt altına inmez', () {
      const t = AppTypography.textTheme;
      for (final style in [t.bodySmall, t.labelSmall]) {
        expect(style!.fontSize, greaterThanOrEqualTo(12));
      }
    });

    test('skor stilleri eşit genişlikli rakam kullanır', () {
      final score = ScoreTextTheme.fromScheme(AppColors.light);
      for (final style in [score.total, score.cell, score.entry, score.key]) {
        expect(
          style.fontFeatures,
          contains(const FontFeature.tabularFigures()),
        );
      }
    });
  });

  group('Tema', () {
    test('açık ve koyu tema Material 3 ve skor stilleriyle kurulur', () {
      for (final theme in [AppTheme.light(), AppTheme.dark()]) {
        expect(theme.useMaterial3, isTrue);
        expect(theme.extension<ScoreTextTheme>(), isNotNull);
        expect(theme.scaffoldBackgroundColor, theme.colorScheme.surface);
      }
    });

    test('ana buton yüksekliği dokunma alanından küçük değil', () {
      expect(
        AppSizes.primaryButtonHeight,
        greaterThanOrEqualTo(AppSizes.minTouchTarget),
      );
      expect(
        AppSizes.keypadKeyHeight,
        greaterThanOrEqualTo(AppSizes.minTouchTarget),
      );
    });

    testWidgets('azaltılmış hareket açıkken animasyon süresi sıfırlanır', (
      tester,
    ) async {
      late Duration resolved;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(
            builder: (context) {
              resolved = AppDurations.resolve(context, AppDurations.medium);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(resolved, Duration.zero);
    });
  });
}
