# Инструкция для ИИ-агента (каноническая)

Этот документ — **единственный канонический источник** сценариев работы с конвейером.
Скрипты — источник правды по поведению; при расхождении с README верь скриптам и этому
документу. Для контекста открывай также: `docs/INSTALL.md`, `docs/PATCH.md`,
`docs/UPDATES.md`, `docs/ERRORS.md`, `docs/SOURCES.md`, `docs/REVERSE.md`.

---

## 📋 Готовый промпт — скопируй человеку целиком

```text
Выполни установку/обновление Antigravity IDE + CLI (agy) на этом Linux-хосте по этому
репозиторию.

Порядок работы:
1. Прочитай docs/AGENT.md — это каноническая инструкция (сценарии, ограничения, отчёт).
2. Прочитай docs/INSTALL.md, docs/UPDATES.md, docs/ERRORS.md для контекста.
3. Проверь источники: репо уже склонировано (текущий каталог) ИЛИ клонируй
   https://github.com/VS-212/agy.git и работай из его корня.
4. Архивы: ищи в ~/Downloads по именам Antigravity*.tar.gz и agy_cli_linux_x64.tar.gz;
   если их там нет — СТОП, попроси человека положить архивы (в конвейер не продолжай).
5. Выполни конвейер в строгом порядке:
   bash scripts/05_check_env.sh && bash scripts/10_sources.sh && bash scripts/20_build.sh &&
   bash scripts/30_patch.sh && bash scripts/40_install.sh && bash scripts/50_postinstall.sh

Ограничения:
- контейнеры с сетью НЕ запускать (единственное исключение — 90_check_updates.sh,
  только по явному разрешению человека);
- проприетарные бинари Google в репозиторий НЕ коммитить;
- если 30_patch.sh вернул код 2/3/4 («signature not found») — НЕ обходить и НЕ «чинить»
  самому: следуй сценарию 4.3 из docs/AGENT.md (обновление патчера);
- если выпала ошибка #3501 / HTTP 400 / HTTP 500 — это серверные ответы Google,
  локально не лечатся: зафиксируй и не трать время (docs/ERRORS.md);
- sudo: если пароль недоступен — не обходи, напечатай готовые команды для человека.

Финальный отчёт (обязательно):
- версии установленных компонентов (agy --version и версия IDE);
- вывод статуса патча (команда из раздела 6 docs/AGENT.md;
  ожидается: language_server : patched, agy : patched);
- какие шаги прошли и какие коды возврата;
- оставшиеся ручные шаги для человека (SUID chrome-sandbox, /etc/hosts через sudo, вход);
- все ошибки и что сделано по ним.
```

---

## 1. Цель

Установить / обновить пропатченные **Antigravity IDE 2.0** и **CLI (`agy`)** на Linux x86-64
(проверено: Ubuntu 24.04) с помощью локального конвейера. Патч региональных ограничений
выполняется **строго в Docker-песочнице без сети** (`--network none`).

## 2. Источники

| Что | Где |
|---|---|
| Репозиторий | `https://github.com/VS-212/agy.git` → клонируй: `git clone https://github.com/VS-212/agy.git && cd agy` |
| Архивы (нет в репо!) | скачивает человек; ищи в `~/Downloads` по именам `Antigravity*.tar.gz` и `agy_cli_linux_x64.tar.gz`, либо пути передаются env-переменными |

Все пути **параметризуются переменными окружения** (шапка `scripts/10_sources.sh`):

| Переменная | Значение по умолчанию |
|---|---|
| `AGY_DOWNLOAD_DIR` | `$HOME/Downloads` |
| `AGY_IDE_ARCHIVE` | `$DL_DIR/Antigravity(1).tar.gz` |
| `AGY_CLI_ARCHIVE` | `$DL_DIR/agy_cli_linux_x64.tar.gz` |
| `AGY_PATCHER_URL` | `https://github.com/AvenCores/open-antigravity-patcher.git` |
| `AGY_PATCHER_MIRROR_URL` | `https://github.com/VS-212/open-antigravity-patcher-mirror.git` |
| `AGY_PATCHER_DIR` | локальная копия патчера (последний резерв) |

## 3. Конвейер установки — порядок НЕ менять

Каждый шаг должен завершиться успешно, прежде чем переходить к следующему:

```bash
bash scripts/05_check_env.sh    # предусловия: Linux x86_64, docker демон, tar/gzip/git/curl, PATH, архивы
bash scripts/10_sources.sh      # архивы -> sources/ + клон патчера (canonical → mirror → AGY_PATCHER_DIR) + sha256
bash scripts/20_build.sh        # docker build safe-ag-patcher:latest (из локальных sources/, сеть не нужна)
bash scripts/30_patch.sh        # распаковка + ПАТЧ (контейнер --network none) — ожидается RC=0
bash scripts/40_install.sh      # установка IDE в ~/apps, CLI в ~/.local/bin/agy, .desktop, проверка патча
bash scripts/50_postinstall.sh  # автоапдейты off (IDE yml + /etc/hosts) + проверка патча (идемпотентно)
```

