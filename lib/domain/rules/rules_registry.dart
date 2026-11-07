import '../models/game_config.dart';
import '../models/round.dart';
import '../models/rule_set.dart';
import 'batak_rules.dart';
import 'free_rules.dart';
import 'game_rules.dart';
import 'okey101_rules.dart';
import 'okey_rules.dart';
import 'pisti_rules.dart';
import 'tavla_rules.dart';

/// Şablonun puan motoru.
GameRules rulesFor(GameTemplate template) => switch (template) {
  GameTemplate.free => const FreeGameRules(),
  GameTemplate.okey => const OkeyGameRules(),
  GameTemplate.okey101 => const Okey101GameRules(),
  GameTemplate.tavla => const TavlaGameRules(),
  GameTemplate.pisti => const PistiGameRules(),
  GameTemplate.batak => const BatakGameRules(),
};

/// Kayıtlı kural setini `template` alanına göre çözer. Şablon adı yoksa
/// ya da bilinmiyorsa [FormatException]; diğer eksik alanlar varsayılana
/// düşer.
RuleSet decodeRuleSet(Map<String, Object?> json) {
  final name = json['template'];
  final template = name is String ? GameTemplate.fromName(name) : null;
  if (template == null) {
    throw FormatException('Bilinmeyen oyun şablonu', name);
  }
  return rulesFor(template).ruleSetFromJson(json);
}

/// Kayıtlı el girdisini şablonun motoruyla çözer; bozuksa
/// [FormatException].
RoundInput decodeRoundInput(GameTemplate template, Map<String, Object?> json) =>
    rulesFor(template).roundInputFromJson(json);
