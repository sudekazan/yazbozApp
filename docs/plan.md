# Yazboz — Planlama (Aşama 1)

Tarih: 2026-11-07. Bu dosya onaylanınca tasarım belgesi olarak repoya girer; sonraki aşamalar buna göre yapılır.

## 1. Verilen kararlar (2026-11-07)

- 101: Çarpanlar birbiriyle çarpılır (çiftten açıp okeyle bitiş x4, elden okeyle bitiş x4).
- 101: Çiftten açıp bitiremeyen oyuncunun kalan taşları x2 yazılır (kurallardan kapatılabilir).
- Eşli 101: Eli bitirenin eşi o elde 0 yazar.
- Batak: 3 kişide bir dağıtımda 17 el, 4 kişide 13 el.
- Eşli klasik Okey: Takım başına tek puan (takım 20 ile başlar).
- Biten oyunlar ana sayfada ayrı "Biten Oyunlar" bölümünde görünür, dokununca salt okunur tablo açılır.
- Uygulama kimliği: `com.sudekazan.yazboz`.
- Commit mesajları bu projede "…eklendi / …düzeltildi" kalıbında.
- Renk paleti "Çuha": tek vurgu rengi masa çuhası yeşili (açıkta #1D6B48, koyuda #6FCF97), nötr gri-beyaz zemin. Puan rakamları renklendirilmez. Ayrıntı 6. bölümde.

## 2. Mimari

Katmanlar tek yönlü bağımlı: `features → domain ← data`. `domain` saf Dart; Flutter'a bağlı değil, tek başına test edilir.

```
lib/
  main.dart, app.dart          # MaterialApp.router, tema, yerelleştirme
  core/
    theme/                     # spacing, radius, süre, renk, tipografi tokenları; açık/koyu tema
    router/                    # go_router tanımları
    utils/
  data/
    db/                        # drift tabloları, dönüştürücüler, migration'lar
    repositories/              # GameRepository, GroupRepository, SettingsRepository
  domain/
    models/                    # Game, Seat, SeatOccupant, Round, RuleSet, RoundInput, RoundResult, GameStatus
    rules/                     # GameRules arayüzü + 6 şablonun motoru + kayıt (registry)
    dealer.dart                # dağıtıcı hesabı
    validation.dart            # isim, puan, sayaç sınırları
  features/
    home/ game_setup/ scoreboard/ round_entry/ game_over/ settings/
  l10n/                        # app_tr.arb (sonra app_en.arb)
test/
  domain/ data/ features/
```

Veri akışı: Ekran → Riverpod notifier → repository (drift transaction) → drift stream → provider → ekran. Toplamlar, lider, kazanan ve dağıtıcı veritabanına yazılmaz; her seferinde ellerden hesaplanır. Böylece el düzenleme, silme ve geri almada tutarsızlık çıkmaz.

## 3. Domain modeli

**Puan birimi (sütun):** Her şablon kendi sütunlarını söyler.

| Şablon | Bireysel | Eşli |
|---|---|---|
| Serbest | 2–8 sütun (takım oynanıyorsa sütun adına takım adı yazılır) | — |
| Okey | 4 oyuncu | 2 takım |
| 101 | 4 oyuncu | 4 oyuncu, takım toplamı ayrıca gösterilir |
| Tavla | 2 oyuncu | — |
| Pişti | 2 oyuncu | 2 takım |
| Batak | 3 ya da 4 oyuncu | 2 takım (4 kişide) |

**Takım:** Eşler karşılıklı oturur. Oturma sırası 1-2-3-4 ise 1 ile 3, 2 ile 4 eştir. Kurulumda sıralama takımı da belirler.

**Koltuk ve oyuncu ayrı:** Puanlar koltuğa bağlı. Koltukta kimin oturduğu "şu elden itibaren şu isim" satırlarıyla tutulur. Oyuncu değiştirilince yeni isim bir sonraki elden itibaren geçerli olur; tabloda o elin üstünde "5. elden itibaren: Ayşe → Mehmet" notu çıkar. "İsmi Düzenle" yalnızca yazım düzeltir, not bırakmaz.

**Dağıtıcı (türetilmiş):** `sıradaki dağıtıcı = (ilk dağıtıcı + el sayısı + elle kaydırma) mod koltuk sayısı`. Elle değiştirince sadece "elle kaydırma" sayısı güncellenir. El silinince ya da geri alınınca el sayısı azaldığı için gösterge kendiliğinden geri döner. Tavla'da gizli (genelde zarla ya da kazanan başlar).

**RuleSet:** Her şablonun bir alt sınıfı var, JSON olarak sürüm numarasıyla saklanır. Kurallar oyun kurulumunda belirlenir, oyun sırasında sadece görüntülenir.

**RoundInput (ham girdi):** Her şablonun kendi girdi sınıfı. El bu ham girdiyle saklanır, puan her zaman yeniden hesaplanabilir.

**Motor arayüzü:**

```dart
abstract class GameRules {
  List<ScoringUnit> units(GameConfig config);          // sütunlar
  List<RoundError> validate(RoundInput input, RuleSet rules, GameConfig config);
  RoundResult calculateRound(RoundInput input, RuleSet rules);
  GameStatus evaluate(Game game);                       // devam ediyor mu, sıralama, kazanan
}
```

## 4. Şablon kuralları (varsayılanlar, hepsi kurallardan değiştirilebilir)

**Serbest**
- Ayar: "Kim kazanır: En yüksek / En düşük toplam" + "Hedef puan (opsiyonel)".
- Hedef varsa biri hedefe ulaşınca (toplam ≥ hedef) oyun biter, sıralama seçime göre yapılır. "Hedefe ulaşan kazanır" = en yüksek kazanır, "ulaşan kaybeder" = en düşük kazanır; iki ayrı ayar yerine bu tek seçim yeterli.
- Hedef yoksa oyun "Oyunu Bitir" ile biter.

**Okey (klasik)**
- Herkes (eşlide her takım) 20 ile başlar.
- Giriş: bitiren seçilir, bitiş türü seçilir (varsayılan Normal seçili gelir): Normal −2, Okey atarak −4, Çifte −4, Okey atarak çifte −8. Bitiren hariç herkes (eşlide rakip takım) düşer.
- Gösterge: gösteren oyuncu(lar) işaretlenir, diğerleri (eşlide rakip takım) −1. İki kopya olduğu için birden fazla oyuncu işaretlenebilir.
- "Kimse bitiremedi" seçeneği var (taşlar bitti); o elde sadece gösterge puanı işler.
- Bir el sonunda birinin puanı 0 ya da altına inerse oyun biter; en yüksek puan kalan kazanır.

**101 Okey**
- 9 el; sonunda en düşük toplam kazanır (eşlide en düşük takım toplamı).
- Giriş: bitiren seçilir; bitiş biçimi işaretlenir: Okeyle (x2), Elden (x2), Çiftten (x2). İşaretli çarpanlar çarpılır.
- Bitiren −101 × çarpan. Hiç açamayan +202 × çarpan. Açıp bitiremeyen: kalan taş toplamı × çarpan (çiftten açtıysa ayrıca x2). Eşlide bitirenin eşi 0.
- "Kimse bitiremedi" seçeneği: çarpan 1, herkes kalanını ya da +202 yazar.
- Cezalar elden ayrı, oyuncuya eklenir, çarpandan etkilenmez: İşler taş atma +101, Okey atma +101, Yanlış açma +101, Diğer (tutar girilir).

**Tavla**
- 2 oyuncu, hedef 5 (3, 5, 7, 11 ya da özel).
- Giriş: kazanan + Normal (1) / Mars (2). Katlama küpü ayarı açıksa küp değeri (1, 2, 4 … 64) seçilir, puan × küp.
- Hedefe ilk ulaşan kazanır.

**Pişti**
- Hedef 151 (101, 151, 201 ya da özel).
- Sayaç modu, her oyuncu/takım için: Pişti × 10, Vale piştisi × 20, As × 1, Vale × 1. Tek sahipli olanlar seçimle girilir: Kart çoğunluğu (+3, "Eşit" seçeneği var, eşitse kimse almaz), Sinek 2 (+2), Karo 10 (+3).
- As ve Vale toplamı 4'ü geçemez; birinin sayısı girilince diğeri 4'ten kalanla dolar (değiştirilebilir).
- "Doğrudan puan gir" modu: her sütuna sadece sayı.
- Bir el sonunda biri hedefe ulaşırsa en yüksek toplam kazanır.

**Batak**
- Mod: Düz / İhaleli. Süre: 11 el ya da hedef puan.
- Bir dağıtımda 13 el (3 kişide 17). Girilen el sayılarının toplamı buna eşit olmalı; son oyuncunun sayısı kalanla dolar (değiştirilebilir).
- Düz: herkes aldığı el kadar +.
- İhaleli: ihaleyi alan oyuncu + ihale miktarı (en az 5, en çok 13 ya da 17) + koz (opsiyonel, bilgi amaçlı). Tutturan aldığı el kadar +, tutturamayan ihale kadar −, diğerleri aldığı el kadar +. Eşlide ihaleyi alanın takımının toplam eli sayılır.
- Hiç el alamayan için puan: varsayılan 0 (ör. −5 yapılabilir). İki modda da geçerli.

**Beraberlik (tüm şablonlar):** Hedefle biten oyunlarda (Serbest-en yüksek, Tavla, Pişti, hedefli Batak) en yüksek iki toplam eşitse oyun sürer. El sayısıyla ya da 0'a inmeyle biten oyunlarda (101, 11 elli Batak, Okey, Serbest-en düşük) eşit olanlar ortak kazanır.

## 5. Veritabanı şeması (drift, şema sürümü 1)

| Tablo | Sütunlar |
|---|---|
| `games` | id, template, team_mode, rules_json, status (active/finished), first_dealer_seat, dealer_offset, dealer_indicator, created_at, updated_at, finished_at?, deleted_at? |
| `seats` | id, game_id → games (cascade), seat_index; tekil (game_id, seat_index) |
| `seat_occupants` | id, seat_id → seats (cascade), player_name (1–20), from_round (1 = baştan) |
| `rounds` | id, game_id → games (cascade), sequence, input_json, result_json (hesaplanmış puan önbelleği), created_at, updated_at; indeks (game_id, sequence) |
| `undo_actions` | id, game_id → games (cascade), kind, payload_json, created_at |
| `player_groups` | id, name (1–30), member_names_json (sıralı liste), created_at, updated_at |
| `app_settings` | tek satır: theme_mode, keep_screen_on, haptics, dealer_indicator_default |

- **Otomatik kayıt:** Her el kaydı, düzenleme, silme tek bir transaction'da yazılır; aynı transaction'a geri alma kaydı da girer.
- **Geri alma:** `undo_actions` oyun başına son 50 işlemi tutar (el ekleme, düzenleme, silme, oyuncu değiştirme, isim düzenleme, dağıtıcı değiştirme). Uygulama kapanıp açılsa da geri alınabilir.
- **Ana sayfada kaydırıp silme:** Önce `deleted_at` işaretlenir, snackbar'daki "Geri Al" bunu temizler. Snackbar kapanınca ya da bir sonraki açılışta kalıcı silinir.
- **İsim önerileri:** `seat_occupants` ve `player_groups` içindeki farklı isimler, son kullanıma göre sıralı. Ayrı oyuncu tablosu yok.
- **Migration:** drift'in şema dökümü (`drift_schemas/`) repoya girer, her sürüm geçişi için otomatik test yazılır.
- Sorgular sadece drift'in tip güvenli API'siyle; JSON sütunları tip dönüştürücüyle okunur. Bozuk JSON okunursa o oyun "açılamadı" olarak işaretlenir, uygulama çökmez.

## 6. Ekran akışı ve davranış

- **Oyun sonu:** Motor "bitti" deyince sonuç ekranı açılır. Geri tuşu tabloya döner; son el yanlışsa düzeltilebilir. "Ana Sayfa" ya da "Rövanş Yap" basılınca oyun kesin biter.
- **Rövanş:** Aynı şablon, kurallar, oturma sırası ve isimler (son oturanlar). İlk dağıtıcı, önceki oyunda sıradaki dağıtıcı olur.
- **Yeniden başlat:** Oyuncular kalır, eller silinir. Onay diyaloğu ne silineceğini yazar ("Bu oyundaki 7 el silinsin mi?").
- **Dağıtıcı göstergesi:** Ayarlar'daki anahtar yeni oyunların varsayılanı; oyun menüsünden o oyun için açılıp kapatılır.
- **Paylaş:** Tablonun tamamı (ekranda görünmeyen eller dahil) PNG'ye çizilir, geçici dizine yazılır, paylaşım bitince silinir.
- **Yazı tipi:** Sistem fontu (iOS'ta SF Pro, Android'de Roboto), 2 ağırlık; skorlarda eşit genişlikli rakam (tabular figures).
- **Renk paleti "Çuha"** (UI UX Pro Max'in "kart ve masa oyunu" önerisinden; tüm yazı çiftleri WCAG AA'yı geçer):

  | Rol | Açık | Koyu | Payı | Flutter karşılığı |
  |---|---|---|---|---|
  | Zemin | #F5F6F4 | #101311 | %60 | `surface` |
  | Kart, sayfa yüzeyi | #FFFFFF | #191D1A | %30 | `surfaceContainerLow` |
  | İkincil yüzey (tuş, etiket) | #EAEDEA | #232824 | %30 | `surfaceContainerHigh` |
  | Ayırıcı çizgi | #DCE0DC | #2C322E | — | `outlineVariant` |
  | Kenarlık (dokunulan öğe) | #7A847E | #6E7871 | — | `outline` |
  | Yazı | #17201B | #E6EAE7 | — | `onSurface` |
  | Soluk yazı | #57615B | #9BA49E | — | `onSurfaceVariant` |
  | Vurgu (ana butonlar) | #1D6B48 | #6FCF97 | %10 | `primary` |
  | Vurgu üstü yazı | #FFFFFF | #062A17 | — | `onPrimary` |
  | Seçili durum zemini | #D6EDDF | #1D3829 | — | `primaryContainer` |
  | Seçili durum yazısı | #0E3B26 | #C2EBD3 | — | `onPrimaryContainer` |
  | Hata | #B3261E | #F2B8B5 | — | `error` |

  - Vurgu rengi sadece ana aksiyonlarda (Kaydet, El Ekle, Oyunu Başlat) ve seçili durumlarda kullanılır.
  - Puan rakamları hep yazı renginde. İyi puanın yönü oyuna göre değiştiği için (101'de düşük, Okey'de yüksek iyi) pozitif/negatif renklendirme yapılmaz.
  - Lider renkle değil, ince çerçeve ve taç ikonuyla gösterilir. Dağıtıcı isminin yanında kart ikonu.
  - Hata her zaman ikon ve metinle gelir, sadece renge dayanmaz.
  - Gölge yok; ayrım çizgilerle yapılır. Bottom sheet arkasında yarı saydam koyu perde (%45).
- **Ölçüler:** Boşluklar 4/8'in katları; köşe yuvarlaklığı 8 (tuş, etiket, alan), 12 (buton, kart), 20 (bottom sheet); dokunma alanı en az 48.
- **Ekran maketleri:** [Yazboz Ekranları](https://claude.ai/artifact/CFfDqohxGs1xgL52Mb2Yt8) (özel; ana akış ve el girişi ekranları).

## 7. Paketler

| Paket | Neden | Yayıncı |
|---|---|---|
| flutter_riverpod, riverpod_annotation | Talimattaki durum yönetimi | dash-overflow.net |
| riverpod_generator, build_runner (dev) | Riverpod ve drift kod üretimi | dash-overflow.net, tools.dart.dev |
| drift, drift_flutter, drift_dev (dev) | Yerel SQLite; drift_flutter iOS/Android'de veritabanını açar | simonbinder.eu |
| go_router | Navigasyon | flutter.dev |
| wakelock_plus | Oyun ekranında ekranı açık tutma | fluttercommunity.dev |
| share_plus | Tabloyu paylaşma | fluttercommunity.dev |
| path_provider | Paylaşılacak görseli geçici dizine yazmak | flutter.dev |
| flutter_localizations (SDK), intl | ARB çevirileri, tarih biçimi | flutter.dev, dart.dev |
| characters | İsim uzunluğunu emoji dahil doğru saymak (Flutter'ın zaten içinde olan paket) | dart.dev |
| flutter_lints (dev) + birkaç ek kural | Taşbaz'daki gibi; very_good_analysis'in zorunlu belge yorumu kuralı tek kişilik projede gürültü yapar | flutter.dev |

Eklemeyeceklerim: google_fonts (sistem fontu yeterli, çevrimdışı), shared_preferences (ayarlar drift'te), freezed/json_serializable (modeller elle yazılır, kod üretimi az kalır), ekran görüntüsü paketi (Flutter'ın RepaintBoundary'si yeterli), titreşim paketi (HapticFeedback yerleşik).

Üretilen `*.g.dart` dosyaları repoya girmez; CI'da `build_runner` ile üretilir.

## 8. Repo, CI ve güvenlik

- Repo klonlandı: `sudekazan/yazbozApp`, `main` dalı, henüz commit yok.
- İlk commit: `.gitignore` (talimattaki tüm kalıplar + `*.g.dart`) ve `android/key.properties.example`.
- Talimatın kendisi kök dizine `CLAUDE.md` olarak girer, sonuna "Son kararlar" bölümü eklenir (1. bölümdeki kararlar).
- Platformlar: sadece iOS ve Android. iOS deployment target 15.0 (Taşbaz gibi).
- CI (`.github/workflows/ci.yml`, her push ve PR): format kontrolü, analyze, test, gitleaks, osv-scanner ve release APK'da `INTERNET` izni kontrolü. Action'lar commit SHA'sıyla sabitlenir, `permissions: contents: read`.
- Dependabot: pub + github-actions, haftalık.
- Release komutu (`--obfuscate --split-debug-info`) README'ye yazılır.
- Her commit öncesi: `dart format .`, `flutter analyze`, `flutter test`, `git status`, `git diff --staged`.
- Her aşamanın sonunda talimat gereği `git push` yapılır ve kısa özet verilir.

## 9. Aşama 2'de yapılacaklar

1. `.gitignore` + `key.properties.example` (ilk commit)
2. `flutter create --org com.sudekazan --project-name yazboz --platforms ios,android`, Android release imza ayarı, izin temizliği
3. `CLAUDE.md` + README
4. Tema tokenları (açık/koyu)
5. Router iskeleti
6. Yerelleştirme altyapısı (ARB)
7. CI + Dependabot

Her madde ayrı commit.
