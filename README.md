# emulator-yomikai

Изолированный эмулятор-харнесс для тестирования APK **yomikai**
(read-читалка манги с OCR и озвучкой). Держит ВСЁ эмуляторное в отдельном
репозитории, чтобы не создавать конфликтов с основным репо сборки.

## Что здесь

- `scripts/setup_emulator.sh` — установка компонентов Android SDK (эмулятор,
  системный образ), создание AVD.
- `scripts/run_tests.sh` — запуск эмулятора, установка APK из релиза,
  smoke-тесты (запуск, вкладки, скриншоты).
- `scripts/install_apk.sh` — быстрая установка конкретного APK в уже
  запущенный эмулятор.

## Как пользоваться

```bash
# 1. Подготовить SDK и AVD (однократно)
ANDROID_HOME=/usr/local/lib/android/sdk bash scripts/setup_emulator.sh

# 2. Загрузить APK из последнего релиза yomikai
gh release download universal-v1.9.84 -R sj0404-collab/yomikai -p "*.apk"

# 3. Запустить тесты
ANDROID_HOME=/usr/local/lib/android/sdk bash scripts/run_tests.sh
```

## Требования

- Linux с KVM (`/dev/kvm`), или macOS c Hardware Acceleration.
- `adb`, `sdkmanager`, `avdmanager` (из Android cmdline-tools).
- `gh` CLI с доступом к релизам `sj0404-collab/yomikai`.

## Почему отдельный репо

Основной репозиторий `yomikai` собирает APK (release workflow) и не должен
содержать тяжёлые эмуляторные артефакты (AVD-образы, скриншоты, логи). Всё
эмуляторное живёт здесь и не трогает ветки/CI основного репо.