### Коды возврата `30_patch.sh` (это КОД ОШИБКИ контейнера)

| RC | Значение |
|---|---|
| `0` | ок |
| `2` | менеджер IDE не пропатчен |
| `3` | CLI не пропатчен |
| `4` | оба не пропатчены |

Если контрольные суммы до/после совпали — патч не применился вне зависимости от RC.

### Про `sudo`

- `40_install.sh` и `50_postinstall.sh` пробуют `sudo -n` (контекст-агента). Если пароль
  недоступен — они печатают готовые команды для человека. **Не пытайся** подсовывать пароль,
  менять sudoers или обходить SUID-шаг — просто зафиксируй в отчёте.

## 4. Сценарии

### 4.1 Установка с нуля → раздел 3 (см. выше)

### 4.2 Новая версия Antigravity (IDE/CLI) от Google

1. Человек кладёт свежие архивы в `~/Downloads` (или даёт пути).
2. `bash scripts/10_sources.sh` (перезапишет старые `sources/*.tar.gz`)
3. `bash scripts/30_patch.sh` — если RC `0` → `40_install.sh`, `50_postinstall.sh`.
4. Если RC `2/3/4` (сигнатура новой версии не найдена) — **не обходи и не «чини» бинарь**:
   обнови патчер по сценарию 4.3, затем повторно `30_patch.sh` → `40_install.sh` →
   `50_postinstall.sh`.
5. После установки: `agy --version`, статус патча (раздел 6), человек перелогинивается.

### 4.3 Новая версия патчера (главный SPOF конвейера)

```bash
bash scripts/90_check_updates.sh    # РАЗОВЫЙ контейнер с сетью (только проверка, --rm); только с разрешения человека
git -C sources/patcher pull         # локальная копия патчера (или обнови mirror-снапшот в GitHub UI: Sync fork)
bash scripts/20_build.sh            # пересобрать образ
bash scripts/30_patch.sh && bash scripts/40_install.sh && bash scripts/50_postinstall.sh
```

### 4.4 Патч потерялся, версии те же (после переустановки ОС и т.п.)

```bash
bash scripts/20_build.sh && bash scripts/30_patch.sh && bash scripts/40_install.sh && bash scripts/50_postinstall.sh
```

### 4.5 Откат патча (бекапы `.agybak` рядом с целями)

```bash
docker run --rm --network none -v "$HOME/apps":/app/apps \
  safe-ag-patcher:latest restore-manager /app/apps/antigravity-ide/resources/bin/language_server
docker run --rm --network none -v "$HOME/.local/bin":/app/bin \
  safe-ag-patcher:latest restore-agy /app/bin/agy
```

### 4.6 Полная зачистка / сброс авторизации

- `bash scripts/00_uninstall.sh` — снести установку с бекапами (не трогает `~/.gemini`).
- `bash scripts/reset-login.sh` — сброс аккаунта/токенов/кешей (бекап в `~/Backups/`).

## 5. Ограничения (жёсткие)

- **Никаких контейнеров с сетью**, кроме явного `90_check_updates.sh` по разрешению человека.
- **Проприетарные бинари Google НЕ коммитить** в репозиторий (см. `.gitignore`).
- **Не обходить ошибки патча**: RC `2/3/4` → обнови патчер, а не «подправь бинарь вручную».
- `#3501`, `HTTP 400/500` — серверные ответы Google, локально не лечатся: зафиксируй и не трать время.
- Перед конвейером: `unset DOCKER_HOST` (битый rootless-сокет) — скрипты делают это сами.

## 6. Проверка статуса патча

```bash
docker run --rm --network none \
  -v "$HOME/apps":/app/apps -v "$HOME/.local/bin":/app/bin \
  safe-ag-patcher:latest status /app/apps/antigravity-ide/resources/bin/language_server /app/bin/agy
```

Ожидается в выводе: `language_server : patched`, `agy : patched`.

## 7. Финальный отчёт (обязательный формат)

1. Версии: `agy --version` и версия IDE (из `docs/REVERSE.md` / манифеста).
2. Статус патча (вывод команды из раздела 6).
3. Какие шаги конвейера прошли / какие коды возврата.
4. Ручные шаги для человека (SUID `chrome-sandbox`, `/etc/hosts` через sudo, вход в аккаунт).
5. Все ошибки и что с ними сделано (ссылка на раздел `docs/ERRORS.md`).