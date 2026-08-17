#!/usr/bin/env bash
# 10_sources.sh — подготовка локальных источников (всё офлайн, кроме клона патчера при необходимости).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
mkdir -p sources state

log() { echo -e "\n\033[1;34m==>\033[0m $*"; }

# ---------- 1. IDE + CLI архивы ----------
log "Копирую свежие архивы в sources/"
if [ -f "$HOME/Downloads/Antigravity(1).tar.gz" ]; then
  cp "$HOME/Downloads/Antigravity(1).tar.gz" sources/antigravity.tar.gz
  echo "  sources/antigravity.tar.gz  ($(du -h sources/antigravity.tar.gz | cut -f1))"
else
  echo "  PREF: Sources/Antigravity(1).tar.gz не найден"
fi
if [ -f "$HOME/Downloads/agy_cli_linux_x64.tar.gz" ]; then
  cp "$HOME/Downloads/agy_cli_linux_x64.tar.gz" sources/agy_cli_linux_x64.tar.gz
  echo "  sources/agy_cli_linux_x64.tar.gz  ($(du -h sources/agy_cli_linux_x64.tar.gz | cut -f1))"
else
  echo "  PREF: agy_cli_linux_x64.tar.gz не найден"
fi

# ---------- 2. Патчер (локальная копия, коммит фиксируется) ----------
log "Готовлю sources/patcher/ (зафиксированный коммит)"
if [ ! -d sources/patcher/.git ]; then
  echo "  пробую свежий clone (если GitHub доступен)..."
  if timeout 30 git clone --depth 1 https://github.com/AvenCores/open-antigravity-patcher.git sources/patcher 2>/dev/null; then
    echo "  клонирован."
  else
    echo "  GitHub недоступен — использую резервную копию из patcher-local."
    mkdir -p sources
    [ -d sources/patcher ] && rm -rf sources/patcher
    # патчер-local был перемещён в Backups/ag-userdata-*/ag_setup-old/patcher-local на этапе 00
    SRCP=$(ls -d "$HOME"/Backups/ag-userdata-*/ag_setup-old/patcher-local 2>/dev/null | tail -1 || true)
    if [ -n "$SRCP" ] && [ -d "$SRCP" ]; then
      cp -a "$SRCP" sources/patcher
      echo "  скопирован из: $SRCP"
    elif [ -d "$HOME/ag_setup/patcher-local" ]; then
      cp -a "$HOME/ag_setup/patcher-local" sources/patcher
      echo "  скопирован из: ~/ag_setup/patcher-local"
    else
      echo "  PREF: источник патчера не найден!"
    fi
  fi
else
  echo "  sources/patcher уже существует — обновляю нельзя (пин), оставляю."
fi

# ---------- 3. Фиксация коммита и контрольные суммы ----------
if [ -d sources/patcher/.git ]; then
  git -C sources/patcher rev-parse HEAD > state/patcher.commit
  echo "  патчер commit: $(cat state/patcher.commit)"
else
  echo "  патчер commit: (без .git, копия без пина)" | tee state/patcher.commit
fi

log "Контрольные суммы источников -> state/manifest.sha256"
sha256sum sources/antigravity.tar.gz sources/agy_cli_linux_x64.tar.gz > state/manifest.sha256
[ -d sources/patcher ] && find sources/patcher -type f -exec sha256sum {} \; >> state/manifest.sha256 || true
echo "PREF: sources готовы:"
ls -1 sources/ sources/patcher/source 2>/dev/null | head -30
echo "  done."