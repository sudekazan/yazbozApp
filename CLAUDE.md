# Yazboz — Flutter Uygulaması (Proje Talimatı)

Masa ve kart oyunları için dijital yazboz (skor tutma) uygulaması. Flutter, iOS + Android, arayüz Türkçe (ARB ile). İnternet, hesap ve reklam yok; tüm veri cihazda kalır.

Temel ilke: sadelik ve hız. Masada puan girişi 2-3 dokunuşu geçmemeli.

Ayrıntılar bu dosyada yok, gerektiğinde oku:
- `docs/plan.md`: mimari, domain modeli, şablon kuralları, veritabanı şeması, ekran akışı, paketler, CI ve güvenlik.
- `docs/ilk-talimat.md`: ilk yazılan uzun talimat (arşiv). Plan'la çelişirse plan geçerli.
- `README.md`: kurulum, build ve release komutları.

Kapsam dışı (şimdilik yapma): bulut senkronizasyonu, hesap sistemi, reklam, istatistik ekranı, çoklu cihaz.

## Kodlama kuralları

- State: Riverpod (riverpod_generator). Veritabanı: drift. Navigasyon: go_router.
- Oyun kuralı değerlerini koda gömme; her şablonun değerleri `RuleSet` modelinde durur ve kurulumda düzenlenebilir.
- Puan motoru UI'dan bağımsız, saf Dart. Her el ham girdisiyle saklanır (düzenlenince yeniden hesaplanır).
- Dağıtıcı sırası kayıtlı değil, türetilir. Oyuncu ile koltuk ayrı modellenir.
- Kullanıcıya görünen her metin ARB dosyasından gelir.
- Her şablonun puan motoru için unit test zorunlu; kuralların her biri için en az bir test.
- Yeni paket eklemeden önce gerekçesini söyle.

## UI/UX kuralları (zorunlu)

- Material 3, tek vurgu rengi (palet "Çuha", `docs/plan.md`). Glassmorphism, gradient buton, gereksiz gölge, dekoratif illüstrasyon yok.
- 4/8pt boşluk. Spacing, renk ve tipografi `theme/` altında token; widget'ta sabit sayı/renk yok.
- En fazla 2 font ağırlığı. Skor rakamları büyük ve tabular figures.
- Dokunma alanı en az 48x48 dp. Açık ve koyu tema kusursuz, kontrast WCAG AA.
- Butonlar fiille başlar ("Oyunu Başlat", "El Ekle"); "Tamam", "Gönder" yok.
- Silmede onay diyaloğu neyin silineceğini söyler; mümkünse snackbar + "Geri Al".
- Hata mesajı kullanıcıyı suçlamaz, çözüm söyler ("Toplam el sayısı 13 olmalı, şu an 12").
- Animasyon 150-250 ms, "azaltılmış hareket" ayarına uyar. İkon butonlarda Semantics/tooltip var.
- iPhone SE boyutunda ve büyük fontta taşma yok; yatay kaydırma yok.

## Çalışma şekli

- Her ekran bitince commit'ten önce UI/UX kurallarına göre madde madde kontrol et.
- Aşama sonunda güvenlik kontrolünü yap.
- Son kontrolde tam UI/UX ve güvenlik denetimi yap, `SECURITY_REVIEW.md`'ye yaz.

## Git ve commit

- Repo public: https://github.com/sudekazan/yazbozApp. Var olan dosyaları silme veya üzerine yazma, önce sor.
- Commit öncesi sırayla: `dart format .`, `flutter analyze` (sıfır uyarı). Analyze başarısızsa commit atma. Testler commit için şart değil; sadece değişen kısmın testlerini çalıştır (`-r failures-only`), sonucu söyle.
- Bir commit = tek mantıksal değişiklik. Mesaj sade Türkçe cümle, ön ek yok ("Skor tablosuna dağıtıcı göstergesi eklendi"). Bu kural tüm `.md` dosyaları için de geçerli.
- Commit'ten önce `git status` ve `git diff --staged` ile neyin gittiğine bak; build çıktısı, IDE dosyası ve gizli dosya girmesin.
- `git push` her aşama sonunda yapılır, ama sormadan push etme.

## Güvenlik (repo public)

- Koda anahtar, şifre, token girmez. İmzalama bilgisi yerel `android/key.properties`'ten okunur (`.example` şablonu repoda).
- Release Android manifestinde `INTERNET` izni olmaz (`scripts/check_release_permissions.sh`). Gereksiz izin yok.
- Veritabanında ham SQL'e string birleştirme yok. Girdiler doğrulanır (oyuncu adı en fazla 20, grup adı en fazla 30 karakter, puan ±99.999, sayaç negatif olamaz); geçersiz girdi çökertmez.
- Migration'lar test edilir, eski veri kaybolmaz.
- CI, action'lar commit SHA'sıyla sabit, `permissions: contents: read`. Ayrıntı: `docs/plan.md` bölüm 8.

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
- 2026-11-08: Commit öncesi tüm testler değil, sadece değişen kısmın testleri çalışır (`-r failures-only`); tam test iş bitince bir kez.
