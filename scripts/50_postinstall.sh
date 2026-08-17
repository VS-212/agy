#!/usr/bin/env bash
# 50_postinstall.sh — идемпотентная доводка после 40_install.sh.
# 1) отключает автоапдейт IDE (app-update.yml -> .bak)
# 2) добавляет в ~/.bashrc функцию agy() с --update-check=false (автоапдейт CLI)
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

log "2) Автоапдейт CLI — отключить (функция agy в ~/.bashrc)"
if grep -q '^agy()' "$H/.bashrc" 2>/dev/null; then
  echo "  функция agy уже есть — пропускаю"
else
  printf '\n# Disable agy auto-update (preserve regional patch)\nagy() { command agy --update-check=false "$@"; }\n' >> "$H/.bashrc"
  echo "  добавлено в ~/.bashrc (применится в новых терминалах / после source ~/.bashrc)"
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