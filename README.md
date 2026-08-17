# Antigravity CLI + IDE 2.0 — воспроизводимая установка и патч (Linux)

> Проверенный на практике конвейер установки **Antigravity IDE 2.0** и **CLI (`agy`)** на Linux
> с патчингом региональных ограничений строго внутри **Docker-песочницы без доступа в интернет**.
> Всё локально, воспроизводимо, с бекапами на каждом шаге.

English: Reproducible Linux install pipeline for Antigravity IDE 2.0 + CLI (`agy`) with
regional-patch applied inside an **offline** Docker sandbox (`--network none`).

---

## ⚠️ Дисклеймер

- Репозиторий содержит **только скрипты и документацию**. Проприетарные бинари Google
  (Antigravity/`agy`) сюда **не входят** — официальные архивы скачиваешь ты сам.
- Патчер — сторонний проект [`AvenCores/open-antigravity-patcher`](https://github.com/AvenCores/open-antigravity-patcher)
  (GPL-3.0). Он клонируется скриптами и **копируется в образ при сборке**, а не скачивается в рантайме.
- Перед использованием убедись, что это легально и допустимо для тебя (регион, ToS, лицензии).

---

## 📦 Что входит

```
agy/
├── README.md            ← этот файл (обзор + быстрый старт)
├── LICENSE              ← MIT (наши скрипты и доки)
├── scripts/             ← основной конвейер
│   ├── 05_check_env.sh       проверка предусловий (docker, tar, PATH, архивы)
│   ├── 00_uninstall.sh      полная зачистка Antigravity с бекапами
│   ├── 10_sources.sh        подготовка источников: архивы + клон патчера (pin) + sha256
│   ├── 20_build.sh          docker build образа safe-ag-patcher (из локальных копий)
│   ├── 30_patch.sh          распаковка архивов + ПАТЧ (контейнер --network none)
│   ├── 40_install.sh        установка: ~/apps/antigravity-ide + ~/.local/bin/agy + .desktop
│   ├── 50_postinstall.sh    идемпотентная доводка: автоапдейты off + проверка патча
│   ├── 90_check_updates.sh  РУЧНОЙ выпуск патчера в интернет (разовый --rm контейнер)
│   └── reset-login.sh       сброс авторизации/аккаунта (файлы + keyring + кеши)
├── build/                ← песочница
│   ├── Dockerfile            образ из python:3.12-slim, non-root, cap-drop ALL
│   ├── entrypoint.sh
│   └── driver.py             неинтерактивный драйвер (без диалогов/captcha/браузера)
└── docs/
    ├── INSTALL.md            пошаговая установка
    ├── PATCH.md              как устроен патч и как им пользоваться
    ├── ERRORS.md             ошибки: #3501, HTTP 400/500, «сразу заходит», keyring
    ├── UPDATES.md            обновления и повторный патчинг
    └── SOURCES.md            где брать официальные архивы и как скормить их конвейеру
```

## 🚀 Быстрый старт (Linux, Ubuntu 24.04)

```bash
# 1. Клонируй и перейди
git clone https://github.com/VS-212/agy.git && cd agy

# 2. Предусловия: Docker (системный демон), полезные утилиты
#    sudo apt install docker.io && sudo usermod -aG docker "$USER"   # после этого выйти/зайти
bash scripts/05_check_env.sh     # проверить готовность (docker, tar, PATH, архивы)

# 3. Официальные архивы (бинар без сети в репо не лежит):
#      - IDE:  Antigravity(...).tar.gz     (~160 МБ)
#      - CLI:  agy_cli_linux_x64.tar.gz    (~55 МБ)
#    положи в ~/Downloads (см. docs/SOURCES.md), либо передай пути напрямую:
#    AGY_IDE_ARCHIVE=/путь/иде.tar.gz AGY_CLI_ARCHIVE=/путь/agy.tar.gz bash scripts/10_sources.sh

# 4. Конвейер (порядок важен!)
bash scripts/10_sources.sh   # архивы в sources/ + клон патчера + sha256
bash scripts/20_build.sh     # собрать песочницу safe-ag-patcher:latest
bash scripts/30_patch.sh     # распаковка + патч (БЕЗ сети), контрольные суммы
bash scripts/40_install.sh   # установка IDE/CLI + .desktop
bash scripts/50_postinstall.sh  # автоапдейты off + проверка патча (идемпотентно)

# 5. Один ручной шаг — SUID chrome-sandbox (иначе IDE только с --no-sandbox):
sudo chown root:root ~/apps/antigravity-ide/chrome-sandbox && sudo chmod 4755 ~/apps/antigravity-ide/chrome-sandbox

# 6. Вход: аутентификация в браузере-ИНКОГНИТО одним Google-аккаунтом →
#    открыть IDE (ярлык Antigravity) или CLI (agy). Цикл повторять при переустановке.
```

Проверка, что патч применился:

```bash
docker run --rm --network none \
  -v "$HOME/apps":/app/apps -v "$HOME/.local/bin":/app/bin \
  safe-ag-patcher:latest status /app/apps/antigravity-ide/resources/bin/language_server /app/bin/agy
# → language_server : patched
# → agy             : patched
```

## 🔒 Модель безопасности

Патчер — непроверенный сторонний код, поэтому он работает **только в песочнице**:

| Механизм | Значение |
|---|---|
| Сеть | `--network none` **по умолчанию** (никаких проверок обновлений, DNS, телеметрии) |
| Привилегии | `--cap-drop ALL`, `--security-opt no-new-privileges`, non-root (uid 1000) |
| Данные | В контейнер монтируются **только** цели (`final/`) и `state/` — нет `~/.ssh`, `~/.gemini`, `.git` |
| Интерактивность | Все диалоги/captcha/«открыть браузер» заблокированы (driver.py) |
| Сети нет вообще | Единственное исключение — явный ручной запуск `scripts/90_check_updates.sh` |
| Откат | `.agybak`-бекапы создаются рядом с целями до изменений |

## 🛡️ Обновления — только вручную

Автопроверка обновлений **отключена намеренно**: автоапдейт заменил бы пропатченные
бинари свежими (НЕпропатченными). Инструкции — в [`docs/UPDATES.md`](docs/UPDATES.md).

## 🔎 Частые ошибки — коротко

| Ошибка | Причина | Решение |
|---|---|---|
| `#3501 You do not have a valid license` | **Серверная** лицензия Google для аккаунта/региона | Локально НЕ лечится: ждать/сменить аккаунт с лицензией; подробно [`docs/ERRORS.md`](docs/ERRORS.md) |
| `HTTP 400 User location is not supported` | Регион определён как неподдерживаемый | Патч снимает локальный гейт; при наличии — DNS/Xbox-обход или смена аккаунта |
| `HTTP 500 Internal Server Error` | Внутренний отказ на стороне Google | Менять аккаунт (официальный регион/платная подписка) |
| «Сразу заходит» после сброса | Токен в GNOME keyring + кеш `google-vscode-extension` | `bash scripts/reset-login.sh` (чистит всё с бекапом) |

## 📜 Лицензия

- Скрипты и документация этого репо: **MIT** (см. [LICENSE](LICENSE)).
- Патчер (`open-antigravity-patcher`): **GPL-3.0**, берётся из его официального репозитория.
- Бинари Antigravity: проприетарные, принадлежат Google — не входят в этот репозиторий.