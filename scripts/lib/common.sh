#!/usr/bin/env bash
# Общие настройки и хелперы для скриптов эмулятора.
# Автодетект SDK, размещения AVD, прав KVM и запущенных эмуляторов.

set -euo pipefail

SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-/usr/local/lib/android/sdk}}"
ADB="$SDK/platform-tools/adb"
EMULATOR="$SDK/emulator/emulator"
SDKM="$SDK/cmdline-tools/latest/bin/sdkmanager"
AVDM="$SDK/cmdline-tools/latest/bin/avdmanager"
AAPT2="$(ls -1v "$SDK"/build-tools/*/aapt2 2>/dev/null | tail -1)"

YOMIKAI_REPO="${YOMIKAI_REPO:-sj0404-collab/yomikai}"
AVD_NAME="${AVD_NAME:-yomikai_test_api35}"
SYSTEM_IMAGE="${SYSTEM_IMAGE:-system-images;android-35;google_apis;x86_64}"
PKG_DEFAULT="app.yomihon"
ACTIVITY_DEFAULT="eu.kanade.tachiyomi.ui.main.MainActivity"

resolve_avd_home() {
  local cand
  for cand in "${ANDROID_AVD_HOME:-}" "$HOME/.config/.android/avd" "$HOME/.android/avd"; do
    [ -n "$cand" ] && [ -f "$cand/$AVD_NAME.ini" ] && { ANDROID_AVD_HOME="$cand"; break; }
  done
  ANDROID_AVD_HOME="${ANDROID_AVD_HOME:-$HOME/.android/avd}"
  mkdir -p "$ANDROID_AVD_HOME"
  export ANDROID_AVD_HOME
}
resolve_avd_home

kvm_usable() {
  [ -c /dev/kvm ] || return 1
  [ -r /dev/kvm ] && [ -w /dev/kvm ]
}

avd_exists() {
  [ -f "$ANDROID_AVD_HOME/$AVD_NAME.ini" ]
}

emulator_run() {
  if kvm_usable; then
    "$EMULATOR" "$@"
  elif command -v sg >/dev/null 2>&1 && [ -c /dev/kvm ]; then
    sg kvm -c "$(printf '%q ' "$EMULATOR")$(printf '%q ' "$@")"
  else
    echo "ERROR: /dev/kvm недоступен для текущего пользователя и нет 'sg' для переключения группы kvm" >&2
    return 1
  fi
}

list_running_serials() {
  "$ADB" devices 2>/dev/null | awk '/^emulator-/{print $1}'
}

find_running_emulator() {
  local serial name
  for serial in $(list_running_serials); do
    name=$("$ADB" -s "$serial" emu avd name 2>/dev/null | head -1) || true
    [ "$name" = "$AVD_NAME" ] && { echo "$serial"; return 0; }
  done
  return 1
}

pick_free_port() {
  local busy p
  busy=$(list_running_serials)
  for p in 5554 5556 5558 5560 5562 5564; do
    case "$busy" in *"emulator-$p"*) ;; *) echo "$p"; return 0 ;; esac
  done
  echo 5566
}

wait_for_boot() {
  local serial="$1" i=0
  "$ADB" -s "$serial" wait-for-device
  while [ $((i * 5)) -lt "${BOOT_TIMEOUT:-600}" ]; do
    [ "$("$ADB" -s "$serial" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ] && return 0
    sleep 5; i=$((i + 1))
  done
  return 1
}

latest_release_tag() {
  gh release list --repo "$YOMIKAI_REPO" --limit 1 --json tagName --jq '.[0].tagName' 2>/dev/null
}