#!/usr/bin/env bash
# 90_check_updates.sh — РУЧНОЙ выпуск патчера в интернет для проверки новых версий.
# Запускать ТОЛЬКО осознанно и вручную. Контейнер живёт только на время проверки (--rm),
# после выхода сеть исчезает вместе с контейнером.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
unset DOCKER_HOST 2>/dev/null || true

log() { echo -e "\n\033[1;34m==>\033[0m $*"; }

log "Проверка обновлений патчера на GitHub (контейнер с сетью, разовый)"
docker run --rm \
  --network bridge \
  --cap-drop ALL \
  --security-opt no-new-privileges \
  safe-ag-patcher:latest \
  check-updates

echo ""
echo "  Контейнер удалён (--rm). Для новых версий патчера обнови sources/patcher:"
echo "    git -C sources/patcher pull   (затем ./20_build.sh)"
echo "  Новые версии Antigravity скачиваются вручную -> ./10_sources.sh -> ./30_patch.sh -> ./40_install.sh"