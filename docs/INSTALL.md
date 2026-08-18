# Установка — пошагово

Проверено на **Ubuntu 24.04** (x86-64). Скрипты рассчитывают на системный Docker-демон.

## 0. Предусловия

```bash
# Docker (системный, НЕ rootless) + включение пользователя в группу docker
sudo apt install -y docker.io
sudo usermod -aG docker "$USER"
# выйти и зайти заново (или newgrp docker), чтобы применилась группа docker

# Проверка
docker ps   # должно работать без sudo
```

> 💡 **Грабли с DOCKER_HOST.** Если в окружении прописан `DOCKER_HOST` от rootless-демона
> (например `unix:///run/user/$UID/docker.sock`), а работает системный демон —
> все `docker`-команды будут падать с «no such file or directory». Скрипты делают
> `unset DOCKER_HOST` сами, но при ручном запуске docker тоже убери её:
> ```bash
> unset DOCKER_HOST
> ```

## 1. Получи официальные архивы

Бинари в репозиторий не входят. Скачай сам с официального источника Google:

| Компонент | Ожидаемый файл в `~/Downloads` | Примечание |
|---|---|---|
| IDE Antigravity 2.0 | `Antigravity(1).tar.gz` (~163 МБ) | ресурс `resources/` с `language_server` |
| CLI `agy` | `agy_cli_linux_x64.tar.gz` (~55 МБ) | один бинарь в корне архива |

Если имена отличаются — поправь `scripts/10_sources.sh` (блок «Копирую свежие архивы»).

## 2. Конвейер

Каждый следующий скрипт должен завершиться успешно, прежде чем переходить дальше.

| # | Скрипт | Что делает | Типичный вывод |
|---|---|---|---|
| 0 | `05_check_env.sh` | проверка предусловий: Linux, docker/группа, tar/gzip/git/curl, PATH, наличие архивов | `Предусловия OK` / списки `[FAIL]` |
| 1 | `10_sources.sh` | копирует архивы в `sources/` (пути можно передать через `AGY_IDE_ARCHIVE`/`AGY_CLI_ARCHIVE`), клонирует патчер в порядке **канонический → зеркало → `AGY_PATCHER_DIR`**, пишет sha256 и коммит патчера в `state/` | `sources/... .tar.gz`, `коммит патчера: <sha>` |
| 2 | `20_build.sh` | `docker build` образа **safe-ag-patcher:latest** из локальных `sources/` (патчер копируется в образ, рантайм ничего не качает) | `Successfully tagged safe-ag-patcher:latest` |
| 3 | `30_patch.sh` | распаковывает архивы в `final/`, считает sha256 **до**, запускает патчер в контейнере **`--network none`**, сверяет суммы **после** | `language_server : patched`, `agy : patched`, `RC=0` |
| 4 | `40_install.sh` | ставит IDE в `~/apps/antigravity-ide`, CLI в `~/.local/bin/agy`, создаёт `.desktop`, проверяет статус патча | `ГОТОВО!` + пути |
| 5 | `50_postinstall.sh` | идемпотентная доводка: автоапдейты IDE/CLI выключить, проверить патч, напомнить про SUID | `app-update.yml -> .bak`, `апдейтер CLI заблокирован в /etc/hosts` |

```bash
cd agy   # корень клона репо
bash scripts/05_check_env.sh
bash scripts/10_sources.sh
bash scripts/20_build.sh
bash scripts/30_patch.sh
bash scripts/40_install.sh
bash scripts/50_postinstall.sh
```

> #### Что делать, если 30_patch.sh вернул не-0
> Код возврата контейнера является кодом ошибки:
> `0` — ок; `2` — не пропатчен менеджер IDE; `3` — не пропатчен agy; `4` — оба.
> Самое частое — «байтовая сигнатура не найдена» (вышла новая версия бинарей).
> Тогда нужен **обновлённый патчер** → [`docs/UPDATES.md`](UPDATES.md).

## 3. Ручные шаги (один раз)

Большинство доводок сделает `50_postinstall.sh` (автоапдейты, блокировка апдейтера CLI —
один раз спросит пароль sudo для `/etc/hosts`, проверка патча).
Остаётся только одно ручное действие — **SUID chrome-sandbox**, чтобы IDE запускалась без
root и без `--no-sandbox`:

```bash
sudo chown root:root ~/apps/antigravity-ide/chrome-sandbox && sudo chmod 4755 ~/apps/antigravity-ide/chrome-sandbox
```

Если `~/.local/bin` не в PATH — добавь (разово):

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc && source ~/.bashrc
```

## 4. Вход в аккаунт

1. Открой браузер в **инкогнито** и войди **только в один** Google-аккаунт (тот, у
   которого должна быть лицензия/доступ).
2. Запусти IDE (ярлык **Antigravity**) или CLI: `agy`.
3. Авторизация завершится тем аккаунтом, который в инкогнито. Не перебирай аккаунты —
   каждая попытка плодит OAuth-согласия и риск попасть под флаг Google.

## 5. Финальная проверка

```bash
agy --version                                   # 1.1.13 и выше
docker run --rm --network none \
  -v "$HOME/apps":/app/apps -v "$HOME/.local/bin":/app/bin \
  safe-ag-patcher:latest status /app/apps/antigravity-ide/resources/bin/language_server /app/bin/agy
# → language_server : patched
# → agy             : patched
```

## 6. Чистка и сброс авторизации

- **Снести всё с бекапами** (для аккуратного «с нуля»):
  `bash scripts/00_uninstall.sh`
- **Сбросить авторизацию** (файлы аккаунта + GNOME keyring + кеши CLI + кеш
  `google-vscode-extension`), с бекапом в `~/Backups/`:
  `bash scripts/reset-login.sh`  (или `--full` для полного сброса состояния)