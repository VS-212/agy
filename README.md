# Antigravity CLI + IDE 2.0 — воспроизводимая установка и патч (Linux)

> Проверенный на практике конвейер установки **Antigravity IDE 2.0** и **CLI (`agy`)** на Linux
> с патчингом региональных ограничений строго внутри **Docker-песочницы без доступа в интернет**.
> Всё локально, воспроизводимо, с бекапами на каждом шаге.

English: Reproducible Linux install pipeline for Antigravity IDE 2.0 + CLI (`agy`) with
regional-patch applied inside an **offline** Docker sandbox (`--network none`).

---

## 🤖 Для человека: запуск ИИ-агента

Репозиторий спроектирован так, что установку и патч выполняет **ИИ-агент** (агенту
достаточно этого README + `docs/`). Твоя задача — подготовить входные данные и передать
агенту готовый промпт.

### Шаг 0. Подготовь (1–2 минуты)

| Что | Требование |
|---|---|
| ОС | Linux x86-64 (проверено на Ubuntu 24.04) |
| Docker | установлен, твой пользователь в группе `docker`: `sudo usermod -aG docker "$USER"` (затем выйти/зайти) |
| Официальные архивы | скачай сам (в репо бинарей нет): IDE `Antigravity(...).tar.gz` (~160 МБ) и CLI `agy_cli_linux_x64.tar.gz` (~55 МБ). Положи в `~/Downloads` **или** подготовь точные пути до файлов |
| sudo | понадобится один раз — для SUID-шага `chrome-sandbox` |
| Google-аккаунт | один аккаунт для входа в IDE/CLI (вход делает **человек**, в инкогнито) |
| Интернет | да, на время первого клона репозитория и патчера |

### Шаг 1. Скопируй промпт агенту

```text
Выполни полную установку Antigravity IDE + CLI (agy) на этом Linux-хосте по репозиторию.

Источники:
- репо: https://github.com/VS-212/agy.git (клонируй локально: git clone https://github.com/VS-212/agy.git && cd agy)
- архивы:
    IDE = <ПУТЬ_К_АРХИВУ_IDE>
    CLI = <ПУТЬ_К_АРХИВУ_CLI>
  (если пути не указаны — ищи в ~/Downloads по именам Antigravity*.tar.gz и agy_cli_linux_x64.tar.gz)
- sudo для SUID-шага: доступен / недоступен   (укажи)

Порядок (не менять!):
1) bash scripts/05_check_env.sh   — проверить предусловия (docker, tar, PATH, архивы)
2) bash scripts/10_sources.sh     — подготовить источники; если пути архивов уходят через
   env:   AGY_IDE_ARCHIVE=<путь>  AGY_CLI_ARCHIVE=<путь> bash scripts/10_sources.sh
3) bash scripts/20_build.sh       — собрать образ песочницы safe-ag-patcher:latest
4) bash scripts/30_patch.sh       — патч строго офлайн; должен вернуть RC=0
5) bash scripts/40_install.sh     — установка IDE/CLI + .desktop
6) bash scripts/50_postinstall.sh — отключить автоапдейты + проверить патч (идемпотентно)

Ограничения:
- контейнеры с сетью НЕ запускать (единственное исключение — 90_check_updates.sh, только
  по явному разрешению пользователя);
- проприетарные бинари Google в репозиторий НЕ коммитить;
- если 30_patch.sh вернул код 2/3/4 («signature not found») — НЕ обходить и НЕ «чинить»
  самому: сообщи и смотри docs/UPDATES.md, docs/REVERSE.md;
- если выпала ошибка #3501 — это серверная лицензия Google (docs/ERRORS.md), локально
  не лечится: зафиксируй и не трать время на обход.

Финальный отчёт (обязательно):
- вывод статуса патча:
  docker run --rm --network none -v "$HOME/apps":/app/apps -v "$HOME/.local/bin":/app/bin \
    safe-ag-patcher:latest status /app/apps/antigravity-ide/resources/bin/language_server /app/bin/agy
  (ожидается: language_server : patched, agy : patched);
- версии установленных компонентов;
- оставшийся ручной SUID-шаг (если sudo недоступен);
- все ошибки и что сделано по ним.
```

### Шаг 2. Если агент запускается в командной строке — что передать

Единственное, что обычно нужно внести в командную строку — это пути к архивам (остальное
скрипты находят сами):

```bash
# положи пути в окружение ОДИН раз (свои пути замени)
export AGY_IDE_ARCHIVE="$HOME/Downloads/Antigravity(1).tar.gz"
export AGY_CLI_ARCHIVE="$HOME/Downloads/agy_cli_linux_x64.tar.gz"

cd ~/agy
bash scripts/05_check_env.sh   && \
bash scripts/10_sources.sh     && \
bash scripts/20_build.sh       && \
bash scripts/30_patch.sh       && \
bash scripts/40_install.sh     && \
bash scripts/50_postinstall.sh
```

Альтернатива без `export` — передать переменные только на один шаг:

```bash
AGY_IDE_ARCHIVE=/путь/иде.tar.gz AGY_CLI_ARCHIVE=/путь/agy.tar.gz bash scripts/10_sources.sh
```

### Шаг 3. После агента — что остаётся тебе (человеку)

1. Один `sudo`-шаг, если агент не смог его выполнить:
   ```bash
   sudo chown root:root ~/apps/antigravity-ide/chrome-sandbox && sudo chmod 4755 ~/apps/antigravity-ide/chrome-sandbox
   ```
2. Вход в IDE (ярлык Antigravity) — в **инкогнито-браузере одним Google-аккаунтом**.
3. Если увидишь `#3501` — это серверная лицензия Google, локально не лечится (детали в `docs/ERRORS.md`).

> 💡 Агент сам найдёт все детали в `docs/`: INSTALL, PATCH, REVERSE, ERRORS, UPDATES, SOURCES.

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
│   ├── 10_sources.sh        подготовка источников: архивы + клон патчера (canonical→mirror→local) + sha256
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
    ├── REVERSE.md            байтовые дельты патча (offset, asm, подтверждения) по версиям
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
bash scripts/10_sources.sh   # архивы в sources/ + клон патчера (canonical→зеркало→локально) + sha256
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