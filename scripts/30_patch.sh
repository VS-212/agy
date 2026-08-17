#!/usr/bin/env bash
# 30_patch.sh — распаковка свежих архивов и ПАТЧИНГ В КОНТЕЙНЕРЕ БЕЗ СЕТИ.
# Патчер физически не имеет доступа в интернет (--network none).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
unset DOCKER_HOST 2>/dev/null || true
mkdir -p final/ide final/cli state/logs

IMGH="safe-ag-patcher:latest"
MGR_REL="ide/resources/bin/language_server"
CLI_REL="cli/antigravity"

log() { echo -e "\n\033[1;34m==>\033[0m $*"; }

[ -f sources/antigravity.tar.gz ] || { echo "НЕТ sources/antigravity.tar.gz"; exit 1; }
[ -f sources/agy_cli_linux_x64.tar.gz ] || { echo "НЕТ sources/agy_cli_linux_x64.tar.gz"; exit 1; }
docker image inspect "$IMGH" >/dev/null 2>&1 || { echo "НЕТ образа — сначала 20_build.sh"; exit 1; }

# ---------- 1. Распаковка ----------
log "Распаковка IDE (Antigravity 2.0) в final/ide/"
rm -rf final/ide && mkdir -p final/ide
tar -xzf sources/antigravity.tar.gz -C final/ide --strip-components=1
echo "  IDE распакована, resources/bin/language_server: $(test -f "final/$MGR_REL" && echo есть || echo НЕТ)"

log "Распаковка CLI в final/cli/"
rm -rf final/cli && mkdir -p final/cli
# Тар без вложенной папки (в корне лежит сам бинарь) — strip не нужен
tar -xzf sources/agy_cli_linux_x64.tar.gz -C final/cli
# Страховка на случай будущих архивов с вложенной папкой:
if [ ! -f "final/$CLI_REL" ]; then
  sub=$(find final/cli -mindepth 1 -maxdepth 1 -type d | head -1)
  [ -n "$sub" ] && mv "$sub"/* final/cli/ && rmdir "$sub" 2>/dev/null || true
fi
chmod +x "final/$CLI_REL" 2>/dev/null || true
echo "  CLI бинарь: $(test -f "final/$CLI_REL" && echo есть || echo НЕТ)"

# ---------- 2. Контрольные суммы ДО ----------
log "sha256 до патча -> state/checksums.before"
sha256sum "final/$MGR_REL" "final/$CLI_REL" > state/checksums.before
cat state/checksums.before

# ---------- 3. Запуск патчера (НЕТ СЕТИ) ----------
LOG="state/logs/patch-$(date +%Y%m%d-%H%M%S).log"
log "Запуск патчера в контейнере (--network none). Лог: $LOG"
set +e
docker run --rm \
  --network none \
  --cap-drop ALL \
  --security-opt no-new-privileges \
  --mount "type=bind,src=$PWD/final,dst=/app/target" \
  --mount "type=bind,src=$PWD/state,dst=/app/state" \
  "$IMGH" \
  patch-all "/app/target/$MGR_REL" "/app/target/$CLI_REL" 2>&1 | tee "$LOG"
RC="${PIPESTATUS[0]}"
set -e

# RC: 0=ok, 2=manager failed, 3=agy failed, 4=оба (см. driver.py)
echo ""
echo "  exit code контейнера: $RC (0=ok, 2=manager-fail, 3=agy-fail, 4=both)"

# ---------- 4. Контрольные суммы ПОСЛЕ ----------
log "sha256 после патча -> state/checksums.after"
sha256sum "final/$MGR_REL" "final/$CLI_REL" > state/checksums.after
diff <(sed 's/ \*.*//' state/checksums.before ) <(sed 's/ \*.*//' state/checksums.after ) \
  >/dev/null && echo "  ВНИМАНИЕ: контрольные суммы не изменились — патча не было?" || echo "  Контрольные суммы изменены (патч применён)."

log "Бекапы патчера (должны появиться рядом с целями):"
ls -la final/ide/resources/bin/*.agybak final/cli/*.agybak 2>/dev/null || echo "  (.agybak не найдены)"

echo ""
echo "  Итог: RC=$RC"
echo "  Продолжение: ./40_install.sh"
exit "$RC"