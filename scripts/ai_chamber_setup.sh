#!/usr/bin/env bash
#
# ai_chamber_setup.sh — изолированная сетевая комната (netns) для агентов
# (agy / hermes / kg) через Smart DNS (Xbox DNS).
#
# Что делает:
#   * создаёт netns ai_chamber с veth-парой и NAT через uplink
#   * DNS комнаты → Xbox DNS (111.88.96.50 / .51) — файл /etc/netns/ai_chamber/resolv.conf
#   * полностью отключает IPv6 внутри комнаты (защита от AAAA-утечки Smart DNS)
#   * БЛОКИРУЕТ (FORWARD) любой чужой DNS-трафик из комнаты наружу —
#     разрешены только наши DNS-резолверы (защита от утечек на 8.8.8.8 и пр.)
#   * самопроверка резолвинга ключевых гео-доменов
#
# Использование:
#   sudo bash ai_chamber_setup.sh            # создать/пересоздать комнату
#   sudo bash ai_chamber_setup.sh --systemd  # то же + автозапуск при загрузке
#   sudo bash ai_chamber_setup.sh --purge    # удалить комнату и все правила
#
set -euo pipefail

NS=ai_chamber            # имя netns
VHOST=veth-agx            # veth на стороне хоста
VNS=veth-agy              # veth внутри комнаты
HOST_CIDR=10.77.0.1/30
NS_CIDR=10.77.0.2/30
NET=10.77.0.0/30
DNS1=111.88.96.50         # Xbox DNS primary  (Smart DNS)
DNS2=111.88.96.51         # Xbox DNS secondary
CHAIN=AI_CHAMBER_DNS      # iptables-цепочка «блок чужих DNS»
UNIT_SCRIPT=/home/aaa/ai_chamber_setup.sh

usage() {
  sed -n '2,15p' "$0" | sed 's/^# \?//'
}

MODE=create
SYSTEMD=0
for arg in "$@"; do
  case "$arg" in
    --purge)   MODE=purge ;;
    --systemd) SYSTEMD=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Неизвестный аргумент: $arg"; usage; exit 1 ;;
  esac
done

# ---------- проверки окружения ----------
[ "$(id -u)" -eq 0 ] || { echo "Нужны права root: sudo bash $0 $*"; exit 1; }
for tool in ip iptables sysctl awk timeout; do
  command -v "$tool" >/dev/null 2>&1 || { echo "Нет утилиты: $tool"; exit 1; }
done
if command -v dig >/dev/null 2>&1; then DIG=1; else
  DIG=0
  echo "⚠ нет dig (dnsutils) — самопроверка резолвинга будет пропущена"
  echo "  (sudo apt install -y dnsutils)"
fi

UPLINK=$(ip route show default | awk '{print $5; exit}')
[ -n "$UPLINK" ] || { echo "Не найден интерфейс в интернет (default route)"; exit 1; }
echo "🌐 Uplink интерфейс: $UPLINK"

# ---------- teardown (используется и при --purge, и перед пересозданием) ----------
teardown() {
  iptables -D FORWARD -s "$NET" -j "$CHAIN" 2>/dev/null || true
  iptables -F "$CHAIN" 2>/dev/null || true
  iptables -X "$CHAIN" 2>/dev/null || true
  iptables -t nat -D POSTROUTING -s "$NET" -o "$UPLINK" -j MASQUERADE 2>/dev/null || true
  ip link del "$VHOST" 2>/dev/null || true
  ip netns del "$NS" 2>/dev/null || true
  rm -f "/etc/netns/$NS/resolv.conf" 2>/dev/null || true
  [ -d "/etc/netns/$NS" ] && rmdir "/etc/netns/$NS" 2>/dev/null || true
}

# ---------- purge ----------
if [ "$MODE" = purge ]; then
  teardown
  if [ -f /etc/systemd/system/ai-chamber.service ]; then
    systemctl disable --now ai-chamber 2>/dev/null || true
    rm -f /etc/systemd/system/ai-chamber.service
    systemctl daemon-reload
    echo "systemd-сервис ai-chamber удалён"
  fi
  echo "🗑   Комната $NS и все правила удалены"
  exit 0
fi

# аварийная очистка при ошибке во время создания
cleanup() { echo "‼ Ошибка на шаге $? — откатываю изменения"; teardown; }
trap cleanup ERR

# ---------- 1. чистый старт ----------
teardown
ip netns add "$NS"

