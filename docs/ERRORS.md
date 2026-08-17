# Ошибки и их диагностика

Собрано из реального опыта эксплуатации. Каждая ошибка — с причиной (что мы установили
фактически) и решением.

---

## 1. `#3501 — You do not have a valid license of this product`

```
⚠ You do not have a valid license of this product. Please contact your administrator to request a
license. If you are not an enterprise user and believe you are receiving this message as an error,
please try using the latest version and logging in again. (#3501)
```

### Что это такое

**Серверная проверка лицензии на стороне Google.** В CLI это видно в логах как:

```
403 PERMISSION_DENIED: ... (#3501)
endpoint: https://daily-cloudcode-pa.googleapis.com/v1internal:retrieveUserQuotaSummary
```

Патчер её **не затрагивает**: он меняет только локальные бинари (экраны eligibility/регион).
Выдать аккаунту лицензию или изменить ответ Google API он не может — это прямо указано и в
README самого патчера.

### Что мы проверяли (чтобы исключить локальные причины)

1. **Версия последняя** — `agy --version`, `state/update_status.json` → «Already on the latest version».
2. **Патч на месте** — `status` через контейнер → `patched`.
3. **Сейчас вошёл именно нужный аккаунт** — декодируем токен аккаунта из GNOME keyring
   и спрашиваем Google, чей он:
   ```bash
   # 1) вытащить access_token (libsecret, python3-gi)
   python3 - <<'EOF'
   import gi, json
   gi.require_version("Secret", "1")
   from gi.repository import Secret
   schema = Secret.Schema.new("org.freedesktop.Secret.Generic", Secret.SchemaFlags.NONE,
       {"service": Secret.SchemaAttributeType.STRING, "username": Secret.SchemaAttributeType.STRING})
   val = Secret.password_lookup_sync(schema, {"service": "gemini", "username": "antigravity"}, None)
   print(json.loads(val)["token"]["access_token"])
   EOF
   # 2) чей это токен
   curl -s "https://oauth2.googleapis.com/tokeninfo?access_token=<АТ>"
   # → email, sub, scope (должен быть нужный аккаунт)
   ```
4. **В логе смотрим последний вход** — `~/.gemini/antigravity-cli/log/cli-*.log`:
   `applyAuthResult: email=<email>, authMethod=consumer, quotaProject=`

На практике так мы подтвердили: аккаунт верный, токен живой, версия последняя, патч на месте —
**а ошибку всё равно отдаёт сервер**. Значит, она серверная.

### Решения

1. **Подождать** (часы–сутки) и повторить вход. Google часто снимает временные флаги на
   серию ре-логинов и смену аккаунтов.
2. **Аккаунт с реальной лицензией** (платная подписка / регион, где продукт официально
   работает) — единственное, что гарантированно проходит эту проверку.
3. Повторить вход в **инкогнито** одним аккаунтом, без перебора (п.4 INSTALL).
4. **НЕ перебирать аккаунты и «проекты»** — статус `applyAuthResult: ..., authMethod=gcp`
   означает вход через Google Cloud-проект; без привязки billing-project он ничего не даёт,
   а каждая попытка подозрительна для Google.

> ⚠️ **Ложная гипотеза.** Переустановка «с нуля» на #3501 **не влияет** — это не локальная
> ошибка. Локальное хранилище токенов при этом чистить стоит (см. п.5 ниже).

---

## 2. `HTTP 400 Bad Request: User location is not supported`

```
"code": 400, "message": "User location is not supported for the API use.",
"status": "FAILED_PRECONDITION"
```

Google определил местоположение как неподдерживаемое.

**Решение (по README патчера):**
1. Применить патч (он выставляет обход `isGoogleInternal` на уровне кода).
2. Если патч применён — сменить аккаунт или VPN.
3. Пробовать спец-DNS: [Xbox DNS](https://xbox-dns.ru/), [dns.malw.link](https://info.dns.malw.link/),
   [GeoHide](https://dns.geohide.ru:8443/).

> ⚠️ VPN/прокси могут детектироваться Google и приводить к этой же ошибке — Google активно
> борется с обходами.

---

## 3. `HTTP 500 Internal Server Error`

```
"code": 500, "message": "Internal error encountered.", "status": "INTERNAL"
```

Внутренний отказ на стороне Google. Локально **не лечится** (патчер тоже).

**Решение:** менять аккаунт — желательно на регион, где продукт официально работает, или с
купленной платной подпиской.

---

## 4. «После сброса аккаунт всё равно сразу заходит»

Классика: удалили `~/.gemini/google_accounts.json`, `oauth_creds.json`, а вход всё равно
мгновенный. Причина — авторизация хранится **не только в файлах**:

| Хранилище | Что там | Как чистить |
|---|---|---|
| **GNOME keyring** (`login.keyring`) | запись `service='gemini', username='antigravity'` — токен сессии | `bash scripts/reset-login.sh` |
| `~/.cache/google-vscode-extension/auth/` | полный OAuth (access + refresh) того же аккаунта | `bash scripts/reset-login.sh` |
| `~/.gemini/*` (файлы аккаунта, кеши CLI) | OAuth-файлы, кеш onboarding | `bash scripts/reset-login.sh` |

`reset-login.sh` всё это убирает **с бекапом** в `~/Backups/reset-login-<дата>/`.
Подробнее про то, где именно живут токены:

- Просмотр записей keyring (libsecret):
  ```bash
  python3 -c "
  import gi; gi.require_version('Secret','1')
  from gi.repository import Secret
  s = Secret.Service.get_sync(Secret.ServiceFlags.OPEN_SESSION | Secret.ServiceFlags.LOAD_COLLECTIONS)
  for c in s.get_collections():
      for it in c.get_items():
          print(dict(it.get_attributes()))"
  ```
- Быстрый фикс самой записи:
  ```bash
  python3 -c "
  import gi; gi.require_version('Secret','1')
  from gi.repository import Secret
  schema = Secret.Schema.new('org.freedesktop.Secret.Generic', Secret.SchemaFlags.NONE,
      {'service': Secret.SchemaAttributeType.STRING, 'username': Secret.SchemaAttributeType.STRING})
  print(Secret.password_clear_sync(schema, {'service':'gemini','username':'antigravity'}))"
  ```

---

## 5. Сброс авторизации «с нуля»

```bash
bash scripts/reset-login.sh        # аккаунт+токены+кеши CLI (история/проекты сохраняются)
bash scripts/reset-login.sh --full # + installation_id и состояние/кеши IDE-приложения
```

Все файлы перед удалением бэкапятся в `~/Backups/reset-login-<дата>/`.
После сброса вход — в инкогнито, одним аккаунтом.

---

## 6. «Патчер не применяется: сигнатура не найдена»

См. [`docs/PATCH.md`](PATCH.md) → «Если сигнатура не найдена»: вышла новая версия бинарей,
патчер нужно обновить (`docs/UPDATES.md`).