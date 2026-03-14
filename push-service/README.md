# tyflocentrum-push (push-service)

Minimalny backend do powiadomień push dla Tyflocentrum.

> Uwaga: prawdziwa wysyłka do APNs wymaga Apple Developer Program + kluczy APNs. W MVP serwis loguje „wysyłki” i utrzymuje stan/prefy.

## Endpointy

- `GET /health`
- `POST /api/v1/register` `{ token, env, prefs }`
- `POST /api/v1/update` `{ token, prefs }`
- `POST /api/v1/unregister` `{ token }`
- `POST /api/v1/events/live-start` (auth Bearer)
- `POST /api/v1/events/live-end` (auth Bearer)
- `POST /api/v1/events/schedule-updated` (auth Bearer)

## Uruchomienie lokalne

```bash
PORT=9070 \
DATA_DIR=./.data \
TOKEN_TTL_DAYS=60 \
MAX_TOKENS=50000 \
WEBHOOK_SECRET=dev \
node push-service/server.js
```

## Konfiguracja na VPS (tyflo.eu.org)

Docelowo:
- nginx reverse proxy: `tyflocentrum.tyflo.eu.org` → `127.0.0.1:9070`
- state: `/var/lib/tyflocentrum-push/state.json`
- serwis systemd: `tyflocentrum-push.service`
