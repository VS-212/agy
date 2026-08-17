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
(`AGY_PATCHER_URL`, `AGY_PATCHER_MIRROR_URL`, `AGY_PATCHER_DIR`) — см. шапку
`scripts/10_sources.sh`.

## Зеркало патчера (fallback)

Патчер — внешняя GPL-зависимость всего конвейера и его главный SPOF. Для робастности мы
держим **форк-снапшот** под своим контролем:

`https://github.com/VS-212/open-antigravity-patcher-mirror`
(HEAD на момент создания — `fed74634…`, тот же коммит, что задеплоен в этом гайде).

`10_sources.sh` берёт патчер в таком порядке:

1. **канонический источник** — `AvenCores/open-antigravity-patcher` (свежие сигнатуры);
2. **зеркало** — `VS-212/open-antigravity-patcher-mirror` (fallback, если канонический
   недоступен/деопубликован);
3. **локальная копия** — `AGY_PATCHER_DIR` (полный офлайн).

> ⚠️ Зеркало — это **снапшот**, а не автосинк. Форки GitHub переживают удаление родителя.
> Когда осознанно переходишь на новую проверенную пару «Antigravity + патчер», синкай
> зеркало вручную одним движением:
> ```bash
> git clone --bare https://github.com/VS-212/open-antigravity-patcher-mirror.git /tmp/m
> cd /tmp/m && git fetch origin '+refs/heads/*:refs/heads/*' && git push --mirror https://github.com/VS-212/open-antigravity-patcher-mirror.git
> ```
> Или через GitHub UI — «Fork → Sync fork → Update branch». Автосинка нет намеренно:
> новый upstream-коммит не должен «втихую» менять детерминированный деплой.

## Проверка целостности

После `10_sources.sh` контрольные суммы всех источников пишутся в `state/manifest.sha256`
(используются для сверки `before/after` на этапе 30_patch.sh).

## Проверка актуальности CLI

Апдейтер подтверждает текущую стабильную версию (на момент написания — **1.1.13**):

```bash
curl -s https://antigravity-cli-auto-updater-974169037036.us-central1.run.app
# → Antigravity CLI auto updater is running! Stable Version: 1.1.13. Rolled out to 100%
```