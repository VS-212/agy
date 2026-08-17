#!/usr/bin/env bash
# 05_check_env.sh — проверка предусловий перед конвейером (лучше запускать до 10_sources.sh).
# Выход:
#   0 — всё критичное есть (могут быть предупреждения)
#   1 — есть критично пропущенные предусловия (docker/даемон/tar/gzip)
set -uo pipefail

log() { echo -e "\n\033[1;36m==>\033[0m $*"; }
ok()   { echo "  [ok]    $*"; }
warn() { echo "  [warn]  $*"; }
fail() { echo "  [FAIL]  $*"; FAILS=$((FAILS+1)); }
FAILS=0

log "ОС/архитектура"
case "$(uname -s)-$(uname -m)" in
  Linux-x86_64) ok "Linux x86_64 — поддерживаемая комбинация" ;;
  Linux-aarch64) warn "Linux aarch64: патчер заявляет ARM64-поддержку, но архивы слова могут отличаться" ;;
  *) fail "ОС/архитектура: $(uname -s)-$(uname -m) (ожидается Linux x86_64)" ;;
esac

log "Docker"
if command -v docker >/dev/null 2>&1; then
  ok "docker CLI: $(docker --version 2>/dev/null | cut -d, -f1)"
else
  fail "нет docker CLI — установи: sudo apt install docker.io"
fi
if [ -n "${DOCKER_HOST:-}" ]; then
  warn "DOCKER_HOST задан (${DOCKER_HOST}) — конвейер сам делает unset, но убедись, что системный демон работает (docker ps)"
fi
if unset DOCKER_HOST; docker info >/dev/null 2>&1; then
  ok "демон docker доступен (group 'docker' настроена)"
else
  fail "docker info не проходит — проверь демон и группу: sudo usermod -aG docker \$USER (выход/вход)"
fi

log "Инструменты"
for t in tar gzip git curl; do
  command -v "$t" >/dev/null 2>&1 && ok "$t: присутствует" || fail "$t: не найден"
done
if command -v python3 >/dev/null 2>&1 && python3 -c "import gi; gi.require_version('Secret','1')" 2>/dev/null; then
  ok "python3 + libsecret (нужен reset-login.sh)"
else
  warn "python3/PyGObject Secret нет — reset-login.sh пропустит очистку GNOME keyring (поставит: sudo apt install python3-gi)"
fi

log "Размещение"
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ok "\$HOME/.local/bin уже в PATH" ;;
  *) warn "\$HOME/.local/bin не в PATH — добавь: export PATH=\"\$HOME/.local/bin:\$PATH\" (в ~/.bashrc)" ;;
esac
if [ -f "$HOME/apps/antigravity-ide/antigravity" ] || [ -f "$HOME/.local/bin/agy" ]; then
  warn "обнаружена существующая установка — 40_install.sh заменит её (бекапы только бэкапит 00_uninstall.sh)"
fi
[ -f "$HOME/Downloads/Antigravity(1).tar.gz" ] && ok "архив IDE в ~/Downloads" || warn "архива IDE в ~/Downloads нет — см. docs/SOURCES.md или AGY_IDE_ARCHIVE"
[ -f "$HOME/Downloads/agy_cli_linux_x64.tar.gz" ] && ok "архив CLI в ~/Downloads" || warn "архива CLI в ~/Downloads нет — см. docs/SOURCES.md или AGY_CLI_ARCHIVE"

echo
if [ "$FAILS" -gt 0 ]; then
  echo "  Найдено критичных проблем: $FAILS — исправь их и перезапусти."
else
  echo "  Предусловия OK (возможны предупреждения выше — на конвейер не влияют)."
fi
echo "done."
exit "$([ "$FAILS" -gt 0 ] && echo 1 || echo 0)"