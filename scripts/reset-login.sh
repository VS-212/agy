#!/usr/bin/env bash
# reset-login.sh — сброс авторизации/кешей Antigravity для перелогина.
#
# Использование:
#   bash reset-login.sh          # сброс аккаунта+токенов+кешей CLI (история и проекты сохраняются)
#   bash reset-login.sh --full   # + installation_id, состояние и кеши IDE-приложения
#
# Перед удалением всё бэкапится в ~/Backups/reset-login-<дата>/ .
set -euo pipefail

H="$HOME"
STAMP="$(date +%Y%m%d-%H%M%S)"
BK="$H/Backups/reset-login-$STAMP"
FULL="${1:-}"
mkdir -p "$BK"

echo "==> Останавливаю запущенные процессы Antigravity/CLI"
for p in agy language_server antigravity; do
  pkill -x "$p" 2>/dev/null && echo "    остановлен: $p" || true
done
sleep 1

echo "==> Бекап в $BK"
echo "==> 1) Авторизация (аккаунт + OAuth) — при следующем запуске будет запрошен логин"
for f in "$H/.gemini/google_accounts.json" "$H/.gemini/oauth_creds.json"; do
  if [ -f "$f" ]; then
    cp -a "$f" "$BK/" && rm -f "$f"
    echo "    сброшено: ${f#$H/}"
  fi
done

echo "==> 2) Кеши CLI"
if [ -d "$H/.gemini/antigravity-cli/cache" ]; then
  mv "$H/.gemini/antigravity-cli/cache" "$BK/cli-cache"
  echo "    кеш CLI убран в бекап"
fi

echo "==> 3) Токен в GNOME keyring (libsecret, service=gemini)"
if python3 -c "import gi; gi.require_version('Secret', '1')" 2>/dev/null; then
  python3 - <<'PYEOF'
import gi
gi.require_version("Secret", "1")
from gi.repository import Secret
schema = Secret.Schema.new(
    "org.freedesktop.Secret.Generic",
    Secret.SchemaFlags.NONE,
    {"service": Secret.SchemaAttributeType.STRING,
     "username": Secret.SchemaAttributeType.STRING},
)
r = Secret.password_clear_sync(schema, {"service": "gemini", "username": "antigravity"})
print(("    keyring: токен Antigravity удалён" if r else "    keyring: записи не найдено"))
PYEOF
else
  echo "    PyGObject/keyring недоступен — токен удали вручную:"
  echo "      sudo apt install libsecret-tools"
  echo "      secret-tool clear --service=gemini --username=antigravity"
fi

echo "==> 4) Кеш авторизации Google-инструментов (используется Antigravity as data source)"
if [ -d "$H/.cache/google-vscode-extension/auth" ]; then
  mv "$H/.cache/google-vscode-extension/auth" "$BK/google-vscode-extension-auth"
  echo "    перемещено в бекап: .cache/google-vscode-extension/auth (аккаунт gibk.sky@gmail.com)"
fi

if [ "$FULL" = "--full" ]; then
  echo "==> 5) Полный сброс: installation_id + состояние/кеши IDE-приложения"
  for f in \
    "$H/.gemini/installation_id" \
    "$H/.gemini/antigravity/installation_id" \
    "$H/.gemini/antigravity-cli/installation_id"; do
    if [ -f "$f" ]; then
      cp -a "$f" "$BK/" && rm -f "$f"
      echo "    сброшен: ${f#$H/}"
    fi
  done
  if [ -f "$H/.gemini/antigravity/antigravity_state.pbtxt" ]; then
    cp -a "$H/.gemini/antigravity/antigravity_state.pbtxt" "$BK/"
    rm -f "$H/.gemini/antigravity/antigravity_state.pbtxt"
    echo "    сброшено: .gemini/antigravity/antigravity_state.pbtxt"
  fi
  if [ -d "$H/.config/Antigravity" ]; then
    mv "$H/.config/Antigravity" "$BK/config-Antigravity"
    echo "    сброшено: .config/Antigravity"
  fi
  if [ -d "$H/.cache/antigravity" ]; then
    mv "$H/.cache/antigravity" "$BK/cache-antigravity"
    echo "    сброшено: .cache/antigravity"
  fi
fi

echo
echo "==> Готово. Бекап: $BK"
echo "    При следующем запуске agy / IDE Antigravity будет запрошен вход в аккаунт."
echo "    Запуск:  agy   |   ~/apps/antigravity-ide/antigravity"