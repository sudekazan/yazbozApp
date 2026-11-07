import '../../domain/models/game_config.dart';
import '../../domain/rules/rules_registry.dart';
import '../../domain/validation.dart';

/// Şablonun verilen oynanışla oynanabildiği kişi sayıları.
List<int> allowedSeatCounts(GameTemplate template, PlayMode mode) => [
  for (var n = GameConfig.minSeats; n <= GameConfig.maxSeats; n++)
    if (rulesFor(template)
        .supports(GameConfig(template: template, seatCount: n, playMode: mode)))
      n,
];

/// Şablonun herhangi bir oynanışla oynanabildiği kişi sayıları, küçükten
/// büyüğe.
List<int> anySeatCounts(GameTemplate template) =>
    {for (final mode in PlayMode.values) ...allowedSeatCounts(template, mode)}
        .toList()
      ..sort();

bool supportsPairs(GameTemplate template) =>
    allowedSeatCounts(template, PlayMode.pairs).isNotEmpty;

/// Varsayılan kişi sayısı: oynanabiliyorsa 4, değilse ilk geçerli sayı.
int defaultSeatCount(GameTemplate template, PlayMode mode) {
  final allowed = allowedSeatCounts(template, mode);
  return allowed.contains(4) ? 4 : allowed.first;
}

/// [members] kişilik grup bu şablonda hangi oynanışla oynanır? Önce şu anki
/// oynanış denenir; uymuyorsa `null`.
PlayMode? fitGroup(GameTemplate template, PlayMode current, int members) {
  for (final mode in [current, ...PlayMode.values.where((m) => m != current)]) {
    if (allowedSeatCounts(template, mode).contains(members)) return mode;
  }
  return null;
}

/// Tavla'da ilk oyuncuyu zar ya da önceki eli kazanan belirler.
bool showsDealer(GameTemplate template) => template != GameTemplate.tavla;

/// "Kurallar" bölümünde düzenlenen bir sayı alanı.
class RuleFieldSpec {
  const RuleFieldSpec(this.key, {this.min = 0, this.max = Limits.maxAbsPoints});

  /// Kural setinin JSON alan adı.
  final String key;
  final int min;
  final int max;

  bool get allowsNegative => min < 0;

  bool accepts(int value) => value >= min && value <= max;
}

/// Şablonun "Kurallar" bölümündeki sayı alanları. Ana seçenekler (hedef, el
/// sayısı, mod) kurulumun üst kısmında ayrıca gösterilir.
List<RuleFieldSpec> ruleFields(GameTemplate template) => switch (template) {
  GameTemplate.free => const [],
  GameTemplate.okey => const [
    RuleFieldSpec('startingPoints', min: 1),
    RuleFieldSpec('normalFinish'),
    RuleFieldSpec('okeyFinish'),
    RuleFieldSpec('pairsFinish'),
    RuleFieldSpec('okeyPairsFinish'),
    RuleFieldSpec('indicator'),
  ],
  GameTemplate.okey101 => const [
    RuleFieldSpec('finishPoints'),
    RuleFieldSpec('notOpenedPoints'),
    RuleFieldSpec('okeyMultiplier', min: 1, max: 16),
    RuleFieldSpec('handFinishMultiplier', min: 1, max: 16),
    RuleFieldSpec('pairsFinishMultiplier', min: 1, max: 16),
    RuleFieldSpec('pairsRemainingMultiplier', min: 1, max: 16),
    RuleFieldSpec('penaltyTileToMeld'),
    RuleFieldSpec('penaltyDiscardOkey'),
    RuleFieldSpec('penaltyWrongOpen'),
  ],
  GameTemplate.tavla => const [
    RuleFieldSpec('normalPoints', min: 1),
    RuleFieldSpec('marsPoints', min: 1),
  ],
  GameTemplate.pisti => const [
    RuleFieldSpec('pisti'),
    RuleFieldSpec('jackPisti'),
    RuleFieldSpec('majority'),
    RuleFieldSpec('clubTwo'),
    RuleFieldSpec('diamondTen'),
    RuleFieldSpec('ace'),
    RuleFieldSpec('jack'),
  ],
  GameTemplate.batak => const [
    RuleFieldSpec('minBid', min: 1, max: 17),
    RuleFieldSpec('zeroTricksPoints', min: -Limits.maxAbsPoints),
  ],
};
