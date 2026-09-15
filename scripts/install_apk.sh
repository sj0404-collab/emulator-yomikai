#!/usr/bin/env bash
# Установка конкретного APK в уже запущенный эмулятор.
# Автоматически находит эмулятор с нашим AVD (или первый запущенный).
# Пример: bash scripts/install_apk.sh /path/to/app.apk

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/lib/common.sh"

APK="${1:?Укажите путь к APK}"
[ -f "$APK" ] || { echo "ERROR: файл не найден: $APK"; exit 1; }

SERIAL="$(find_running_emulator || true)"
[ -z "$SERIAL" ] && SERIAL="$(list_running_serials | head -1 || true)"
[ -n "$SERIAL" ] || { echo "ERROR: нет запущенного эмулятора. Сначала выполните: bash scripts/run_tests.sh"; exit 1; }

echo "== Устанавливаю $APK в $SERIAL (AVD $AVD_NAME)"
"$ADB" -s "$SERIAL" install -r "$APK"
echo "OK: установлен в $SERIAL"