#!/usr/bin/env bash
# 10_sources.sh — подготовка локальных источников (конвейер офлайн; единственный шаг с сетью —
# клон патчера, и только если его ещё нет локально).
#
# Для ИИ-агентов / CI — все пути параметризованы (задаются переменными окружения):
#   AGY_DOWNLOAD_DIR  каталог с уже скачанными архивами (по умолч. $HOME/Downloads)
#   AGY_IDE_ARCHIVE   путь напрямую к архиву IDE (переопределяет поиск в AGY_DOWNLOAD_DIR)
#   AGY_CLI_ARCHIVE   путь напрямую к архиву CLI
#   AGY_PATCHER_URL   URL git-клона патчера (по умолч. официальный GitHub)
#   AGY_PATCHER_DIR   локальная копия патчера на случай недоступного GitHub
# Пример:
#   AGY_IDE_ARCHIVE=/srv/antigravity.tar.gz \
#   AGY_CLI_ARCHIVE=/srv/agy_cli_linux_x64.tar.gz ./scripts/10_sources.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
mkdir -p sources state

log() { echo -e "\n\033[1;34m==>\033[0m $*"; }

DL_DIR="${AGY_DOWNLOAD_DIR:-$HOME/Downloads}"
IDE_ARCHIVE="${AGY_IDE_ARCHIVE:-$DL_DIR/Antigravity(1).tar.gz}"
CLI_ARCHIVE="${AGY_CLI_ARCHIVE:-$DL_DIR/agy_cli_linux_x64.tar.gz}"
PATCHER_URL="${AGY_PATCHER_URL:-https://github.com/AvenCores/open-antigravity-patcher.git}"
PATCHER_DIR="${AGY_PATCHER_DIR:-}"

MISSING=0

# ---------- 1. IDE + CLI архивы ----------
log "Копирую архивы в sources/"
if [ -f "$IDE_ARCHIVE" ]; then
  cp -a "$IDE_ARCHIVE" sources/antigravity.tar.gz
  echo "  IDE: sources/antigravity.tar.gz ($(du -h sources/antigravity.tar.gz | cut -f1))"
else
  echo "  PREF: IDE-архив не найден: $IDE_ARCHIVE"
  MISSING=$((MISSING+1))
fi

if [ -f "$CLI_ARCHIVE" ]; then
  cp -a "$CLI_ARCHIVE" sources/agy_cli_linux_x64.tar.gz
  echo "  CLI: sources/agy_cli_linux_x64.tar.gz ($(du -h sources/agy_cli_linux_x64.tar.gz | cut -f1))"
else
  echo "  PREF: CLI-архив не найден: $CLI_ARCHIVE"
  MISSING=$((MISSING+1))
fi

if [ "$MISSING" -gt 0 ]; then
  echo
  echo "  Как передать архивы: см. docs/SOURCES.md или AGY_IDE_ARCHIVE/AGY_CLI_ARCHIVE."
fi

# ---------- 2. Патчер (локальная копия, коммит фиксируется) ----------
log "Готовлю sources/patcher/ (зафиксированный коммит)"
if [ ! -d sources/patcher/.git ]; then
  echo "  клонирую: $PATCHER_URL"
  if timeout 60 git clone --depth 1 "$PATCHER_URL" sources/patcher 2>/dev/null; then
    echo "  клонирован."
  elif [ -n "$PATCHER_DIR" ] && [ -d "$PATCHER_DIR" ]; then
    mkdir -p sources
    rm -rf sources/patcher
    cp -a "$PATCHER_DIR" sources/patcher
    echo "  GitHub недоступен — скопирован из AGY_PATCHER_DIR: $PATCHER_DIR"
  else
    echo "  PREF: GitHub недоступен и AGY_PATCHER_DIR не задан — патчер не готов."
  fi
else
  echo "  sources/patcher уже существует (pin), оставляю."
fi

# ---------- 3. Фиксация коммита и контрольные суммы ----------
if [ -d sources/patcher/.git ]; then
  git -C sources/patcher rev-parse HEAD > state/patcher.commit
  echo "  патчер commit: $(cat state/patcher.commit)"
else
  echo "  патчер commit: (копия без пина)" | tee state/patcher.commit
fi

log "Контрольные суммы источников -> state/manifest.sha256"
: > state/manifest.sha256
[ -f sources/antigravity.tar.gz ] && sha256sum sources/antigravity.tar.gz >> state/manifest.sha256 || true
[ -f sources/agy_cli_linux_x64.tar.gz ] && sha256sum sources/agy_cli_linux_x64.tar.gz >> state/manifest.sha256 || true
[ -d sources/patcher ] && find sources/patcher -type f -exec sha256sum {} \; >> state/manifest.sha256 || true
echo "PREF: sources готовы:"
ls -1 sources/ 2>/dev/null | head -20
echo "  done."