# Yazboz

Masa ve kart oyunları için dijital yazboz (skor tutma) uygulaması. Serbest, Okey, 101 Okey, Tavla, Pişti ve Batak şablonları; puanları kurallara göre uygulama hesaplar. İnternet, hesap ya da reklam yok; tüm veriler cihazda kalır.

Platformlar: iOS ve Android (Flutter).

## Gereksinimler

- Flutter 3.47 (stable), Dart 3.13
- Android için JDK 17, iOS için Xcode

## Geliştirme

```bash
flutter pub get
flutter run
```

Her değişiklikten sonra:

```bash
dart format .
flutter analyze
flutter test
```

Proje kuralları ve verilen kararlar `CLAUDE.md` dosyasında, mimari ve veri modeli `docs/plan.md` dosyasında.

## Release

### Android imzası

`android/key.properties.example` dosyasını `android/key.properties` adıyla kopyalayıp kendi anahtar bilgilerinle doldur. Bu dosya ve anahtar dosyaları (`*.jks`, `*.keystore`) git'e girmez. `key.properties` yoksa release build debug anahtarıyla imzalanır; bu çıktı mağazaya yüklenemez.

### Build komutları

Kod karartma (obfuscation) açık, hata ayıklama sembolleri ayrı klasöre yazılır:

```bash
flutter build appbundle --release --obfuscate --split-debug-info=build/debug-info/android
```

```bash
flutter build ipa --release --obfuscate --split-debug-info=build/debug-info/ios
```

`build/debug-info/` içindeki sembol dosyalarını her sürüm için sakla; çökme kayıtlarını okunur hale getirmek için gerekir. Bu klasör git'e girmez.

### İzin kontrolü

Release APK'da `INTERNET` izni olmamalı. Kontrol için:

```bash
scripts/check_release_permissions.sh
```

## Güvenlik

Repo herkese açık. Anahtar, şifre ya da token koda veya repoya eklenmez. CI her push'ta gitleaks ile gizli bilgi, osv-scanner ile bilinen açık taraması yapar.
