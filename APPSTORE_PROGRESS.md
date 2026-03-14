# Tyflocentrum — App Store readiness (postęp prac)

Data: **2026-01-29**

Ten plik jest „żywą” check‑listą wdrożeń pod wydanie **1.0** (App Store) na podstawie `CODE_REVIEW_APPSTORE.md`.

## Stan CI

- Baseline (przed poprawkami z tej iteracji): workflow `iOS (unsigned IPA)` – **success** (run `21481970583`).
- Po poprawkach z tej iteracji: workflow `iOS (unsigned IPA)` – **success** (run `21495748088`).

## Wdrożone (bez Apple Developer Program)

- Usunięto martwy, legacy kod renderowania HTML (`HTMLTextView`, `HTMLRendererHelper`).
- Push (na teraz): UI i automatyczna rejestracja powiadomień są ukryte/wyłączone w buildzie Release (żeby nie dostarczać „pozornej” funkcji).
- Zoptymalizowano `Podcast.PodcastTitle.plainText` (memoizacja + szybka ścieżka bez parsowania HTML) i dodano testy regresji.
- Migracja `NavigationView` → `NavigationStack` w głównych widokach.
- `TyfloAPI`: dla requestów WordPress domyślne `cachePolicy = .useProtocolCachePolicy` (a dla endpointów „na żywo” wymuszone `reloadIgnoringLocalCacheData`) + testy regresji.
- SwiftFormat: dodano `.swiftformat` + `.swift-version`, lint w CI oraz workflow `SwiftFormat` do automatycznego formatowania bez Maca.
- `TyfloAPI`: dodano in‑memory cache z TTL (5 min) dla odpowiedzi z `cache-control: no-store` + testy regresji.
- `TyfloAPI`: dodano limity pamięci dla cache `no-store` (max wpisów / max bajtów / max rozmiar pojedynczej odpowiedzi) + testy ewikcji.
- Logowanie: `print(...)` zastąpiono `Logger` (`os_log`) i ograniczono logowanie „wrażliwych” URL-i (bez querystringów).
- Ustabilizowano nawigację z menu aplikacji (żeby UI testy i nawigacja były deterministyczne).
- iPad/Mac: ukryto i wyłączono iPhone‑only „tryb ucha” (proximity) w ekranie głosówek + testy regresji.
- `SafeHTMLView`: odświeża font-size po zmianie Dynamic Type (żeby treść HTML reagowała na ustawienia).
- Projekt: ujednolicono niespójne build settings (`IPHONEOS_DEPLOYMENT_TARGET`).
- Daty: zabezpieczono współdzielenie `DateFormatter` w `Podcast.formattedDate` (uniknięcie problemów przy concurrency).

## Wymaga Apple Developer Program / zewnętrznej konfiguracji

- Realne powiadomienia push przez APNs:
  - capability **Push Notifications** + entitlements dla docelowego bundle ID,
  - klucz APNs (`.p8`) + `teamId` + `keyId`,
  - faktyczna wysyłka do APNs w `push-service` (obecnie MVP tylko loguje fan‑out).

## Do zrobienia poza kodem (App Store Connect)

- Dodać **Privacy Policy URL** oraz **Support URL**.
- Uzupełnić „App Privacy” zgodnie z realnym działaniem aplikacji (kontakt, głosówki, ulubione/ustawienia; push jeśli zostanie włączony).
- Przygotować notatki do App Review (co i gdzie przetestować).

## Kandydaci na kolejne iteracje (nie blokują 1.0)

- ✅ Dołożono narzędzie do automatycznego formatowania (**SwiftFormat**) i ustandaryzowano styl w repo (lint w CI).
- ✅ Dodano „prawdziwy” cache (in‑memory + TTL) dla endpointów z `cache-control: no-store` (z testami).
