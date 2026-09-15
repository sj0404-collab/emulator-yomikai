#!/usr/bin/env bash
# Установка компонентов Android SDK для эмулятора и создание AVD.
# Пример: ANDROID_HOME=/usr/local/lib/android/sdk bash scripts/setup_emulator.sh
set -euo pipefail

SDK="${ANDROID_HOME:-/usr/local/lib/android/sdk}"
SDKM="$SDK/cmdline-tools/latest/bin/sdkmanager"
AVDM="$SDK/cmdline-tools/latest/bin/avdmanager"
SYSTEM_IMAGE="system-images;android-35;google_apis;x86_64"
AVD_NAME="yomikai_test_api35"

echo "== SDK: $SDK"
echo "== Установка эмулятора и системного образа"
yes | "$SDKM" --licenses >/dev/null 2>&1 || true
"$SDKM" --install "emulator" "$SYSTEM_IMAGE" platform-tools platforms\;android-35

echo "== Создание AVD '$AVD_NAME'"
echo "no" | "$AVDM" create avd -n "$AVD_NAME" -k "$SYSTEM_IMAGE" --device "pixel_6" --force

echo "== Готово. AVD: $AVD_NAME"
"$AVDM" list avd | grep -A2 Name || true