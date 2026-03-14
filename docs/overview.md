# Tyflocentrum — przegląd

Tyflocentrum to aplikacja iOS napisana w **SwiftUI**, która agreguje i udostępnia treści z serwisów Tyflo:

- **Tyflopodcast**: podcasty + komentarze + dodatki do odcinków (znaczniki czasu, linki),
- **Tyfloświat**: artykuły + **czasopismo TyfloŚwiat** (roczniki, numery, spis treści),
- **Tyfloradio**: stream na żywo + ramówka + kontakt z radiem (tekstowo i głosowo).

Aplikacja jest projektowana z naciskiem na **dostępność (VoiceOver)** i wygodę odsłuchu (pilot systemowy, wznawianie, prędkość).

## Wymagania

- iOS **17.0+**
- Xcode **15+** (Swift 5) — jeśli budujesz z kodu

## Co potrafi aplikacja (high level)

- **Nowości**: wspólny feed podcastów i artykułów + doładowywanie starszych treści.
- **Podcasty / Artykuły**: kategorie → lista → szczegóły.
- **Czytnik artykułów**: bezpieczne renderowanie HTML.
- **Odtwarzacz**: play/pause, przewijanie ±30s, suwak pozycji, prędkość do 3.0x, wznawianie.
- **Ulubione**: podcasty, artykuły (w tym z czasopisma), tematy (znaczniki czasu), linki.
- **Ustawienia**: m.in. pozycja etykiety typu treści w komunikatach VoiceOver, zapamiętywanie prędkości.
- **Kontakt z Tyfloradiem**: wiadomość tekstowa lub głosowa (nagrywanie, odsłuch, dogrywanie, wysyłka).

## Uruchomienie z Xcode (najprostsze)

1. Otwórz `Tyflocentrum.xcodeproj` w Xcode.
2. Wybierz scheme `Tyflocentrum`.
3. Uruchom na symulatorze lub urządzeniu.

Na urządzeniu może być potrzebny provisioning (Signing).

## Gotowa paczka (unsigned IPA) z CI

Repo zawiera workflow GitHub Actions `iOS (unsigned IPA)` (`.github/workflows/ios-unsigned-ipa.yml`), który buduje artifact `Tyflocentrum-unsigned-ipa`.

Pobieranie artifactu:

```bash
./scripts/fetch-ipa.sh
./scripts/fetch-ipa.sh <run_id>
```

Domyślnie plik trafia do `artifacts/tyflocentrum.ipa`.

> `.ipa` jest **niepodpisana**, więc do instalacji potrzebujesz narzędzia do sideloadingu (np. AltStore/Sideloadly).

## Wiadomości głosowe do Tyfloradia

Opcja głosówek wymaga panelu kontaktowego (serwer) obsługującego endpointy `addvoice` / `voice`. Kontrakt i notatki wdrożeniowe: [docs/voice-messages.md](voice-messages.md).
