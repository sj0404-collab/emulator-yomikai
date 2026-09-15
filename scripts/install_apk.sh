#!/usr/bin/env bash
# Установка конкретного APK в уже запущенный эмулятор.
# Пример: bash scripts/install_apk.sh /path/to/app.apk
set -euo pipefail

SDK="${ANDROID_HOME:-/usr/local/lib/android/sdk}"
ADB="$SDK/platform-tools/adb"
APK="${1:?Укажите путь к APK}"

"$ADB" wait-for-device
"$ADB" install -r "$APK"
echo "OK: $APK установлен"