# Tyflocentrum — development

## Repo layout

- `Tyflocentrum/` — kod aplikacji (Swift/SwiftUI)
- `TyflocentrumTests/` — unit tests
- `TyflocentrumUITests/` — UI tests + smoke
- `docs/` — dokumentacja (README jest celowo krótkie)
- `scripts/` — skrypty pomocnicze (np. pobieranie `.ipa` z CI)

## CI (build IPA)

- Unsigned IPA: `.github/workflows/ios-unsigned-ipa.yml` (GitHub-hosted `macos-14`)
  - lint: `swiftformat --lint`
  - test: `xcodebuild test` (Simulator)
  - build: artifact `Tyflocentrum-unsigned-ipa` (`tyflocentrum.ipa`)
- Skrypt używany przez workflow: `scripts/build-unsigned-ipa.sh`
- Pobranie artifactu: `scripts/fetch-ipa.sh` (albo UI GitHub Actions)

## Najważniejsze entrypointy

- Start appki: `Tyflocentrum/TyflocentrumApp.swift`
  - konfiguruje zależności i wstrzykuje je przez `EnvironmentObject`,
  - hostuje `ContentView` w wrapperze obsługującym **Magic Tap** (VoiceOver).
- Taby: `Tyflocentrum/Views/ContentView.swift`

## Warstwy (w skrócie)

- UI: `Tyflocentrum/Views/*`
- Sieć / WordPress API + kontakt: `Tyflocentrum/TyfloAPI.swift`
- Audio (AVPlayer): `Tyflocentrum/AudioPlayer.swift`
- Bezpieczne renderowanie HTML: `Tyflocentrum/Views/SafeHTMLView.swift`
- Ulubione: `Tyflocentrum/FavoritesStore.swift`
- Ustawienia: `Tyflocentrum/SettingsStore.swift`

## UI i dostępność (VoiceOver)

- Widok **Nowości** używa `ScrollView + LazyVStack` zamiast `List`, bo na niektórych urządzeniach `List` nie wystawia przewidywalnie systemowego paska przewijania VoiceOver na pierwszym ekranie (pojawiał się dopiero po kilku gestach przewijania).

## Sieć i cache

- `TyfloAPI.fetch*` domyślnie używa `cachePolicy = .useProtocolCachePolicy` dla requestów do WordPress (listy/detale), żeby pozwolić `URLCache` obniżyć koszt sieci i energii (o ile serwery zwracają cache‑friendly nagłówki).
- Dla odpowiedzi z `cache-control: no-store` (np. część endpointów TyfloŚwiata) TyfloAPI ma dodatkowy **in-memory cache z TTL = 5 min** (żeby ograniczyć powtarzane requesty i drenaż baterii).
- Endpointy „na żywo” (`isTPAvailable`, `getRadioSchedule`) wymuszają `cachePolicy = .reloadIgnoringLocalCacheData` (żeby nie „przegapić” rozpoczęcia audycji / zmian w ramówce).

## Testy

### Unit tests

- `TyflocentrumTests/` (m.in. stubowanie `URLSession` przez `StubURLProtocol`).

## Formatowanie (SwiftFormat)

- Konfiguracja: `.swiftformat` (repo root).
- CI: workflow `iOS (unsigned IPA)` uruchamia `swiftformat --lint` przed testami.
- Lokalnie na macOS:

```bash
brew install swiftformat
swiftformat --config .swiftformat .
```

- Bez Maca: uruchom workflow GitHub Actions **SwiftFormat** (manual). Jeśli są zmiany, workflow sam je zacommituje do `master`.

### UI tests

- `TyflocentrumUITests/`
- App rozpoznaje argument launch `UI_TESTING` i wtedy:
  - używa in-memory Core Data,
  - stubuje sieć przez `UITestURLProtocol` (zdefiniowany w `Tyflocentrum/TyflocentrumApp.swift`).

Przykładowe flagi do scenariuszy awaryjnych:

- `UI_TESTING_FAIL_FIRST_REQUEST` — pierwsze requesty do wybranych endpointów zwrócą błąd (test retry/pull-to-refresh).
- `UI_TESTING_STALL_NEWS_REQUESTS` — symuluje “zawieszone” requesty w Nowościach.
- `UI_TESTING_STALL_DETAIL_REQUESTS` — symuluje “zawieszone” requesty detali (post/page).

### xcodebuild (jak w CI)

```bash
xcodebuild \
  -project Tyflocentrum.xcodeproj \
  -scheme Tyflocentrum \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -parallel-testing-enabled NO \
  -parallel-testing-worker-count 1 \
  test
```

## CI i artefakty

- Unsigned IPA: `.github/workflows/ios-unsigned-ipa.yml`
- Pobranie artifactu: `scripts/fetch-ipa.sh`

## Polityka dokumentacji (kompromis)

- `README.md` trzymamy **krótkie** (opis projektu + szybki start + linki).
- Szczegóły (funkcje, architektura, kontrakty, CI) trzymamy w `docs/`.
- Formatowanie kodu utrzymujemy spójne przez **SwiftFormat** (lint w CI + manual workflow do automatycznej poprawy).
- Guard w CI (`scripts/require-readme-update.sh`) wymaga aktualizacji **README lub `docs/`** tylko wtedy, gdy zmiana dotyka “public surface” (nowe funkcje/API/CI/build), a nie przy każdej drobnej poprawce.