# ---------- 2. veth-пара ----------
ip link add "$VHOST" type veth peer name "$VNS"
ip link set "$VNS" netns "$NS"
ip addr add "$HOST_CIDR" dev "$VHOST"
ip link set "$VHOST" up
ip netns exec "$NS" ip addr add "$NS_CIDR" dev "$VNS"
ip netns exec "$NS" ip link set "$VNS" up
ip netns exec "$NS" ip link set lo up

# ---------- 3. маршрут + NAT ----------
ip netns exec "$NS" ip route add default via 10.77.0.1
sysctl -w net.ipv4.ip_forward=1 >/dev/null
iptables -t nat -C POSTROUTING -s "$NET" -o "$UPLINK" -j MASQUERADE 2>/dev/null || \
  iptables -t nat -A POSTROUTING -s "$NET" -o "$UPLINK" -j MASQUERADE

# ---------- 4. IPv6 внутри комнаты выключаем полностью ----------
ip netns exec "$NS" sysctl -w net.ipv6.conf.all.disable_ipv6=1    >/dev/null
ip netns exec "$NS" sysctl -w net.ipv6.conf.default.disable_ipv6=1 >/dev/null
ip netns exec "$NS" sysctl -w net.ipv6.conf."$VNS".disable_ipv6=1  >/dev/null

# ---------- 5. DNS комнаты ----------
mkdir -p /etc/netns/"$NS"
cat > "/etc/netns/$NS/resolv.conf" <<EOF
nameserver $DNS1
nameserver $DNS2
options rotate timeout:2 attempts:2
EOF
chmod 644 "/etc/netns/$NS/resolv.conf"

# ---------- 6. Блокировка «чужих» DNS из комнаты ----------
# ДНС-запросы из комнаты наружу разрешены ТОЛЬКО на наши резолверы.
iptables -N "$CHAIN" 2>/dev/null || iptables -F "$CHAIN"
iptables -A "$CHAIN" -p udp -d "$DNS1" -j ACCEPT
iptables -A "$CHAIN" -p udp -d "$DNS2" -j ACCEPT
iptables -A "$CHAIN" -p udp -j DROP
iptables -A "$CHAIN" -p tcp -d "$DNS1" -j ACCEPT
iptables -A "$CHAIN" -p tcp -d "$DNS2" -j ACCEPT
iptables -A "$CHAIN" -p tcp -j DROP
iptables -C FORWARD -s "$NET" -j "$CHAIN" 2>/dev/null || \
  iptables -I FORWARD 1 -s "$NET" -j "$CHAIN"

trap - ERR

# ---------- 7. проверка ----------
echo
echo "════════ Проверка комнаты $NS ════════"
ip netns exec "$NS" bash -c '
  echo "--- /etc/resolv.conf комнаты:"
  cat /etc/resolv.conf
  echo
  if dig -h >/dev/null 2>&1; then
    for d in cloudcode-pa.googleapis.com daily-cloudcode-pa.googleapis.com \
             generativelanguage.googleapis.com api.anthropic.com api.openai.com \
             oauth2.googleapis.com; do
      a=$(dig +short +time=2 +tries=1 A "$d" | tr "\n" " " | sed "s/ $//")
      printf "%-42s -> %s\n" "$d" "${a:-NODATA}"
    done
    who=$(dig +short +time=2 +tries=1 whoami.ds.akahelp.net | tr "\n" " ")
    echo "путь резолвера (whoami): ${who:-—}"
  fi
'
echo
echo "--- TCP до прокси-пула 87.228.47.204:443 (гео-обход):"
if timeout 5 bash -c "</dev/tcp/87.228.47.204/443" 2>/dev/null; then
  echo "  TCP OK"
else
  echo "  TCP FAIL (возможно, пул сменился)"
fi
echo "--- IPv6 внутри комнаты: $(ip netns exec "$NS" sysctl -n net.ipv6.conf.all.disable_ipv6)"
echo "--- DNS-блокировка активна (цепочка $CHAIN): $(iptables -L FORWARD -n | grep -c "$CHAIN") правило"
echo
echo "Комната готова. Вход:"
echo "  sudo ip netns exec $NS bash"
echo "  или алиас ai-room / ai-env / ai-agy / ai-hermes / ai-kg (из вашего .bashrc)"

[ "$SYSTEMD" = 1 ] || exit 0

# ---------- 8. (опционально) автозапуск при загрузке ----------
cat > /etc/systemd/system/ai-chamber.service <<EOF
[Unit]
Description=ai_chamber netns (Smart DNS room for agents)
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=$UNIT_SCRIPT
ExecStop=$UNIT_SCRIPT --purge

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now ai-chamber 2>/dev/null || true
echo "✅ systemd-сервис ai-chamber установлен (автозапуск при загрузке)"