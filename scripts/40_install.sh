#!/usr/bin/env bash
# 40_install.sh — развёртывание пропатченных бинарей на хост.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
unset DOCKER_HOST 2>/dev/null || true

H="$HOME"
IDE_SRC="final/ide"
CLI_SRC="final/cli/antigravity"
IDE_DST="$H/apps/antigravity-ide"
CLI_DST="$H/.local/bin/agy"

log() { echo -e "\n\033[1;34m==>\033[0m $*"; }

[ -d "$IDE_SRC" ] || { echo "НЕТ final/ide — сначала 30_patch.sh"; exit 1; }
[ -f "$CLI_SRC" ] || { echo "НЕТ final/cli/antigravity"; exit 1; }

# ---------- 1. IDE ----------
log "Устанавливаю IDE -> $IDE_DST"
mkdir -p "$H/apps"
rm -rf "$IDE_DST"
mv "$IDE_SRC" "$IDE_DST"
chmod +x "$IDE_DST/antigravity"
echo "  language_server: $IDE_DST/resources/bin/language_server"

# Пропатчен ли менеджер IDE? Сверяем через sandbox-образ (без сети)
set +e
STATUS_MGR=$(docker run --rm --network none \
  --mount "type=bind,src=$H/apps,dst=/app/apps" \
  safe-ag-patcher:latest status "/app/apps/antigravity-ide/resources/bin/language_server" "-" 2>/dev/null | grep language_server || echo "n/a")
set -e
echo "  статус патча: $STATUS_MGR"

# ---------- 2. chrome-sandbox (SUID) ----------
SB=$(find "$IDE_DST" -name chrome-sandbox -type f | head -1)
if [ -n "$SB" ]; then
  log "Настраиваю SUID chrome-sandbox"
  if sudo -n chown root:root "$SB" 2>/dev/null && sudo -n chmod 4755 "$SB" 2>/dev/null; then
    echo "  ok: $SB (root:root, 4755)"
  else
    echo "  sudo недоступен без пароля. Чтобы IDE работала без root, выполни вручную:"
    echo "    sudo chown root:root \"$SB\" && sudo chmod 4755 \"$SB\""
    echo "  Либо запускай IDE с флагом --no-sandbox."
  fi
else
  echo "  chrome-sandbox не найден (не критично)."
fi

# ---------- 3. CLI ----------
log "Устанавливаю CLI -> $CLI_DST"
mkdir -p "$H/.local/bin"
install -m 0755 "$CLI_SRC" "$CLI_DST"
echo "  agy: $CLI_DST ($(du -h "$CLI_DST" | cut -f1))"

# Пропатчен ли CLI? Сверяем через sandbox-образ (без сети)
set +e
STATUS_CLI=$(docker run --rm --network none \
  --mount "type=bind,src=$H/.local/bin,dst=/app/bin" \
  safe-ag-patcher:latest status "-" "/app/bin/agy" 2>/dev/null | grep agy || echo "n/a")
set -e
echo "  статус CLI:   $STATUS_CLI"

# ---------- 4. .desktop-ярлык ----------
log "Создаю .desktop-ярлык"
mkdir -p "$H/.local/share/applications"
cat > "$H/.local/share/applications/antigravity-ide.desktop" <<EOF
[Desktop Entry]
Name=Antigravity
Comment=Antigravity IDE (regional patch)
Exec=$IDE_DST/antigravity %F
Type=Application
Terminal=false
Categories=Development;IDE;
StartupWMClass=antigravity
EOF
echo "  $H/.local/share/applications/antigravity-ide.desktop"

# ---------- 5. PATH-подсказка ----------
case ":$PATH:" in
  *":$H/.local/bin:"*) : ;;
  *) echo "  подсказка: $H/.local/bin не в PATH — добавь в ~/.bashrc: export PATH=\"\$HOME/.local/bin:\$PATH\"" ;;
esac

echo ""
echo "=========================================="
echo "  ГОТОВО!"
echo "  IDE: $IDE_DST/antigravity"
echo "  CLI: $CLI_DST (команда: agy)"
echo "  Ярлык: Antigravity (в меню приложений)"
echo "=========================================="