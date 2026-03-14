# Tyflocentrum

Tyflocentrum to aplikacja iOS napisana w **SwiftUI**, która agreguje i udostępnia treści z serwisów Tyflo:

- **Tyflopodcast** (podcasty + komentarze + dodatki do odcinków),
- **Tyfloświat** (artykuły + czasopismo TyfloŚwiat),
- **Tyfloradio** (stream na żywo + kontakt z radiem).

Priorytetem projektu jest **dostępność (VoiceOver)** oraz wygoda odsłuchu (pilot systemowy, prędkość, wznawianie).

## Dokumentacja

README jest celowo utrzymywane **krótkie i stabilne** — szczegóły są w `docs/`.

- Start tutaj: [docs/index.md](docs/index.md)

## Wymagania

- iOS **17.0+**
- Xcode **15+** (Swift 5)
- (opcjonalnie) GitHub CLI `gh` – do pobierania unsigned IPA z GitHub Actions.

## Uruchomienie z Xcode

1. Otwórz `Tyflocentrum.xcodeproj` w Xcode.
2. Wybierz scheme `Tyflocentrum`.
3. Uruchom na symulatorze lub urządzeniu.

Jeśli uruchamiasz na urządzeniu, możesz potrzebować własnego Teamu/Provisioningu (ustawienia Signing w Xcode).

## Gotowa paczka (unsigned IPA) z CI

Repo zawiera workflow GitHub Actions `iOS (unsigned IPA)` (`.github/workflows/ios-unsigned-ipa.yml`), który publikuje artifact `Tyflocentrum-unsigned-ipa`.

Pobieranie artifactu skryptem (wymaga `gh` oraz zalogowania do GitHuba):

```bash
./scripts/fetch-ipa.sh                # pobierze ostatni udany run na gałęzi master
./scripts/fetch-ipa.sh <run_id>       # pobierze konkretny run (databaseId)
```

Domyślnie skrypt zapisuje plik do `artifacts/tyflocentrum.ipa`.

> `.ipa` jest **niepodpisana**, więc do instalacji potrzebujesz narzędzia do sideloadingu (np. AltStore/Sideloadly).

