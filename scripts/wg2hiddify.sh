#!/usr/bin/env bash
# wg2hiddify.sh — конвертация WireGuard .conf (например, от Windscribe)
# в формат wireguard:// для импорта в Hiddify (ядро sing-box).
#
# Использование:
#   bash wg2hiddify.sh /path/to/config.conf
#   → печатает ссылку wireguard://... — вставить её в Hiddify: «+» → из буфера
set -euo pipefail

[ -f "${1:-}" ] || { echo "Укажите файл конфига: bash wg2hiddify.sh <файл.conf>"; exit 1; }
CONF="$1"

# Валидируем, что это wg-quick конфиг
grep -qE '^\s*\[(Interface|Peer)\]' "$CONF" || { echo "Не похоже на WireGuard-конфиг"; exit 1; }
[ -n "$(grep -E '^\s*PrivateKey\s*=' "$CONF")" ] || { echo "Нет PrivateKey в [Interface]"; exit 1; }

# wireguard:// = base64url(конфиг) + #имя
B64=$(base64 -w0 "$CONF" | tr '+/' '-_' | tr -d '=')
NAME=$(basename "$CONF" .conf)

echo "wireguard://${B64}#${NAME}"
echo
echo "Вставьте эту ссылку в Hiddify: «+» → Import from Clipboard"
