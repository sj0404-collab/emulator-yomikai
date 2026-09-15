#!/usr/bin/env bash
# Установка/обновление компонентов Android SDK и idempotent-создание AVD.
# Повторный запуск переиспользует установленные компоненты и существующий AVD.
# Пример: ANDROID_HOME=/usr/local/lib/android/sdk bash scripts/setup_emulator.sh

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/lib/common.sh"

echo "== SDK: $SDK"
echo "== ANDROID_AVD_HOME: $ANDROID_AVD_HOME"

# KVM / ускорение
if [ -c /dev/kvm ]; then
  if kvm_usable; then echo "OK: KVM доступен напрямую"
  elif command -v sg >/dev/null 2>&1; then echo "OK: KVM доступен через sg kvm (группа kvm)"
  else echo "WARN: /dev/kvm существует, но нет прав доступа. Используйте: sudo gpasswd -a \$(whoami) kvm"
  fi
else
  echo "WARN: /dev/kvm не найден — x86_64 эмуляция без аппаратного ускорения невозможна"
fi

# Установка пакетов (idempotent)
NEED_INSTALL=0
[ -x "$EMULATOR" ]          || { echo "== Требуется: emulator";         NEED_INSTALL=1; }
[ -d "$SDK/system-images/android-35/google_apis/x86_64" ] || { echo "== Требуется: $SYSTEM_IMAGE"; NEED_INSTALL=1; }
[ -x "$ADB" ]               || { echo "== Требуется: platform-tools";   NEED_INSTALL=1; }
[ -d "$SDK/platforms/android-35" ] || { echo "== Требуется: platforms;android-35"; NEED_INSTALL=1; }

if [ "$NEED_INSTALL" -eq 1 ]; then
  echo "== Установка недостающих компонентов"
  yes | "$SDKM" --licenses >/dev/null 2>&1 || true
  "$SDKM" --install "emulator" "$SYSTEM_IMAGE" platform-tools "platforms;android-35"
fi
echo "== Компоненты SDK готовы"

# AVD
if avd_exists; then
  echo "== AVD $AVD_NAME уже существует: $ANDROID_AVD_HOME/$AVD_NAME.ini — переиспользуем"
else
  echo "== Создаём AVD $AVD_NAME (ANDROID_AVD_HOME=$ANDROID_AVD_HOME)"
  echo "no" | "$AVDM" create avd -n "$AVD_NAME" -k "$SYSTEM_IMAGE" --device "pixel_6"
fi

echo "== Готово. Список AVD:"
"$AVDM" list avd 2>/dev/null | grep -B1 -A2 "Name:" || true
echo "== Эмулятор запустится: emulator_run -avd $AVD_NAME ... (auto через run_tests.sh)"