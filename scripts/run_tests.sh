#!/usr/bin/env bash
# Запуск эмулятора, установка последнего universal APK yomikai и smoke-тесты.
# Пример: ANDROID_HOME=/usr/local/lib/android/sdk bash scripts/run_tests.sh
set -euo pipefail

SDK="${ANDROID_HOME:-/usr/local/lib/android/sdk}"
ADB="$SDK/platform-tools/adb"
EMULATOR="$SDK/emulator/emulator"
AVD_NAME="${AVD_NAME:-yomikai_test_api35}"
APK="${1:-$(ls -1 yomikai-universal-*.apk 2>/dev/null | sort -V | tail -1 || true)}"

if [ -z "$APK" ]; then
  echo "== APK не найден. Скачайте: gh release download universal-v1.9.84 -R sj0404-collab/yomikai -p '*.apk'"
  exit 1
fi
echo "== Тестируем: $APK"

echo "== Запуск эмулятора (headless)"
"$EMULATOR" -avd "$AVD_NAME" -no-window -no-audio -no-boot-anim -gpu swiftshader_indirect &
EMU_PID=$!
cleanup() { kill "$EMU_PID" 2>/dev/null || true; }
trap cleanup EXIT

"$ADB" wait-for-device
echo "== Ждём загрузку системы"
until [ "$("$ADB" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]; do
  sleep 2
done
echo "== Система загружена"

echo "== Установка APK"
"$ADB" install -r "$APK"

echo "== Smoke-тест: запуск приложения"
PKG="app.yomikai.reader"
"$ADB" shell am start -n "$PKG/.ui.MainActivity" >/dev/null 2>&1 || \
  "$ADB" shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
sleep 8

echo "== Активность:"
"$ADB" shell dumpsys activity activities | grep -E "topResumedActivity|mResumedActivity" | head -2 || true

echo "== Скриншот:"
"$ADB" shell screencap -p /sdcard/yomikai_launch.png
mkdir -p screenshots && "$ADB" pull /sdcard/yomikai_launch.png screenshots/ >/dev/null 2>&1 || true
echo "OK: эмулятор запущен, APK установлен."