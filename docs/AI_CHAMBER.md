# Комната `ai_chamber` — сетевой гео-разблокировщик (Smart DNS)

Для `HTTP 400 User location is not supported` патч снимает только **локальный** гейт.
Серверная проверка Google остаётся — и без смены региона соединений `agy` всё равно
не зайдёт. Это решается **не** VPN-приложением, а изолированной netns-комнатой со
**Smart DNS**: для покрытых доменов резолвер отдаёт IP прокси-пула за рубежом
(`87.228.47.204`), прокси сам ходит на целевой сервис с foreign-IP — Google видит
не-РФ соединение. Всё остальное идёт напрямую.

Механика проверена эмпирически (см. раздел «Сравнение»): домены берутся не «от
фонаря», а из строк бинарника `agy` (`cloudcode-pa`, `daily-cloudcode-pa`,
`generativelanguage`, …).

## Что даёт

| Домен (эндпоинты agy/hermes) | Через Xbox DNS |
|---|---|
| `cloudcode-pa.googleapis.com` | ✅ прокси `87.228.47.204` |
| `daily-cloudcode-pa.googleapis.com` | ✅ прокси `87.228.47.204` |
| `generativelanguage.googleapis.com` (Gemini) | ✅ прокси `87.228.47.204` |
| `api.anthropic.com`, `api.openai.com` (hermes) | ✅ прокси `87.228.47.204` |
| `oauth2.googleapis.com` и пр. | обычные IP (так и нужно) |

## Использование

```bash
# клонируй и создай комнату (нужен root)
git clone https://github.com/VS-212/agy.git && cd agy
sudo bash scripts/ai_chamber_setup.sh              # создать/пересоздать
sudo bash scripts/ai_chamber_setup.sh --systemd    # + автозапуск при загрузке
sudo bash scripts/ai_chamber_setup.sh --purge      # удалить комнату и правила
```

### Алиасы (в `~/.bashrc`)

```bash
# runuser сам НЕ читает ~/.profile => PATH без ~/.local/bin.
# Обёртка bash -lc подхватывает PATH и окружение из .profile.
ai-env() {
  local cmd="$1"; shift
  local tail=""
  for a in "$@"; do tail+="$(printf '%q ' "$a")"; done
  sudo ip netns exec ai_chamber runuser -u aaa -- bash -lc "$cmd $tail"
}
ai-room()  { sudo ip netns exec ai_chamber runuser -u aaa -- bash -li; }
ai-agy()   { ai-env agy "$@"; }
ai-kg()    { ai-env kg "$@"; }
ai-hermes(){ ai-env hermes "$@"; }
```

- `ai-agy` / `ai-hermes` / `ai-kg chat` — агент сразу в комнате;
- `ai-env <команда>` — любая разовая команда внутри комнаты;
- `ai-room` — интерактивный шелл в комнате.

> Бинарь hermes в `~/.local/bin` называется `hermes` (`kg` — это тонкая обёртка
> `hermes -p kaggle`). Соответственно `ai-hermes` запускает `hermes`, а не
> `hermes_agent`.

### Проверка

```bash
ai-env dig +short cloudcode-pa.googleapis.com       # → 87.228.47.204
ai-env dig +short api.anthropic.com                 # → 87.228.47.204
ai-env curl -s https://api.ipify.org                # ваш RU-IP — это НОРМАЛЬНО
# (Smart DNS проксирует только покрытые домены, остальной трафик — напрямую)
```

## Безопасность (что делает скрипт)

| Механизм | Детали |
|---|---|
| Изоляция | netns + veth + NAT через default-интерфейс; хост-`resolv.conf` не трогается |
| DNS-lock | из комнаты наружу разрешён только UDP/TCP:53 на `111.88.96.50/.51`; чужие резолверы (`8.8.8.8` и пр.) — DROP |
| IPv6 | полностью отключён внутри комнаты (защита от AAAA-утечки, которая ломает Smart DNS) |
| Откат | `trap ERR` снимает комнату и правила при любом сбое; `--purge` сносит всё включая systemd-юнит |
| Автозапуск | опциональный `--systemd` → юнит `ai-chamber.service` |

## Fallback

Если `agy` всё равно отвечает `HTTP 400` на домене **вне** покрытия Smart DNS
(`aicode.googleapis.com`, `aiplatform.googleapis.com`, `modelarmor.googleapis.com`,
`antigravity.google.com` — не проксируются ни Xbox DNS, ни dns.malw.link, ни Comss),
нужен **Control D Redirect** с ручными правилами: добавляешь нужные домены и
выбираешь страну выхода сам.

## Сравнение Smart DNS-провайдеров (эмпирический замер)

Замер: `dig +short A <домен> @<резолвер>` с реальной машины, домены — из бинарника `agy`.

| Домен | dns.malw.link | Xbox DNS | Comss |
|---|---|---|---|
| `cloudcode-pa.googleapis.com` | прямые Google IP ❌ | прокси ✅ | прямые ❌ |
| `daily-cloudcode-pa.googleapis.com` | прокси ✅ | прокси ✅ | прямые ❌ |
| `generativelanguage.googleapis.com` | прокси ✅ | прокси ✅ | прокси ✅ |
| `api.anthropic.com` / `api.openai.com` | прокси ✅ | прокси ✅ | прокси ✅ |
| `aicode` / `aiplatform` / `modelarmor` / `antigravity.google.com` | ❌ | ❌ | ❌ |

Вывод: DNS-ответ = маршрутная таблица. Для `agy` критично покрытие
`cloudcode-pa` — его даёт только **Xbox DNS** (`111.88.96.50/.51`). Репозиторий
патчера рекомендует те же сервисы (Xbox DNS, dns.malw.link, GeoHide) для HTTP 400.