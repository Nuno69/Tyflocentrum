# Powiadomienia push (plan + MVP)

Ten dokument opisuje plan wdrożenia powiadomień push w Tyflocentrum:

- źródła eventów (WordPress + panel kontaktowy),
- kategorie powiadomień (checkboxy),
- backend (push‑service) i kontrakty endpointów,
- ograniczenia testów bez Apple Developer Program.

## Kiedy to będzie działać „na iPhonie”

Żeby **realnie** wysyłać push na fizyczne urządzenia iOS przez APNs, potrzebujesz:

- Apple Developer Program (płatne konto),
- włączonej capability **Push Notifications** dla bundle ID,
- klucza APNs (`.p8`) + `teamId` + `keyId`.

Bez tego da się przygotować całą architekturę, preferencje i testy logiki, ale nie da się wykonać pełnego E2E na urządzeniu.

## Stan na dziś (App Store 1.0)

Ponieważ w tej chwili nie mamy pełnej konfiguracji APNs (capabilities/entitlements + klucze), w buildzie **Release**:

- sekcja „Powiadomienia push” jest ukryta w UI,
- aplikacja nie prosi o zgodę na powiadomienia na starcie.

W buildzie **Debug** sekcja może być widoczna do celów deweloperskich.

## Kategorie (preferencje użytkownika)

W Ustawieniach aplikacji dodajemy sekcję „Powiadomienia push” z checkboxami (domyślnie wszystkie włączone):

- Nowe odcinki Tyflopodcast
- Nowe artykuły Tyfloświat
- Start audycji interaktywnej Tyfloradio
- Zmiana ramówki Tyfloradio

Oraz przełącznik „Wszystkie”, który włącza/wyłącza wszystkie opcje naraz.

## Źródła eventów

### 1) WordPress (poll co 5 minut)

Backend co 5 minut pobiera najnowsze wpisy z:

- `https://tyflopodcast.net/wp-json/wp/v2/posts`
- `https://tyfloswiat.pl/wp-json/wp/v2/posts`

i wysyła powiadomienia o nowych treściach.

### 2) Panel kontaktowy (webhook, „od razu”)

Eventy zależne od anteny powinny być natychmiastowe (bez czekania na poll), więc panel kontaktowy będzie wykonywał webhook do push‑service:

- `live-start` (uruchomienie audycji interaktywnej),
- `live-end` (zakończenie),
- `schedule-updated` (zmiana ramówki).

Wywołania są best‑effort: błąd webhooka nie może blokować panelu.

## Backend: push‑service

Serwis działa pod domeną `tyflocentrum.tyflo.eu.org` (nginx reverse proxy na `127.0.0.1:9070`).

### Endpointy (propozycja)

Publiczne (z aplikacji):

- `POST /api/v1/register`
  - body: `{ token, env, prefs }`
- `POST /api/v1/update`
  - body: `{ token, prefs }`
- `POST /api/v1/unregister` (opcjonalnie)
  - body: `{ token }`

Webhooki z panelu (wymagają sekretu):

- `POST /api/v1/events/live-start`
- `POST /api/v1/events/live-end`
- `POST /api/v1/events/schedule-updated`

Health:

- `GET /health` → `200 OK` (do monitoringu / smoke).

### Autoryzacja webhooków z panelu

Webhooki z panelu muszą mieć nagłówek:

- `Authorization: Bearer <PUSH_WEBHOOK_SECRET>`

Sekret trzymamy poza repo (plik na serwerze).

## Bezpieczeństwo / odporność na nadużycia (MVP)

- Endpointy `POST /api/v1/events/*` są chronione sekretem (`Bearer`), więc nie da się ich wywołać bez znajomości klucza.
- Endpointy rejestracji tokenów są publiczne (apka musi móc się zarejestrować), ale:
  - są objęte limitami requestów po stronie nginx (rate limit),
  - backend ma limit rozmiaru JSON body,
  - backend usuwa „stare” tokeny (TTL) i ogranicza maksymalną liczbę zapisanych tokenów (pruning).

### Payload (dla deep linków)

Wysyłamy w payload:

- `kind`: `podcast` | `article` | `live` | `schedule`
- `id` (dla WP postów) lub inne dane dla `live`/`schedule`
- `title`
- `publishedAt` / `updatedAt` (ISO)

Aplikacja mapuje payload → nawigacja do właściwego widoku.

## Testy

Bez Apple Developer Program nie uruchomimy prawdziwego push na urządzeniu, ale testujemy:

- unit: mapowanie preferencji + kontrakt backendu (JSON),
- unit/UI: nawigacja po otrzymaniu „symulowanego” payloadu (w UI_TESTING),
- backend: testy kontraktów endpointów + smoke `/health`.
