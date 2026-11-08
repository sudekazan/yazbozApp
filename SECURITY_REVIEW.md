# Güvenlik ve UI/UX Denetimi

Tarih: 2026-11-08. Kapsam: ekranların tamamı bitmiş hali (ana sayfa, oyun seçimi, kurulum, skor tablosu, 6 şablonun el girişi, oyun sonu, ayarlar). Bu belge neyin kontrol edildiğini ve sonucunu yazar; kontrol edilmeyen yerler ayrıca belirtilmiştir.

## 1. Güvenlik

| Kontrol | Nasıl bakıldı | Sonuç |
|---|---|---|
| Koda gömülü anahtar, şifre, token | `lib`, `test`, `android`, `ios/Runner`, `scripts`, `docs`, `pubspec.yaml` içinde anahtar sözcük ve bilinen anahtar kalıpları arandı | Temiz. Tek eşleşme `android/app/build.gradle.kts` içindeki `keyPassword`/`storePassword`; bunlar yerel `key.properties`'ten okunuyor, değer yok |
| Gizli dosyaların git'te olmaması | `.gitignore` kalıpları ve `git ls-files` ile `key.properties`, `*.jks`, `*.keystore`, `.env`, `google-services`, `*.p8` arandı | Hiçbiri izlenmiyor; kalıpların hepsi `.gitignore`'da |
| Ham SQL ve string birleştirme | `customSelect`, `customStatement`, `rawQuery`, `execute` arandı | Yalnızca iki sabit ifade var (`SELECT 1` değişim izleme, `PRAGMA foreign_keys = ON`). Kullanıcı girdisi SQL'e girmiyor; sorgular drift'in tip güvenli API'siyle |
| Ağ erişimi | `lib` içinde `http://` ve `https://` arandı; Android manifesti ve iOS `Info.plist` okundu | Kodda adres yok. Ana manifestte `INTERNET` yok (yalnızca debug ve profile manifestlerinde, Flutter'ın varsayılanı). `usesCleartextTraffic="false"` |
| Girdi doğrulama | `validation.dart` ve motor testleri | Oyuncu adı ≤ 20, grup adı ≤ 30 karakter (emoji dahil sayılır), puan ±99.999, sayaçlar negatif olamaz; geçersiz girdi çökertmez, hata çözüm söyler. El girişinde alanlar zaten en fazla 5 basamak alıyor |
| Günlükleme | `print` ve `debugPrint` arandı | Kullanımı yok; kişisel veri günlüğe yazılmıyor |
| Geçici dosya (tablo paylaşma) | Kod incelendi, testle doğrulandı | Görsel geçici dizine yazılıyor, paylaşım bitince `finally` ile siliniyor |
| CI | `.github/workflows/ci.yml` okundu | `permissions: contents: read`; action'lar commit SHA'sıyla sabit; `persist-credentials: false`; gitleaks (sürüm ve SHA256 sabit) ve osv-scanner çalışıyor |
| Yeni paketler | `pubspec.yaml` | `wakelock_plus`, `share_plus`, `path_provider` `docs/plan.md` 7. bölümde gerekçesiyle onaylıydı |
| Veritabanı geçişleri | Testler | Geçiş testleri var ve geçiyor (tüm testler: 441 geçti) |

### Bulgular

1. **Android otomatik yedekleme açık olabilir (karar bekliyor).** Manifestte `android:allowBackup` yazılmamış; Android'de varsayılanı açık. Açıkken oyun verileri Google yedeğine gidebilir. Uygulamanın vaadi "tüm veriler cihazda kalır". Kapatmak (`allowBackup="false"`) vaadi sıkılaştırır ama telefon değişince oyun geçmişi yedekten gelmez. **Bunu ben seçmedim; senin kararın.**
2. **`WAKE_LOCK` izni.** `wakelock_plus` Android manifestine `WAKE_LOCK` ekleyebilir. Bu zararsız bir izin ve `INTERNET` kuralını bozmaz, ama `scripts/check_release_permissions.sh` yasak listesinde olmayan her izni görmek için çıktısına bakılmalı.

### Kontrol edilmeyenler

- **Release APK izinleri:** `scripts/check_release_permissions.sh` çalıştırılamadı. Release APK derlemesi bu oturumda tamamlanmadı (ilk Gradle derlemesi çok uzun sürdü; ayrıca `JAVA_HOME` ayarlı değildi, `/Library/Java/JavaVirtualMachines/openjdk.jdk/Contents/Home` ile denendi). Yukarıdaki izin sonuçları kaynak manifestlerden, derlenmiş APK'dan değil.
- **gitleaks ve osv-scanner yerelde yok.** Bu iki tarama yalnızca CI'da çalışıyor; yerelde elle arama yapıldı.
- **iOS izinleri:** `Info.plist`'te kullanım açıklaması isteyen bir izin eklenmedi (kamera, konum, fotoğraf yok); paylaşma menüsü izin istemiyor.

## 2. UI/UX

Kod taraması (`CLAUDE.md` "UI/UX kuralları"):

| Kural | Sonuç |
|---|---|
| Widget'ta sabit renk yok | Temiz. `Color(0x…)` yalnızca `app_colors.dart`'ta; özelliklerde sadece tema renkleri. `Colors.transparent` temada |
| Spacing, boyut, süre token'dan | Özellik dosyalarında sabit boyut ve süre yok |
| İkon butonlarında ipucu | Tüm `IconButton`'lar `tooltip` taşıyor |
| Butonlar fiille başlar | "Tamam", "Gönder" yok; "El Ekle", "Rövanş Yap", "Tabloyu Paylaş", "Eli Sil" |
| Silmede onay ve geri al | El, grup ve oyun silmede neyin silineceği söylenir; el ve grup için bildirimde "Geri Al" var |
| Hata mesajı çözüm söyler | ARB'de "… seç.", "… olmalı, şu an …" kalıbı |
| Kullanıcıya görünen metin ARB'den | Evet |

Gözle kontrol (iPhone 16e simülatörü, açık ve koyu tema):

- Ana sayfa, oyun seçimi, kurulum, skor tablosu ve 101 el girişi açık temada; el girişi koyu temada. Akış baştan sona çalıştı, veri uygulama yeniden başlayınca kalıcı.
- **Bulundu ve düzeltildi:** tek oyunculu sütunda lider kupası ve dağıtıcı kartı ismi "Oy…" diye kesiyordu → ikonlar ismin üstüne taşındı. El girişi sayfası %92 yükseklikte satırları tuş takımının arkasında bırakıyordu → sayfa tam yükseklik, 101'de odak yazılabilir alana kayıyor (commit `8c4a521`).
- **Kalan sıkışıklık:** 101'de dört oyuncu satırı aynı anda görünmüyor, kaydırmak gerekiyor. Tuş takımı küçültülmedi (48 dp dokunma alanı kuralı).

Widget testleriyle (cihazda değil): her ekran 320×568 boyutunda ve 2× yazı ölçeğinde, açık ve koyu temada taşma vermiyor; ekran okuyucu etiketleri ve eylemleri tablo, el girişi ve oyun sonunda doğrulandı.

### Kontrol edilmeyenler

- Cihazda büyük yazı boyutu ve iPhone SE boyutu (yalnızca testte).
- Koyu temada skor tablosu ve oyun sonu ekranları gözle bakılmadı (el girişi bakıldı).
- Paylaşım menüsünün gerçekten açılması ve görselin içeriği (testte paylaşım işlevi yedekle değiştirildi).
- Titreşimin hissi ve ekranın gerçekten açık kaldığı.
- Android cihazı ya da emülatörü hiç denenmedi.
- "Azaltılmış hareket" ayarı: animasyon süreleri `AppDurations.resolve` ile bu ayara bağlı, ama ayar açıkken elle denenmedi.
