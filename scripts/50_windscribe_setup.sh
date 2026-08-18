#!/usr/bin/env bash
# 50_windscribe_setup.sh — установка Windscribe (GUI+CLI) из локальных .deb
# и подготовка к подключению через US/UK (для Antigravity/hermes).
#
# Использование:
#   sudo bash 50_windscribe_setup.sh            # установить всё
#   sudo bash 50_windscribe_setup.sh --status   # проверить статус/подключение
#   windscribe login                             # (после установки) войти в аккаунт
#   windscribe connect US                        # подключиться к серверу США
set -euo pipefail

DEB_DIR="${1:-/home/aaa/Downloads}"
GUI_DEB=windscribe_2.23.11_amd64.deb
CLI_DEB=windscribe-cli_2.23.11_amd64.deb

usage() { sed -n '2,8p' "$0" | sed 's/^# \?//'; }

[ "$(id -u)" -eq 0 ] || { echo "Нужны права root: sudo bash $0"; exit 1; }

if [ "${1:-}" = "--status" ] || [ "${2:-}" = "--status" ]; then
  echo "=== windscribe-cli ==="
  windscribe-cli version 2>&1 | head -2 || true
  echo "=== статус ==="
  windscribe-cli status 2>&1 | head -8 || true
  echo "=== интерфейсы ==="
  ip -br link 2>/dev/null | grep -E "wgs|ws" || echo "  (туннеля нет)"
  exit 0
fi

echo "=== 1. Установка .deb из $DEB_DIR ==="
cd "$DEB_DIR"
[ -f "$CLI_DEB" ] || { echo "НЕТ $CLI_DEB в $DEB_DIR"; exit 1; }
[ -f "$GUI_DEB" ] || { echo "НЕТ $GUI_DEB в $DEB_DIR"; exit 1; }

dpkg -i "$CLI_DEB" "$GUI_DEB" 2>&1 | tail -3 || true
echo "=== 2. Доустановка зависимостей (если нужно) ==="
apt-get -f install -y 2>&1 | tail -3

echo "=== 3. Проверка ==="
command -v windscribe-cli || { echo "windscribe-cli не установлен — смотрите вывод выше"; exit 1; }
windscribe-cli version 2>&1 | head -1

echo
echo "=== Готово. Дальше (нужен ваш аккаунт) ==="
echo "  1) Зарегистрируйтесь: https://windscribe.com/signup  (бесплатно, 10 ГБ/мес)"
echo "  2) Вход в CLI:"
echo "       windscribe login"
echo "  3) Подключение к серверу США (для Antigravity):"
echo "       windscribe connect US"
echo "     или список стран:"
echo "       windscribe locations"
echo "     или GUI:  Windscribe  (приложение в меню)"
echo
echo "  Проверка гео:  curl -s https://api.ipify.org ; curl -s http://ip-api.com/json/?fields=country"
