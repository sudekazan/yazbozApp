# Yazboz — Flutter Uygulaması (Proje Talimatı)

Uygulamanın adı (şimdilik): Yazboz. Ayrıntılı plan, veri modeli ve şema: `docs/plan.md`.

## 1. Proje özeti

Masa oyunları ve kart oyunları için dijital yazboz (skor tutma) uygulaması geliştiriyoruz. Kullanıcı oyun oynarken yanında kâğıt kalem yoksa uygulamayı açar, oyunu seçer, oyuncuları girer ve el el puan yazar. Toplamları ve oyun kurallarına göre hesaplamaları uygulama yapar.

Temel ilke: sadelik ve hız. Masada oyun oynarken puan girişi 2-3 dokunuşu geçmemeli. Gereksiz ekran, menü, animasyon, üyelik ya da reklam olmayacak.

- Platform: Flutter (iOS + Android)
- Dil: Arayüz Türkçe (ARB ile yerelleştirilebilir yapı kur, ileride İngilizce eklenecek)
- İnternet gerekmez, tüm veriler cihazda tutulur. Hesap/üyelik yok.

## 2. Oyun şablonları

1. Serbest – herhangi bir oyun için genel skor tablosu
2. Okey
3. 101 Okey
4. Tavla
5. Pişti
6. Batak (İhaleli Batak dahil)

Önemli: Bu oyunların kuralları bölgeden bölgeye, masadan masaya değişiyor. Aşağıdaki değerleri varsayılan olarak kullan, ama her şablonun puan değerleri oyun kurulumundaki "Kurallar" bölümünden düzenlenebilir olsun. Kural değerlerini koda gömme, her şablon için bir `RuleSet` modelinde tut.

### 2.1 Serbest

- 2-8 oyuncu veya takım
- Her elde her oyuncu için puan girilir (negatif de olabilir)
- Ayarlar: hedef puan (opsiyonel), hedefe ulaşan kazanır mı kaybeder mi, en yüksek mi en düşük toplam mı kazanır
- Hedef yoksa oyun manuel bitirilir

### 2.2 Okey (klasik, puan düşmeli)

- 4 oyuncu (bireysel) veya 2'ye 2 eşli
- Varsayılan: her oyuncu 20 puan ile başlar, puanı 0'a (veya altına) inen oyunu bitirir; bitiren hariç diğerleri puan kaybeder
- Bitiren oyuncu seçilir, bitiş türü seçilir:
  - Normal bitiş: diğerlerinden -2
  - Okey atarak bitiş: -4
  - Çifte bitiş: -4
  - Okey atarak çifte bitiş: -8
- Gösterge gösteren oyuncu: diğerlerinden -1 (el içinde ayrı işaretlenebilir)
- Puan girişi tek tek sayı yazmak yerine "Kim bitirdi + nasıl bitti" seçimiyle yapılmalı; hesaplamayı uygulama yapar

### 2.3 101 Okey

- 4 oyuncu bireysel veya 2'ye 2 eşli
- Düşük puan iyidir; varsayılan oyun süresi 9 el (ayarlanabilir), sonunda en düşük toplam kazanır
- Her elde:
  - Eli bitiren: -101
  - Açmış ama bitirememiş oyuncu: elinde kalan taşların toplamı (kullanıcı sayıyı girer)
  - Hiç açamayan: +202
  - Okeyle bitiş veya elden bitiş (hiç açmadan tek seferde): tüm puanlar x2 (bitiren -202, açamayan +404, diğerleri kalan x2)
  - Çift açıp bitiş: x2 (ayarlanabilir)
- Cezalar (el içinde ayrı eklenir, her biri +101): işler taş atma, okey atma (açılmış perde varken), yanlış açma vb. Ceza türleri listeden seçilsin, serbest ceza tutarı da girilebilsin
- Eşli oyunda eş puanları toplanarak takım toplamı gösterilir

### 2.4 Tavla

- 2 oyuncu
- Hedef: 5 sayı (seçenekler: 3, 5, 7, 11 veya özel)
- Her oyunda kazanan seçilir ve tür seçilir:
  - Normal galibiyet: 1 sayı
  - Mars: 2 sayı
  - (Opsiyonel ayar) Katlama küpü kullanılıyorsa çarpan 2/4/8/16/32/64 seçilebilir, varsayılan kapalı
