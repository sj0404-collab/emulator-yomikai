#!/usr/bin/env bash
# Полный smoke-тест: переиспользует запущенный эмулятор нужного AVD или
# поднимает новый; авто-download последнего universal APK, авто-детект
# package/activity через aapt2, выдача runtime-разрешений, запуск app,
# проверка процесса, скриншоты и сканирование fatal-логов.
# KEEP_EMULATOR=0 выключит эмулятор по завершении (по умолчанию эмулятор
# остаётся работать для последующих запусков).
# Пример: ANDROID_HOME=/usr/local/lib/android/sdk bash scripts/run_tests.sh [path/app.apk]

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/lib/common.sh"

cd "$ROOT"

KEEP_EMULATOR="${KEEP_EMULATOR:-1}"
PKG="$PKG_DEFAULT"
ACTIVITY="$ACTIVITY_DEFAULT"
UI_PROBE="/tmp/emulator-yomikai-ui.xml"

ui_dump() {
  timeout 20 "$ADB" -s "$1" shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1 || return 1
  "$ADB" -s "$1" pull /sdcard/ui.xml "$UI_PROBE" >/dev/null 2>&1
}

ui_find_button() {
  python3 - "$UI_PROBE" "$1" <<'PY'
import re, sys
import xml.etree.ElementTree as ET
xml, pat = sys.argv[1], sys.argv[2]
rx = re.compile(pat, re.I)
best = None
for n in ET.parse(xml).getroot().iter('node'):
    t = (n.get('text') or '')
    if rx.search(t):
        m = re.match(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]', n.get('bounds') or '')
        if m and (best is None or n.get('clickable') == 'true'):
            x1, y1, x2, y2 = map(int, m.groups())
            best = ((x1 + x2) // 2, (y1 + y2) // 2)
if best:
    print(*best)
PY
}

dismiss_dialogs() {
  local serial="$1" i xy
  for i in 1 2 3 4; do
    ui_dump "$serial" || { sleep 2; continue; }
    xy=$(ui_find_button 'Wait|While using the app|Allow all the time|Allow|Разрешить|Принять|OK') || { sleep 2; continue; }
    "$ADB" -s "$serial" shell input tap $xy >/dev/null 2>&1
    sleep 3
    if ! "$ADB" -s "$serial" shell dumpsys activity activities 2>/dev/null | grep -qE "GrantPermissionsActivity|Application Not Responding"; then
      return 0
    fi
  done
}

# --- APK: аргумент > локальный universal > авто-download последнего релиза ---
APK="${1:-}"
if [ -z "$APK" ]; then
  APK="$(ls -1 yomikai-universal-*.apk 2>/dev/null | sort -V | tail -1 || true)"
fi
if [ -z "$APK" ]; then
  TAG="${YOMIKAI_TAG:-$(latest_release_tag)}"
  [ -n "$TAG" ] || { echo "ERROR: не удалось определить тег последнего релиза $YOMIKAI_REPO"; exit 2; }
  echo "== Скачиваем APK из релиза $TAG"
  gh release download "$TAG" --repo "$YOMIKAI_REPO" --pattern "*universal*.apk"
  APK="$(ls -1 yomikai-universal-*.apk 2>/dev/null | sort -V | tail -1)"
fi
if [ -n "$APK" ] && [ -f "$APK" ]; then
  echo "== Тестируем: $APK"
else
  echo "ERROR: APK не найден: $APK"
  exit 2
fi

# --- Авто-детект пакета и launchable-activity ---
if [ -n "$AAPT2" ]; then
  BADGING="$("$AAPT2" dump badging "$APK" 2>/dev/null)"
  P="$(printf '%s\n' "$BADGING" | sed -n "s/^package: name='\([^']*\)'.*/\1/p" | head -1)"
  A="$(printf '%s\n' "$BADGING" | sed -n "s/^launchable-activity: name='\([^']*\)'.*/\1/p" | head -1)"
  [ -n "$P" ] && PKG="$P"
  [ -n "$A" ] && ACTIVITY="$A"
fi
echo "== Пакет: $PKG / Активность: $ACTIVITY"

