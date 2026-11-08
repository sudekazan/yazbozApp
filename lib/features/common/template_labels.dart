import 'package:flutter/material.dart';

import '../../domain/models/game_config.dart';
import '../../l10n/generated/app_localizations.dart';

extension GameTemplateLabels on GameTemplate {
  String title(AppLocalizations l10n) => switch (this) {
    GameTemplate.free => l10n.templateFree,
    GameTemplate.okey => l10n.templateOkey,
    GameTemplate.okey101 => l10n.templateOkey101,
    GameTemplate.tavla => l10n.templateTavla,
    GameTemplate.pisti => l10n.templatePisti,
    GameTemplate.batak => l10n.templateBatak,
  };

  String description(AppLocalizations l10n) => switch (this) {
    GameTemplate.free => l10n.templateFreeDescription,
    GameTemplate.okey => l10n.templateOkeyDescription,
    GameTemplate.okey101 => l10n.templateOkey101Description,
    GameTemplate.tavla => l10n.templateTavlaDescription,
    GameTemplate.pisti => l10n.templatePistiDescription,
    GameTemplate.batak => l10n.templateBatakDescription,
  };

  IconData get icon => switch (this) {
    GameTemplate.free => Icons.edit_note,
    GameTemplate.okey => Icons.crop_portrait,
    GameTemplate.okey101 => Icons.view_week_outlined,
    GameTemplate.tavla => Icons.casino_outlined,
    GameTemplate.pisti => Icons.style_outlined,
    GameTemplate.batak => Icons.layers_outlined,
  };
}

/// "101 Okey" ya da eşliyse "Pişti · Eşli".
String gameTitle(AppLocalizations l10n, GameTemplate template, PlayMode mode) =>
    mode == PlayMode.pairs
    ? l10n.templatePairsTitle(template.title(l10n))
    : template.title(l10n);

/// "Ayşe, Mehmet, Can" ya da eşliyse "Ayşe & Zeynep – Mehmet & Can".
String playersLine(AppLocalizations l10n, List<String> names, PlayMode mode) {
  if (mode == PlayMode.pairs && names.length == 4) {
    return l10n.teamsVersus(
      l10n.teamNames(names[0], names[2]),
      l10n.teamNames(names[1], names[3]),
    );
  }
  return names.join(', ');
}

/// Sütun adı: tek oyuncu ya da takımsa "Ayşe & Zeynep".
String columnName(AppLocalizations l10n, List<String> names) =>
    names.length == 2 ? l10n.teamNames(names[0], names[1]) : names.join(', ');