- Hedefe ilk ulaşan kazanır

### 2.5 Pişti

- 2 oyuncu veya 2'ye 2 eşli
- Hedef: 151 (seçenekler: 101, 151, 201 veya özel)
- Her elde her oyuncu/takım için şu sayaçlar girilir, puanı uygulama hesaplar:
  - Pişti sayısı × 10
  - Vale (Joker) ile pişti × 20
  - Kart çoğunluğu (en çok kart alan) +3
  - Sinek 2: +2
  - Karo 10: +3
  - Her As: +1, her Vale: +1
- Kullanıcı isterse "doğrudan puan gir" moduna geçebilsin (sayaçla uğraşmak istemeyenler için)
- Hızlı giriş: sayaçlar büyük +/- butonlarıyla

### 2.6 Batak / İhaleli Batak

- 3-4 oyuncu, 4 kişide eşli seçenek
- Varsayılan oyun: 11 el veya hedef puan (ayarlanabilir)
- Mod seçimi: Düz Batak / İhaleli Batak
- İhaleli Batak'ta her elde:
  - İhaleyi alan oyuncu ve ihale miktarı (örn. 5-13) girilir
  - Koz (sinek/karo/kupa/maça) seçimi opsiyonel olarak kaydedilir (bilgi amaçlı)
  - El sonunda her oyuncunun aldığı el sayısı girilir (toplam 13 olmalı, değilse uyarı ver)
  - İhaleyi tutturan: aldığı el kadar +
  - İhaleyi tutturamayan (battı): ihale miktarı kadar -
  - Diğer oyuncular: aldıkları el kadar +; hiç el alamayan oyuncu için "batma" kuralı ayarlanabilir (varsayılan: 0)
- Düz Batak'ta her oyuncu el sayısını girer, aldığı el kadar puan

## 3. Ekranlar

1. Ana Sayfa
   - Büyük "Yeni Oyun" butonu
   - Altında "Devam Eden Oyunlar" listesi (oyun türü, oyuncular, son güncelleme). Kaydırarak silme + geri al (snackbar)
   - Sağ üstte ayarlar ikonu
2. Oyun Seçimi
   - 6 şablon, büyük kartlar (ikon + isim + bir satırlık açıklama). 2 sütunlu grid
