#!/usr/bin/env bash
# 00_uninstall.sh — полная зачистка всех Antigravity/Slai остатков с бекапами.
# Пользовательские данные (~/.gemini) НЕ трогаются (их переиспользует новый CLI).
set -uo pipefail

H="${HOME:?}"
STAMP="$(date +%Y%m%d-%H%M%S)"
BK="$H/Backups/ag-userdata-$STAMP"
mkdir -p "$BK"

log() { echo -e "\n\033[1;34m==>\033[0m $*"; }

# ---------- 1. Остановка процессов ----------
log "Останавливаю процессы Antigravity (если запущены)"
for p in antigravity agy language_server; do
  pkill -x "$p" 2>/dev/null && echo "  остановлен: $p" || true
done
sleep 1

# ---------- 2. Бекапы ----------
if [ -e "$H/Antigravity" ]; then
  log "Бекап ~/Antigravity -> $BK/Antigravity-home/"
  cp -a "$H/Antigravity" "$BK/Antigravity-home/"
fi

if [ -f "$H/Downloads/Antigravity.tar.gz" ]; then
  log "Старый майский архив -> $BK/"
  mv "$H/Downloads/Antigravity.tar.gz" "$BK/Antigravity-old-may-2026.tar.gz"
fi

# ---------- 3. Удаление остатков ----------
log "Удаляю настройки/кеши/бинари Antigravity (Slai-эра и старые)"
RM=(
  "$H/.config/Antigravity"
  "$H/.cache/antigravity"
  "$H/.local/bin/agy"
  "$H/Downloads/Antigravity"
  "$H/Downloads/Antigravity(1)"
)
for p in "${RM[@]}"; do
  if [ -e "$p" ]; then rm -rf "$p"; echo "  удалено: $p"; fi
done

# ---------- 4. Старые артефакты прошлой автоматизации ----------
log "Перемещаю старые скрипты автоматизации в $BK/ag_setup-old/"
mkdir -p "$BK/ag_setup-old"
for f in install-clean.sh Dockerfile cli-src ide-src patcher-local; do
  [ -e "$H/ag_setup/$f" ] && mv "$H/ag_setup/$f" "$BK/ag_setup-old/$f" && echo "  перемещено: $f"
done
# final/ будет пересоздан заново при 30_patch.sh
if [ -e "$H/ag_setup/final" ]; then rm -rf "$H/ag_setup/final"; echo "  удалено: final/ (будет восстановлено)"; fi

# ---------- 5. Старые Docker-образы ----------
log "Удаляю старые sandbox-образы (пересоберём свежий)"
docker rmi --force safe-ag-env safe-ag-final safe-ag-local 2>/dev/null \
  && echo "  удалены старые образы safe-ag-*" || echo "  (образов safe-ag-* не было)"
docker rmi python:3.9-slim 2>/dev/null && echo "  удален python:3.9-slim" || true

# ---------- 6. Контроль ----------
log "Контроль после зачистки (должно быть пусто)"
LEFT=$(find "$H" -maxdepth 4 \( -iname "*antigravity*" -o -iname "*slai*" \) \
   -not -path "$H/Backups/*" -not -path "$H/ag_setup/sources/*" 2>/dev/null | grep -vE "^$H/ag_setup$" || true)
if [ -n "$LEFT" ]; then echo "  осталось:"; echo "$LEFT" | sed 's/^/    /'; fi
echo "  ~/.gemini: $(test -d "$H/.gemini" && echo 'сохранён (не удаляем)' || echo 'отсутствует')"
echo "  бэкапы: $BK"
echo "  done."