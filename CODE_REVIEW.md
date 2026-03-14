# Tyflocentrum — code review (iOS)

> Uwaga: to jest **historyczny** dokument (pierwotny przegląd). Repo było od tego czasu istotnie rozwijane i część uwag może być nieaktualna. Aktualny opis projektu: `docs/development.md`.

Stan repozytorium: `55675e9` (2026-01-23)

## TL;DR / priorytety
1) Odblokować build + przygotować repo pod CI (braki w projekcie, kompilacja, zależności).
2) Uporządkować architekturę pod testy (oddzielenie UI od sieci/audio, DI).
3) Poprawić dostępność (VoiceOver) — szczególnie listy, czytelność treści, player, formularze.
4) Dopiero potem optymalizacje (HTML render, paginacja, cache).

## Szybki przegląd architektury
- SwiftUI app z `TabView` (`Tyflocentrum/Views/ContentView.swift`).
- Dane: WordPress REST API (`Tyflocentrum/TyfloAPI.swift`) + dodatkowy endpoint do “kontakt z radiem”.
- Audio: BASS (`Tyflocentrum/BASSHelper.swift`, `Tyflocentrum/bass.h`, bridging header).
- CoreData: `DataController` istnieje, ale aktualnie nie widać realnego użycia w UI (tylko wstrzyknięcie `managedObjectContext` w `Tyflocentrum/TyflocentrumApp.swift`).

## Krytyczne blokery (build/CI/stabilność)
### 1) Stray znak w kodzie (błąd kompilacji)
- `Tyflocentrum/BASSHelper.swift:17` zawiera samotne `1` przed `print(...)`.

### 2) Błędne użycie `await` (błąd kompilacji)
- `Tyflocentrum/Views/NewsView.swift:27` i `Tyflocentrum/Views/NewsView.swift:29`:
  - jest `await podcasts = ...` zamiast `podcasts = await ...`.

### 3) `bass.xcframework` nie jest w repo (będzie psuło CI i build na cudzym środowisku)
- `Tyflocentrum.xcodeproj/project.pbxproj:76` wskazuje na ścieżkę z `Downloads/...`:
  - to nie zadziała poza komputerem autora.
- Konsekwencja: GitHub Actions / świeża maszyna nie zbuduje projektu, dopóki zależność nie będzie wersjonowana (np. dodana do repo, podciągana w CI, albo zastąpiona `AVPlayer`).

### 4) Potencjalnie niebezpieczne API do C-string (UB/crash)
- `Tyflocentrum/StringHelper.swift` zwraca wskaźnik na `utf8String` z `NSString`.
  - Żywotność tego wskaźnika nie jest gwarantowana po wyjściu z właściwości — ryzyko “dangling pointer”.
  - To szczególnie groźne, bo jest używane w `BASS_StreamCreateURL`.

### 5) Crash przez `fatalError` w runtime
- `Tyflocentrum/TyfloAPI.swift:95-99` — `fatalError("Error")` przy niepoprawnym URL.
- `Tyflocentrum/DataController.swift` — `fatalError` przy problemach z CoreData store.

## Testowalność (co zmienić, żeby dało się sensownie testować)
### 1) Oddzielić UI od side-effectów
Aktualnie widoki SwiftUI wołają sieć bezpośrednio (np. `.task` w listach) i trzymają stan w `@State`.
Propozycja:
- dodać warstwę `ViewModel` (MVVM) / `Repository`:
  - UI: tylko renderuje `@StateObject` VM i wywołuje metody typu `refresh()`.
  - VM: pobiera przez protokół API i mapuje dane na `ViewState` (w tym błąd/loading/empty).

### 2) Wyrzucić singletony na rzecz DI + protokołów
- `TyfloAPI.shared` i `BassHelper.shared` utrudniają testy.
- Docelowo:
  - `protocol TyfloAPIClient { ... }`
  - `protocol AudioPlayer { ... }`
  - Implementacje prod + mock/stub w testach.

### 3) Dodać test targety (Unit + UI)
W projekcie nie ma targetów testowych.
Minimalny zestaw:
- Unit tests:
  - dekodowanie JSON (`Podcast`, `Category`, `Comment`) + daty.
  - poprawność budowania URL-i (szczególnie `search=` i parametry).
  - logika `ViewModel` (loading/empty/error).
- UI tests:
  - nawigacja przez taby i listy.
  - sprawdzenie, że najważniejsze elementy mają `accessibilityIdentifier` i sensowne etykiety.

## Bezpieczeństwo (praktyczne ryzyka i rekomendacje)
### 1) Sklejanie URL bez percent-encoding
- `Tyflocentrum/TyfloAPI.swift:101-114` buduje URL przez konkatenację:
  - `search=\(searchString.lowercased())`
  - dla spacji/UTF-8 to będzie niepoprawne lub da inne wyniki.
Rekomendacja: `URLComponents` + `queryItems`.

### 2) Brak weryfikacji status code / typów błędów
- `URLSession.data(from:)` ignoruje HTTP status.
Rekomendacja:
- sprawdzać `HTTPURLResponse.statusCode` i mapować na błędy domenowe (np. `network`, `decoding`, `server`).
- pokazywać błąd w UI zamiast `print()`.

### 3) `WKWebView` z HTML z internetu
- `Tyflocentrum/Views/HTMLRendererHelper.swift` ładuje HTML prosto do `WKWebView`.
Ryzyka:
- treści mogą zawierać rzeczy, których nie chcesz wykonywać/renderować.
- trudniej o pełną kontrolę dostępności i stylu.
Rekomendacja:
- jeśli to ma być “czytnik”: render do tekstu (sanityzacja → plain text / `AttributedString`) i własne style.
- jeśli zostaje `WKWebView`: ograniczenia przez konfigurację (np. wyłączanie niepotrzebnych rzeczy), spójna obsługa linków, i testy accessibility.