3. Oyun Kurulumu
   - Oyuncu sayısı (stepper) / bireysel–eşli seçimi (şablon destekliyorsa)
   - Kayıtlı gruplar: En üstte kayıtlı grupların yatay listesi ("Ailem", "İş arkadaşları" gibi). Gruba dokununca oyuncu sayısı ve isimler tek seferde dolsun
   - Oyuncu isimleri: varsayılan "Oyuncu 1, 2..." dolu gelsin, değiştirmek opsiyonel olsun. Daha önce kullanılan isimler öneri olarak çıksın
   - Oyuncular oturma sırasına göre sürükle-bırak ile sıralanabilsin (dağıtıcı sırası buna göre döner)
   - İsimler girildikten sonra küçük bir "Grup olarak kaydet" seçeneği çıksın
   - İlk dağıtıcı seçimi: varsayılan ilk oyuncu, dokunarak değiştirilebilir (Tavla'da bu alan "İlk başlayan" olarak gösterilsin ya da gizlensin)
   - Hedef puan / el sayısı
   - "Kurallar" bölümü kapalı (expandable) gelsin; varsayılan değerler hazır olsun, isteyen düzenlesin
   - Alt kısımda sabit "Oyunu Başlat" butonu
4. Skor Tablosu (ana oyun ekranı)
   - Sütunlar: oyuncular/takımlar. Satırlar: eller
   - Toplam satırı üstte sabit dursun (sticky), büyük ve kalın yazılsın
   - Lider oyuncu hafifçe vurgulansın (renk değil, ince bir kenarlık veya küçük ikon)
   - Hedefe kalan puan küçük yazıyla gösterilebilir
   - Dağıtıcı göstergesi: Sıradaki eli dağıtacak oyuncunun sütun başlığında küçük, net bir işaret (ör. kart ikonu) olsun. Her el kaydedildiğinde oturma sırasına göre otomatik bir sonraki oyuncuya geçsin. El silinir veya geri alınırsa gösterge de geri dönsün. İşarete dokunarak dağıtıcı elle değiştirilebilsin. Ayarlardan oyun bazında kapatılabilsin
   - Oyuncu değiştirme: Oyuncu ismine uzun basınca "Oyuncuyu Değiştir" ve "İsmi Düzenle" seçenekleri çıksın. Değiştirmede yeni oyuncu aynı koltuğa (sütuna) geçer, o sütunun puanları devam eder. Değişiklik tabloda ilgili elin yanında küçük bir notla görünsün ("5. elden itibaren: Ayşe → Mehmet"), oyun sonu ekranında da belirtilsin
   - Satıra dokununca o el düzenlenebilir, uzun basınca sil
   - Altta sabit büyük "El Ekle" butonu
   - App bar'da: geri al (undo), menü (oyunu bitir, kuralları gör, yeniden başlat)
   - Çok oyunculu tablolarda yatay kaydırma olmamalı; 6+ oyuncuda isimler kısaltılsın
5. El Girişi (bottom sheet)
   - Şablona göre farklı giriş arayüzü (Okey: bitiren + bitiş türü; Pişti: sayaçlar; Batak: ihale + el sayıları; Serbest/101: sayı girişi)
   - Sayı girişinde özel büyük numerik tuş takımı + "−" tuşu (sistem klavyesi yerine)
   - Oyuncular arasında otomatik sonraki alana geçiş
   - "Kaydet" butonu, hesaplanan puanlar kaydetmeden önce önizlenir
6. Oyun Sonu
   - Kazanan büyük şekilde, final sıralaması
   - Butonlar: "Rövanş" (aynı oyuncu ve ayarlarla yeni oyun), "Tabloyu Paylaş" (skor tablosunu görsel olarak paylaş), "Ana Sayfa"
7. Ayarlar
   - Tema: Sistem / Açık / Koyu
   - Ekranı açık tut (varsayılan açık)
   - Titreşim geri bildirimi (varsayılan açık)
   - Dağıtıcı göstergesi (varsayılan açık)
   - Kayıtlı Gruplar: grupları listeleme, düzenleme (isim ekle/çıkar, sırala), silme
   - Hakkında

## 4. UI/UX kuralları (zorunlu)

- Material 3, sade ve tek bir vurgu rengi. 60-30-10 renk dağılımı: nötr zemin, ikincil yüzeyler, tek vurgu rengi sadece ana aksiyonlarda
- Glassmorphism, gradient butonlar, gereksiz gölgeler, dekoratif illüstrasyonlar yok
- 4/8pt boşluk sistemi. Spacing, renk, tipografi değerleri tek bir `theme/` klasöründe token olarak tanımlansın; widget'larda sabit sayı/renk kullanılmasın
- Tipografi: en fazla 2 font ağırlığı (regular + semibold/bold). Skor rakamları tabular figures (eşit genişlikli rakamlar) ile gösterilsin ki sütunlar kaymasın
- Skor rakamları büyük olsun; telefon masanın ortasında dururken okunabilmeli
- Dokunma alanları en az 48x48 dp
- Açık ve koyu tema ikisi de kusursuz çalışmalı, kontrast WCAG AA
- Tüm butonlar fiille başlasın: "Oyunu Başlat", "El Ekle", "Kaydet", "Rövanş Yap". "Tamam", "Gönder" gibi belirsiz etiketler kullanma
- Silme gibi geri alınamaz işlemlerde onay diyaloğu ne silineceğini açıkça söylesin ("'Pazar 101' oyunu silinsin mi?"). Mümkünse onay yerine snackbar ile "Geri Al" tercih et
- Boş durumlar: ana sayfada hiç oyun yoksa kısa bir metin + "Yeni Oyun" butonu, çizgi film illüstrasyonu yok
- Hata mesajları kullanıcıyı suçlamasın ve çözüm söylesin ("Toplam el sayısı 13 olmalı, şu an 12")
- Animasyonlar kısa (150-250ms), sadece geçiş amaçlı. Sistem "azaltılmış hareket" ayarına uyulsun
- Ekran okuyucu desteği: tüm ikon butonlarda `Semantics`/tooltip olsun
- Küçük ekranlarda (iPhone SE boyutu) hiçbir şey taşmamalı, büyük font ayarında da düzen bozulmamalı

## 5. Teknik gereksinimler

- State management: Riverpod (riverpod_generator ile)
- Yerel veritabanı: drift (SQLite). Her el kaydedildiği anda veritabanına yazılsın; uygulama kapansa da oyun kaybolmasın
- Navigasyon: go_router
- Ekranı açık tutma: wakelock_plus (sadece oyun ekranındayken aktif)
- Paylaşma: share_plus + skor tablosunun görüntüsü
- Yerelleştirme: flutter_localizations + ARB dosyaları, tüm metinler ARB'den gelsin
- Lint: `flutter_lints` veya `very_good_analysis`, uyarısız derlenmeli

### Mimari

```
lib/
  core/          # tema tokenları, sabitler, yardımcılar
  data/          # drift veritabanı, repository'ler
  domain/
    models/      # Game, Player, Round, RuleSet...
    rules/       # her şablon için puan motoru
  features/
    home/
    game_setup/
    scoreboard/
    round_entry/
    game_over/
    settings/
  l10n/
```

- Puan hesaplama motoru UI'dan tamamen bağımsız, saf Dart olsun. Ortak bir arayüz tanımla, her şablon bunu uygulasın:

  ```dart
  abstract class GameRules {
    RoundResult calculateRound(RoundInput input, RuleSet rules);
    GameStatus evaluate(Game game); // devam ediyor mu, kazanan kim
  }
  ```

- Her el ham girdiyle birlikte saklansın (örn. Pişti'de sayaçlar, Batak'ta ihale), sadece hesaplanmış puan değil. Böylece el düzenlenince puan yeniden hesaplanabilir
- Undo: son işlem geri alınabilsin (el ekleme, el silme, el düzenleme, oyuncu değiştirme)
- Oyuncu ile koltuk (seat) ayrı modellensin: puanlar koltuğa bağlı, koltukta hangi oyuncunun hangi elden itibaren oturduğu ayrı tabloda tutulsun
- Dağıtıcı sırası kayıtlı değil, türetilmiş olsun: ilk dağıtıcı + el sayısı + oturma sırasından hesaplansın (elle değiştirme varsa bir offset olarak saklansın). Böylece undo ve el silmede kendiliğinden doğru kalır
- Kayıtlı gruplar için ayrı tablo (grup adı + sıralı oyuncu isimleri)

### Testler

- Her şablonun puan motoru için unit test zorunlu. Yukarıdaki kuralların her biri için en az bir test (örn. 101'de okeyle bitişte x2, Batak'ta ihaleyi tutturamama, Pişti'de vale piştisi, Tavla'da mars)
- Oyun bitiş koşulları için testler
- Dağıtıcı rotasyonu (el ekleme, silme, undo, elle değiştirme sonrası) ve oyuncu değiştirmede puanların korunması için testler
- Kritik ekranlar için birkaç widget testi

## 6. Çalışma şekli

Şu sırayla, aşama aşama ilerle. Her değişiklikte Bölüm 7'deki commit kurallarına, her aşamanın sonunda Bölüm 8'deki güvenlik kontrollerine ve Bölüm 4'teki UI/UX kurallarına uy:

1. Planlama: Kodlamaya başlamadan önce mimariyi, veri modelini ve veritabanı şemasını özetle. Kurallar konusunda belirsizlik gördüğün yerleri sor
2. Temel: Proje kurulumu, `.gitignore`, tema tokenları (açık/koyu), router, yerelleştirme altyapısı, GitHub Actions CI (Bölüm 8)
3. Domain: Modeller + tüm şablonların puan motorları + unit testler
4. Veri katmanı: drift şeması, repository'ler, otomatik kayıt
5. Ekranlar: Ana sayfa → Oyun seçimi → Kurulum → Skor tablosu → El girişi → Oyun sonu → Ayarlar. Önce Serbest şablonla tüm akışı uçtan uca çalışır hale getir, sonra diğer şablonların el giriş arayüzlerini ekle. Her ekran bittiğinde, commit etmeden önce o ekranı Bölüm 4'teki UI/UX kurallarına göre madde madde kontrol et; uymayan yer varsa düzelt, sonra commit et
6. Cilalama: Undo, paylaşma, wakelock, haptic, erişilebilirlik, küçük ekran ve büyük font kontrolleri
7. Son kontrol: Tüm uygulamada UI/UX denetimi (Bölüm 4) ve tam güvenlik denetimi (Bölüm 8) yap. Bulguları bir liste halinde raporla, düzelt, `SECURITY_REVIEW.md` dosyasına neyin kontrol edildiğini ve sonucunu yaz

Kapsam dışı (şimdilik yapma): bulut senkronizasyonu, hesap sistemi, reklam, istatistik ekranı, çoklu cihaz.

## 7. Git ve commit kuralları

- Repo: https://github.com/sudekazan/yazbozApp (public). Repoda var olan dosyaları silme veya üzerine yazma, önce sor
- Her anlamlı değişiklikten sonra commit at. Bir commit = tek bir mantıksal değişiklik (örn. "tema tokenları eklendi", "101 puan motoru + testleri"). Birden fazla özelliği tek commit'te birleştirme
- Commit atmadan önce her seferinde:
  1. `dart format .`
  2. `flutter analyze` → uyarı/hata sıfır olmalı
  3. `flutter test` → tüm testler geçmeli

  Bunlardan biri başarısızsa commit atma, önce düzelt
- Commit mesajları sade Türkçe cümleler olsun, başlarına tür veya kapsam ön eki eklenmez. Örnekler:
  - `Skor tablosuna dağıtıcı göstergesi eklendi`
  - `101'de okeyle bitişteki çarpan hatası düzeltildi`
  - `Pişti puan hesaplama testleri yazıldı`
  - `Bağımlılıklar güncellendi`
- Bu kural projedeki tüm Markdown dosyaları için de geçerli: README, CONTRIBUTING, SECURITY_REVIEW gibi hiçbir `.md` dosyasında ön ekli commit formatı önerilmez veya örnek olarak kullanılmaz
- Her aşamanın (Bölüm 6) sonunda `git push` yap ve o aşamada neler yapıldığını kısaca özetle
- Commit'e eklemeden önce `git status` ve `git diff --staged` ile neyin gittiğini kontrol et; build çıktıları, IDE dosyaları ve gizli dosyalar asla commit'e girmesin

## 8. Güvenlik

Repo public olduğu için gizli bilgi sızıntısı en önemli risk. Uygulama çevrimdışı ve hesapsız olduğu için saldırı yüzeyi küçük, ama aşağıdakiler mutlaka uygulanır.

### 8.1 Gizli bilgiler

- `.gitignore` ilk commit'te eklendi ve şunları kapsar: `android/key.properties`, `*.jks`, `*.keystore`, `*.p12`, `*.mobileprovision`, `ios/Runner/GoogleService-Info.plist`, `android/app/google-services.json`, `.env*`, `build/`, `.dart_tool/`, `*.iml`, `.idea/`, `.vscode/` (paylaşılan ayarlar hariç)
- Koda hiçbir anahtar, şifre, token gömülmez. İmzalama bilgileri sadece yerel `key.properties` dosyasından okunur, repoda `android/key.properties.example` şablonu var
- Her commit öncesi staged dosyalar gizli bilgi açısından kontrol edilir. CI'da gitleaks ile secret taraması çalışır

### 8.2 Bağımlılıklar

- Sadece gerekli, bakımı süren, pub.dev'de doğrulanmış yayıncılı veya yüksek puanlı paketler kullanılır. Yeni paket eklemeden önce gerekçesi söylenir
- `pubspec.lock` commit'lenir
- CI'da osv-scanner ile bilinen açık taraması yapılır; her aşama sonunda `flutter pub outdated` kontrol edilir
- Dependabot yapılandırması (`.github/dependabot.yml`, pub + github-actions, haftalık)

### 8.3 İzinler ve platform ayarları

- Gereksiz hiçbir izin istenmez. Release Android manifestinde `INTERNET` izni yoktur (debug/profile manifestlerinde Flutter'ın kendi eklediği kalabilir). Kamera, konum, rehber, depolama izni yok
- Paylaşma özelliği geçici dosyayı uygulamanın cache dizinine yazar, paylaşımdan sonra temizler; harici depolama izni gerektirmez
- Android: `android:usesCleartextTraffic="false"`, gereksiz `exported` bileşen yok
- Release build `--obfuscate --split-debug-info` ile alınır, komutu README'de
- Release'de `print`/`debugPrint` ile kullanıcı verisi loglanmaz (lint kuralı `avoid_print` açık)

### 8.4 Veri ve girdi güvenliği

- Veritabanı sorguları sadece drift'in tip güvenli API'siyle yapılır, ham SQL'e string birleştirme ile değer eklenmez
- Tüm kullanıcı girdileri doğrulanır: oyuncu ismi en fazla 20 karakter ve boş olamaz, grup ismi en fazla 30 karakter, puanlar makul aralıkta (±99.999), sayaçlar negatif olamaz, Batak'ta toplam el sınırı geçilemez. Geçersiz girdi uygulamayı çökertmez
- Veritabanı migration'ları test edilir; şema değişikliğinde eski verisi olan kullanıcının uygulaması çökmez, veri kaybı olmaz
- Bozuk/beklenmeyen veri okunduğunda uygulama çökmez, hatayı yakalayıp kullanıcıya anlaşılır mesaj gösterir

### 8.5 Güvenlik testleri

- Girdi doğrulama için unit testler: sınır değerler, boş string, çok uzun string, emoji/özel karakter içeren isimler, aşırı büyük/negatif sayılar
- Veritabanı migration testleri
- Release manifestinde izin kontrolü yapan CI adımı (`INTERNET` izni release'de varsa CI başarısız olur)

### 8.6 CI (GitHub Actions)

`.github/workflows/ci.yml` her push ve pull request'te şunları çalıştırır:

1. `dart format --set-exit-if-changed .`
2. `flutter analyze`
3. `flutter test`
4. gitleaks secret taraması
5. osv-scanner bağımlılık taraması

Action'lar sürüm etiketiyle değil commit SHA'sıyla sabitlenir, workflow'un `permissions` alanı `contents: read`.

## Komutlar

```bash
flutter pub get
dart run build_runner build
dart format .
flutter analyze
flutter test
scripts/check_release_permissions.sh
```

## Son kararlar

- 2026-11-07: 101'de çarpanlar birbiriyle çarpılır (çiftten açıp okeyle bitiş x4, elden okeyle bitiş x4).
- 2026-11-07: 101'de çiftten açıp bitiremeyen oyuncunun kalan taşları x2 yazılır (kurallardan kapatılabilir).
- 2026-11-07: Eşli 101'de eli bitirenin eşi o elde 0 yazar.
- 2026-11-07: Batak'ta 3 kişide bir dağıtımda 17 el, 4 kişide 13 el.
- 2026-11-07: Eşli klasik Okey'de takım başına tek puan (takım 20 ile başlar).
- 2026-11-07: Biten oyunlar ana sayfada ayrı "Biten Oyunlar" bölümünde görünür.
- 2026-11-07: Uygulama kimliği `com.sudekazan.yazboz`.
- 2026-11-07: Commit mesajları bu projede "…eklendi / …düzeltildi" kalıbında.
- 2026-11-07: Renk paleti "Çuha": tek vurgu rengi masa çuhası yeşili, puan rakamları renklendirilmez (`docs/plan.md` 6. bölüm).
- 2026-11-07: Lint için flutter_lints + ek kurallar; üretilen `*.g.dart` ve l10n dosyaları repoya girmez, CI'da üretilir.
- 2026-11-07: iOS deployment target 15.0. Release Android build'i `key.properties` yoksa debug anahtarıyla imzalanır (sadece CI için).
