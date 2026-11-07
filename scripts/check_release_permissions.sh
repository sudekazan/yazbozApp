#!/usr/bin/env bash
# Release APK'da gereksiz izin ya da şifresiz trafik izni olup olmadığını kontrol eder.
# Kullanım: scripts/check_release_permissions.sh [apk-yolu]
# Önce: flutter build apk --release
set -euo pipefail

APK="${1:-build/app/outputs/flutter-apk/app-release.apk}"
SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}"
AAPT2="$(ls "$SDK"/build-tools/*/aapt2 2>/dev/null | sort -V | tail -1 || true)"

if [[ -z "$AAPT2" || ! -x "$AAPT2" ]]; then
  echo "aapt2 bulunamadı: $SDK/build-tools altında Android build-tools kurulu olmalı." >&2
  exit 2
fi
if [[ ! -f "$APK" ]]; then
  echo "APK bulunamadı: $APK. Önce 'flutter build apk --release' çalıştır." >&2
  exit 2
fi

FORBIDDEN=(
  android.permission.INTERNET
  android.permission.ACCESS_NETWORK_STATE
  android.permission.CAMERA
  android.permission.RECORD_AUDIO
  android.permission.ACCESS_FINE_LOCATION
  android.permission.ACCESS_COARSE_LOCATION
  android.permission.READ_CONTACTS
  android.permission.READ_EXTERNAL_STORAGE
  android.permission.WRITE_EXTERNAL_STORAGE
  android.permission.READ_MEDIA_IMAGES
  android.permission.READ_MEDIA_VIDEO
)

permissions="$("$AAPT2" dump permissions "$APK")"
echo "Release APK izinleri:"
echo "$permissions"

failed=0
for permission in "${FORBIDDEN[@]}"; do
  if grep -q "name='$permission'" <<<"$permissions"; then
    echo "HATA: release APK'da $permission izni var; uygulama bu izne ihtiyaç duymamalı." >&2
    failed=1
  fi
done

manifest="$("$AAPT2" dump xmltree --file AndroidManifest.xml "$APK")"
if ! grep -Eq 'usesCleartextTraffic\([^)]*\)=false' <<<"$manifest"; then
  echo "HATA: android:usesCleartextTraffic=\"false\" release manifestinde bulunamadı." >&2
  failed=1
fi

if [[ "$failed" -ne 0 ]]; then
  exit 1
fi
echo "Tamam: yasaklı izin yok, şifresiz trafik kapalı."
