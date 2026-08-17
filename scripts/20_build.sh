#!/usr/bin/env bash
# 20_build.sh — сборка sandbox-образа safe-ag-patcher из ЛОКАЛЬНЫХ источников.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
unset DOCKER_HOST 2>/dev/null || true

log() { echo -e "\n\033[1;34m==>\033[0m $*"; }
[ -d sources/patcher ] || { echo "НЕТ sources/patcher — сначала 10_sources.sh"; exit 1; }

log "Сборка образа safe-ag-patcher:latest"
docker build -f build/Dockerfile -t safe-ag-patcher:latest .
docker image inspect safe-ag-patcher:latest --format '{{.Id}}' > state/image.id
echo "  image id: $(cat state/image.id)"
echo "  done."