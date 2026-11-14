import 'package:flutter/material.dart';

import '../../core/theme/app_dimensions.dart';
import '../../data/repositories/game_models.dart';
import '../../domain/models/game_config.dart';
import 'batak_entry.dart';
import 'free_entry.dart';
import 'okey101_entry.dart';
import 'okey_entry.dart';
import 'pisti_entry.dart';
import 'tavla_entry.dart';

/// El girişi sayfasını açar. [editing] verilirse o el düzenlenir.
/// El kaydedilirse `true` döner.
Future<bool> showRoundEntrySheet(
  BuildContext context, {
  required GameSnapshot game,
  StoredRound? editing,
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => FractionallySizedBox(
      heightFactor: AppSizes.entrySheetHeightFactor,
      child: switch (game.config.template) {
        GameTemplate.free => FreeEntry(game: game, editing: editing),
        GameTemplate.okey => OkeyEntry(game: game, editing: editing),
        GameTemplate.okey101 => Okey101Entry(game: game, editing: editing),
        GameTemplate.tavla => TavlaEntry(game: game, editing: editing),
        GameTemplate.pisti => PistiEntry(game: game, editing: editing),
        GameTemplate.batak => BatakEntry(game: game, editing: editing),
      },
    ),
  );
  return saved ?? false;
}
