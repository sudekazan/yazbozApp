import 'game_config.dart';
import 'round.dart';
import 'rule_set.dart';

/// Puan motorunun değerlendirdiği oyun: kurulum, kurallar ve eller.
class Game {
  const Game({required this.config, required this.rules, required this.rounds});

  final GameConfig config;
  final RuleSet rules;

  /// Oynanma sırasına göre eller.
  final List<Round> rounds;
}
