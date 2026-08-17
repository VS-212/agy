# Источники архивов (официальные)

Проприетарные бинари Google в репозиторий **не входят** — их скачивает пользователь или
агент заранее. Ниже — зафиксированные официальные точки и как передать архивы в конвейер.

## Официальные сервисы (проверены на дату написания)

| Сервис | URL | Назначение |
|---|---|---|
| **Апдейтер CLI** | `https://antigravity-cli-auto-updater-974169037036.us-central1.run.app` | Отвечает текущей stable-версией: `Antigravity CLI auto updater is running! Stable Version: 1.1.13. Rolled out to 100%` |
| **Манифест обновлений IDE** | `https://antigravity-hub-auto-updater-974169037036.us-central1.run.app/manifest/` | Используется в `app-update.yml` самого приложения |

> Прямой стабильной публичной ссылки на tar-архивы апдейтеры не отдают (протокол службы
> версий работает изнутри приложения). Поэтому архивы берутся либо из готового даунлоада
> (как в нашем случае — `Antigravity(1).tar.gz` и `agy_cli_linux_x64.tar.gz`), либо через
> официальный сайт / первый запуск проверки обновлений продукта.

## Как передать архивы в конвейер

### Вариант А: файлы в `~/Downloads` (по умолчанию)

```bash
~$ ls -lh ~/Downloads/Antigravity\(1\).tar.gz ~/Downloads/agy_cli_linux_x64.tar.gz
```

| Файл | Размер | Компонент |
|---|---|---|
| `Antigravity(1).tar.gz` | ~160 МБ | IDE 2.0 (`resources/` c `language_server`) |
| `agy_cli_linux_x64.tar.gz` | ~55 МБ | CLI (бинарь в корне архива) |

Далее — обычный конвейер (`10_sources.sh` найдёт их сам).

### Вариант Б: произвольные пути (для ИИ-агентов/CI)

```bash
AGY_IDE_ARCHIVE=/srv/artifacts/antigravity.tar.gz \
AGY_CLI_ARCHIVE=/srv/artifacts/agy.tar.gz \
bash scripts/10_sources.sh
```

Также можно переопределить каталог поиска (`AGY_DOWNLOAD_DIR`) и URL/копию патчера
(`AGY_PATCHER_URL`, `AGY_PATCHER_DIR`) — см. шапку `scripts/10_sources.sh`.

## Проверка целостности

После `10_sources.sh` контрольные суммы всех источников пишутся в `state/manifest.sha256`
(используются для сверки `before/after` на этапе 30_patch.sh).

## Проверка актуальности CLI

Апдейтер подтверждает текущую стабильную версию (на момент написания — **1.1.13**):

```bash
curl -s https://antigravity-cli-auto-updater-974169037036.us-central1.run.app
# → Antigravity CLI auto updater is running! Stable Version: 1.1.13. Rolled out to 100%
```