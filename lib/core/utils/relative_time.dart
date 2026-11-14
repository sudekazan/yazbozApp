import 'package:intl/intl.dart';

import '../../l10n/generated/app_localizations.dart';

/// "Az önce", "12 dk önce", "6 sa önce", "Dün" ya da "3 Kas".
String relativeTime(AppLocalizations l10n, DateTime time, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final diff = current.difference(time);
  if (diff.inMinutes < 1) return l10n.timeJustNow;
  if (diff.inHours < 1) return l10n.timeMinutesAgo(diff.inMinutes);

  final today = DateTime(current.year, current.month, current.day);
  final day = DateTime(time.year, time.month, time.day);
  final daysAgo = today.difference(day).inDays;
  if (daysAgo == 0) return l10n.timeHoursAgo(diff.inHours);
  if (daysAgo == 1) return l10n.timeYesterday;
  return DateFormat.MMMd(l10n.localeName).format(time);
}
