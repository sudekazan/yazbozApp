import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:yazboz/core/utils/relative_time.dart';
import 'package:yazboz/l10n/generated/app_localizations_tr.dart';

void main() {
  final l10n = AppLocalizationsTr();
  final now = DateTime(2026, 11, 7, 15, 30);
  String at(DateTime time) => relativeTime(l10n, time, now: now);

  setUpAll(() => initializeDateFormatting('tr'));

  test('bir dakikadan yeni "Az önce"', () {
    expect(at(now.subtract(const Duration(seconds: 30))), 'Az önce');
  });

  test('bir saatten yeni dakika olarak', () {
    expect(at(now.subtract(const Duration(minutes: 12))), '12 dk önce');
  });

  test('aynı gün saat olarak', () {
    expect(at(DateTime(2026, 11, 7, 9)), '6 sa önce');
  });

  test('bir önceki gün "Dün"', () {
    expect(at(DateTime(2026, 11, 6, 23, 50)), 'Dün');
  });

  test('daha eskisi gün ve ay', () {
    expect(at(DateTime(2026, 11, 3, 20)), '3 Kas');
  });
}
