# Патч — как устроен и как им пользоваться

## Что именно патчится

Патчер меняет **скомпилированные бинари** по байтовой сигнатуре (машинные гейты — не UI-обход):

| Компонент | Что патчится | Результат |
|---|---|---|
| **Antigravity IDE 2.0** (`resources/bin/language_server`) | проверка авторизации в скомпилированном бинарике бэкенда | `hasValidAuth=true (x64)` |
| **CLI `agy`** | два гейта eligibility в Go-бинаре (x86-64 / ARM64) | `eligibility screen off (x64)` ×2 |

Точные байтовые дельты, смещения и disasm для подтверждённых версий (IDE 2.8.1 / CLI 1.1.13)
зафиксированы в [docs/REVERSE.md](REVERSE.md).

Патч **не** трогает и не может трогать:
- облачные лицензии/доступ Google (ошибка `#3501` — см. [docs/ERRORS.md](ERRORS.md));
- ответы Google API (HTTP 400/500);
- твои данные и учётку.

## Почему патчинг идёт в песочнице без сети

Патчер — сторонний код с непрозрачной логикой. Мы запускаем его только внутри Docker-контейнера:

- `--network none` — сеть отключена; любая ветка «проверить обновления / открыть браузер /
  скачать» превращена драйвером в жёсткую ошибку;
- `--cap-drop ALL`, `--security-opt no-new-privileges`, non-root (uid 1000);
- наружу монтируются только `final/` (цели) и `state/` (логи);
- код патчера копируется в образ **при сборке** (пин-коммит в `state/patcher.commit`),
  в рантайме он ничего не качает.

Единственный способ дать контейнеру сеть — явно запустить `scripts/90_check_updates.sh`
(разовый контейнер `--rm`, живёт только на время проверки).

## Жизненный цикл патча

```
источники (10_sources.sh) → образ (20_build.sh) → патч (30_patch.sh) → установка (40_install.sh)
                                     │
                          sha256 ДО → патчер (без сети) → sha256 ПОСЛЕ
                          .agybak-бекапы рядом с целями
```

## Проверка статуса

```bash
# оба компонента сразу (контейнер без сети)
docker run --rm --network none \
  -v "$HOME/apps":/app/apps -v "$HOME/.local/bin":/app/bin \
  safe-ag-patcher:latest status \
  /app/apps/antigravity-ide/resources/bin/language_server \
  /app/bin/agy
# → language_server : patched
# → agy             : patched
```

## Откат патча

Бекапы `.agybak` создаются перед изменением рядом с целями. Восстановление:

```bash
# менеджер IDE
docker run --rm --network none \
  -v "$HOME/apps":/app/apps \
  safe-ag-patcher:latest restore-manager /app/apps/antigravity-ide/resources/bin/language_server
# CLI
docker run --rm --network none \
  -v "$HOME/.local/bin":/app/bin \
  safe-ag-patcher:latest restore-agy /app/bin/agy
```

## Код возврата 30_patch.sh

`0` — ок; `2` — менеджер не пропатчен; `3` — agy не пропатчен; `4` — оба.
«Контрольные суммы не изменились» при этом = патч не применился.

## Если сигнатура не найдена

Патчер работает по байтовым сигнатурам конкретных версий бинарей. Вышла новая версия —
сигнатуры «уехали». Это **не** проблема установки: обновь патчер и повтори цикл →
[`docs/UPDATES.md`](UPDATES.md) (раздел «Новая версия патчера»).