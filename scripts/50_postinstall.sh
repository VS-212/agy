#!/usr/bin/env bash
# 50_postinstall.sh — идемпотентная доводка после 40_install.sh.
# 1) отключает автоапдейт IDE (app-update.yml -> .bak)
# 2) блокирует апдейтер CLI в /etc/hosts (CLI 1.1.13 убрал флаг --update-check,
#    поэтому прежняя функция agy() в ~/.bashrc больше не работает) + миграция:
#    вычищает устаревшую функцию agy() из ~/.bashrc, если она осталась
# 3) проверяет статус патча (offline-контейнер)
# 4) печатает оставшийся ручной шаг (SUID chrome-sandbox)
# Безопасно повторять: ничего не сломает, если уже сделано.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
unset DOCKER_HOST 2>/dev/null || true

H="$HOME"
IDE_DST="$H/apps/antigravity-ide"
CLI_DST="$H/.local/bin/agy"

log() { echo -e "\n\033[1;34m==>\033[0m $*"; }
warn() { echo -e "  \033[33m[warn]\033[0m $*"; }

log "1) Автоапдейт IDE — отключить"
UPD="$IDE_DST/resources/app-update.yml"
if [ -f "$UPD" ]; then
  mv "$UPD" "$UPD.bak"
  echo "  app-update.yml -> .bak (автоапдейт выключен)"
elif [ -f "$UPD.bak" ]; then
  echo "  уже отключено (.bak на месте)"
else
  warn "app-update.yml не найден — IDE не установлена? запусти сначала 40_install.sh"
fi

log "2) Автоапдейт CLI — отключить (блокировка апдейтера в /etc/hosts)"
UPDATER_HOST="antigravity-cli-auto-updater-974169037036.us-central1.run.app"

# 2a) миграция: удалить устаревшую функцию agy() из ~/.bashrc.
# CLI 1.1.13 не поддерживает --update-check: функция валила любой запуск agy
# ("flags provided but not defined: -update-check", exit 2).
if grep -q '^agy()' "$H/.bashrc" 2>/dev/null; then
  cp "$H/.bashrc" "$H/.bashrc.bak-preagy" 2>/dev/null || true
  sed -i \
    -e '/^# Disable agy auto-update (preserve regional patch)$/d' \
    -e '/^agy() { command agy --update-check=false .*}$/d' \
    -e '/^agy() {$/,/^}$/d' \
    "$H/.bashrc"
  echo "  удалена устаревшая функция agy() из ~/.bashrc (ломала запуск в 1.1.13; бекап: ~/.bashrc.bak-preagy)"
else
  echo "  устаревшей функции agy() в ~/.bashrc нет"
fi

# 2b) блокировка сервера обновлений CLI на уровне DNS.
if grep -q "$UPDATER_HOST" /etc/hosts 2>/dev/null; then
  echo "  $UPDATER_HOST уже заблокирован в /etc/hosts"
elif echo "127.0.0.1 $UPDATER_HOST" | sudo tee -a /etc/hosts >/dev/null 2>&1; then
  echo "  заблокирован: 127.0.0.1 $UPDATER_HOST (добавлено в /etc/hosts)"
else
  echo "  ! Не удалось изменить /etc/hosts (нужен sudo). Выполни вручную:"
  echo "    echo '127.0.0.1 $UPDATER_HOST' | sudo tee -a /etc/hosts"
fi

log "3) Статус патча (offline-контейнер)"
set +e
docker run --rm --network none \
  --mount "type=bind,src=$H/apps,dst=/app/apps" \
  --mount "type=bind,src=$H/.local/bin,dst=/app/bin" \
  safe-ag-patcher:latest status \
    /app/apps/antigravity-ide/resources/bin/language_server \
    /app/bin/agy 2>/dev/null | grep -E "language_server|agy"
RC=$?
set -e
if [ "$RC" -ne 0 ]; then
  echo "  (не удалось: может, образ safe-ag-patcher:latest не собран — сначала 20_build.sh)"
fi

log "4) Оставшийся ручной шаг — SUID chrome-sandbox"
if [ -e "$IDE_DST/chrome-sandbox" ]; then
  echo "  sudo chown root:root $IDE_DST/chrome-sandbox && sudo chmod 4755 $IDE_DST/chrome-sandbox"
  echo "  (до этого IDE запускай с флагом --no-sandbox)"
fi

echo
echo "  ГОТОВО. Первый вход — в инкогнито одним аккаунтом."