### 4) Logowanie błędów i danych użytkownika
- W kilku miejscach jest `print(...)`. Przy debugowaniu OK, ale docelowo lepiej:
  - `Logger` (os_log) z kontrolą poziomów.
  - nie logować treści wiadomości z formularza kontaktowego.

## Optymalizacja (wydajność i stabilność)
### 1) HTML parsing w wierszach listy
- `Tyflocentrum/Views/ShortPodcastView.swift` renderuje HTML (tytuł + excerpt) w komórkach listy.
To bywa kosztowne i może “rwać” scroll.
Rekomendacja:
- na listach pokazywać plain text (strip HTML).
- pełny HTML dopiero w szczegółach.

### 2) Brak paginacji i cache
- Wiele endpointów robi `per_page=100`.
Rekomendacja:
- paginacja (np. `page=1..n`) + lazy loading w liście.
- `URLCache` / proste cache w pamięci na czas sesji.

### 3) Audio: zarządzanie handle i cyklem życia
- `BassHelper.stopAll()` nie zwalnia zasobów (`BASS_ChannelFree`) i nie usuwa handle z tablicy.
- Brak `onDisappear` w `MediaPlayerView` do sprzątania/stopowania.
Rekomendacja:
- jasny model: “1 aktywny stream” + zwalnianie poprzedniego.
- osobny `AudioSessionManager` (przynajmniej żeby nie było rozproszonego `AVAudioSession`).

### 4) `HTMLTextView` nie aktualizuje się i jest “jednowierszowe”
- `Tyflocentrum/Views/HTMLTextView.swift`:
  - `updateUIView` jest puste (zmiana `text` nie odświeży UI).
  - `UILabel` domyślnie ma `numberOfLines = 1`.

## Accessibility / VoiceOver (najważniejsze do poprawy)
### 1) Semantyka wierszy listy + akcje
- `ShortPodcastView` zawiera “ukryty” `NavigationLink` z `EmptyView()` sterowany stanem.
  - łatwo o chaos w fokusu VO (elementy bez etykiet) i trudny do testowania UI.
Rekomendacja:
- uprościć nawigację: wiersz jako `NavigationLink` + menu/akcje kontekstowe.
- dodać:
  - sensowny `accessibilityLabel` (np. sam tytuł bez HTML).
  - `accessibilityHint` (np. “Otwiera szczegóły. Akcje: Słuchaj”).
  - `accessibilityIdentifier` dla UI testów.

### 2) Czytelność treści (Dynamic Type, scroll)
- `DetailedPodcastView` pokazuje długi content w `VStack` bez scrolla.
- `HTMLTextView` jako `UILabel` bez wsparcia dynamic type, bez multiline, bez aktualizacji.
Rekomendacja:
- w szczegółach: `ScrollView` + tekst w pełni dostępny (najlepiej plain text / `AttributedString` w `Text`).
- zapewnić:
  - poprawny porządek czytania VO,
  - nagłówki (np. tytuł jako `.accessibilityAddTraits(.isHeader)`),
  - sensowne linki (jeśli są).

### 3) Tytuły nawigacji nie powinny zawierać HTML
- `DetailedPodcastView.navigationTitle("\(podcast.title.rendered) ...")` może zawierać tagi HTML.
Rekomendacja:
- trzymać dodatkowe pole `titlePlain` i używać go do VO oraz tytułów.

### 4) Player: ogłaszanie stanu i wartości
Plus:
- `.accessibilityAction(.magicTap)` już jest (`Tyflocentrum/Views/MediaPlayerView.swift`).
Rekomendacja:
- `accessibilityValue` na przycisku play/pause (np. “Odtwarzanie wstrzymane / trwa”).
- po zmianie stanu: announcement (krótki) lub przynajmniej pewność, że VO odczyta zmianę etykiety.
- upewnić się, że fokus nie “ucieka” po otwarciu playera.

### 5) Formularz kontaktu: błędne komunikaty (VO/UX)
- `ContactView`:
  - zawsze ogłasza sukces (`UIAccessibility.post(...)`) nawet gdy request się nie powiódł,
  - `errorMessage` nigdy nie jest ustawiany (alert pokaże pusty tekst),
  - w razie błędu podstawiasz błąd do `message` (pole treści), co miesza użytkownikowi w edycji.
Rekomendacja:
- na sukces: announcement + dismiss.
- na błąd: nie zamieniać treści wiadomości; pokazać alert z opisem, ustawić fokus na alert.

## Sugerowana kolejność prac (proponowany plan refaktoru)
1) Odblokować build (usunąć stray `1`, poprawić `await`, ogarnąć BASS dependency).
2) Ustabilizować HTML render i czytelność (scroll, dynamic type, plain text w listach).
3) Wprowadzić warstwę VM + protokoły (API/audio) → dodać testy jednostkowe.
4) Dodać `accessibilityIdentifier` + poprawić etykiety/hinty → dodać UI testy VO-krytycznych ścieżek.
5) Dopiero potem paginacja/cache i dopracowanie UX.

## Pytania decyzyjne (wpływają na rozwiązanie)
1) Czy BASS jest konieczny, czy możemy przejść na `AVPlayer`?
2) Jaki minimalny iOS target trzymamy (w projekcie są 16.1 i 17.0)?
3) Czy CoreData zostaje (na dziś wygląda jak nieużywane)?
