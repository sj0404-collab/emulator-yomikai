#!/usr/bin/env bash
# Скачивание последнего universal APK yomikai из релизов.
# YOMIKAI_TAG=<tag> — конкретный релиз, иначе последний.
# Пример: bash scripts/download_apk.sh

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/lib/common.sh"

TAG="${YOMIKAI_TAG:-$(latest_release_tag)}"
[ -n "$TAG" ] || { echo "ERROR: не удалось определить тег релиза в $YOMIKAI_REPO"; exit 1; }

echo "== Скачиваю universal APK из релиза $TAG ($YOMIKAI_REPO)"
gh release download "$TAG" --repo "$YOMIKAI_REPO" --pattern "*universal*.apk" --skip-existing
ls -1 yomikai-universal-*.apk 2>/dev/null | tail -1
echo "OK"