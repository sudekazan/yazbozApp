/// Puanı tabloda gösterilecek biçime çevirir. Eksi için kısa çizgi yerine
/// eksi işareti (U+2212) kullanılır; rakamlarla aynı genişlikte durur.
String formatPoints(int value) => value < 0 ? '−${-value}' : '$value';