# --- Эмулятор: reuse или новый ---
SERIAL="$(find_running_emulator || true)"
STARTED=0
EMU_PID=""
if [ -n "$SERIAL" ]; then
  echo "== Переиспользуем запущенный эмулятор ($SERIAL, AVD $AVD_NAME)"
else
  PORT="$(pick_free_port)"
  SERIAL="emulator-$PORT"
  echo "== Запускаем новый эмулятор AVD $AVD_NAME на порту $PORT (headless)"
  emulator_run -avd "$AVD_NAME" -port "$PORT" -no-window -no-audio -no-boot-anim -no-snapshot \
    -gpu swiftshader_indirect -accel on -cores "${EMULATOR_CORES:-4}" -memory "${EMULATOR_RAM:-2048}" \
    > emulator.log 2>&1 &
  EMU_PID=$!
  STARTED=1
fi

cleanup() {
  if [ "$KEEP_EMULATOR" = "0" ] && [ "$STARTED" = "1" ]; then
    echo "== Выключаю эмулятор $SERIAL"
    "$ADB" -s "$SERIAL" emu kill >/dev/null 2>&1 || true
    [ -n "$EMU_PID" ] && kill "$EMU_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

if ! wait_for_boot "$SERIAL"; then
  echo "ERROR: эмулятор $SERIAL не загрузился за ${BOOT_TIMEOUT:-600}с"
  exit 1
fi
echo "== Система загружена ($SERIAL)"

echo "== Установка APK"
"$ADB" -s "$SERIAL" install -r "$APK" || { echo "ERROR: установка не удалась"; exit 1; }

echo "== Выдаём runtime-разрешения приложения"
if [ -n "$AAPT2" ]; then
  "$AAPT2" dump permissions "$APK" 2>/dev/null \
    | sed -n "s/^uses-permission: name='\([^']*\)'.*/\1/p" \
    | while read -r perm; do "$ADB" -s "$SERIAL" pm grant "$PKG" "$perm" >/dev/null 2>&1 || true; done
fi

echo "== Smoke-тест: запуск приложения $PKG/$ACTIVITY"
"$ADB" -s "$SERIAL" shell am start -n "$PKG/$ACTIVITY" >/dev/null
sleep "${SPLASH_WAIT:-10}"

dismiss_dialogs "$SERIAL"

PROC="$("$ADB" -s "$SERIAL" shell pidof "$PKG" 2>/dev/null | tr -d '\r')"
if [ -n "$PROC" ]; then
  echo "OK: процесс приложения жив (pid $PROC)"
else
  echo "FAIL: процесс $PKG не запущен"
  "$ADB" -s "$SERIAL" logcat -d 2>/dev/null | grep -iE "FATAL EXCEPTION|Force finishing|AndroidRuntime" | tail -20 || true
  exit 1
fi

echo "== Активность (top):"
"$ADB" -s "$SERIAL" shell dumpsys activity activities 2>/dev/null | grep -E "topResumedActivity|mResumedActivity" | head -2 || true

echo "== Скриншот:"
TS="$(date +%Y%m%d_%H%M%S)"
"$ADB" -s "$SERIAL" shell screencap -p /sdcard/yomikai.png >/dev/null
mkdir -p screenshots
"$ADB" -s "$SERIAL" pull /sdcard/yomikai.png "screenshots/yomikai_${PKG}_${TS}.png" >/dev/null 2>&1 || true
ls -1 screenshots/yomikai_*.png 2>/dev/null | tail -3 || true

echo "== Fatal-логи приложения:"
FATAL="$("$ADB" -s "$SERIAL" logcat -d 2>/dev/null | grep -E "FATAL EXCEPTION" | grep -F "$PKG" | tail -10 || true)"
if [ -n "$FATAL" ]; then
  echo "$FATAL"; exit 1
fi
echo "OK: fatal-ошибок нет"

if [ "$KEEP_EMULATOR" = "1" ]; then
  echo "OK: эмулятор $SERIAL оставлен запущенным (KEEP_EMULATOR=1), тест можно повторять"
else
  echo "OK: KEEP_EMULATOR=0"
fi
echo "DONE"