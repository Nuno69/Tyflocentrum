# Tyflocentrum — code review + App Store readiness (iOS)

Data przeglądu: **2026-01-29**  
Stan repozytorium: `c4b0528`  
Zakres: aplikacja iOS (`Tyflocentrum/`, `TyflocentrumTests/`, `TyflocentrumUITests/`) + komponent backendowy powiadomień (`push-service/`) w kontekście funkcji „push”.

## TL;DR (decyzje przed wysyłką do App Store)

### Co się zmieniło od poprzedniej wersji (repo: `83bb751`)
- Usunięto legacy renderowanie HTML (`HTMLTextView`, `HTMLRendererHelper`) i zostało jedno, bezpieczne rozwiązanie (`SafeHTMLView`).
- Push: sekcja w UI i automatyczna rejestracja zostały wyłączone w buildzie **Release** (zostawione jako debug‑only narzędzie).
- Wydajność: `Podcast.PodcastTitle.plainText` ma memoizację i „szybką ścieżkę” dla tekstu bez HTML; są testy regresji.
- Nawigacja: migracja `NavigationView` → `NavigationStack` + stabilniejsze menu aplikacji (`navigationDestination`).
- Sieć: WordPress requesty domyślnie używają `.useProtocolCachePolicy`; endpointy „na żywo” nadal wymuszają `reloadIgnoringLocalCacheData`. Dodano też in‑memory TTL cache (5 min) dla odpowiedzi z `Cache-Control: no-store` + testy.
- Repo: dodano SwiftFormat (`.swiftformat`, `.swift-version`) i lint w CI.
- iPad/Mac: ukryto i wyłączono iPhone‑only „tryb ucha” (proximity) w ekranie głosówek + testy regresji.
- `TyfloAPI`: dodano limity pamięci dla cache `no-store` (max wpisów / max bajtów / max rozmiar pojedynczej odpowiedzi) + testy ewikcji.
- Logowanie: `print(...)` zastąpiono `Logger` (`os_log`) i ograniczono logowanie „wrażliwych” URL-i (bez querystringów).
- `SafeHTMLView`: odświeża font-size po zmianie Dynamic Type (żeby treść HTML reagowała na ustawienia).
- Projekt: ujednolicono niespójne build settings (`IPHONEOS_DEPLOYMENT_TARGET`).
- Daty: zabezpieczono współdzielenie `DateFormatter` w `Podcast.formattedDate` (uniknięcie problemów przy concurrency).

### Najważniejsze ryzyka (w tej wersji)
1. **App Store Connect**: przygotować i uzupełnić:
   - **Privacy Policy URL** i **Support URL**,
   - „App Privacy” zgodne z realnym działaniem aplikacji (kontakt/wiadomości/głosówki + dane lokalne).
2. **iPad**: projekt wspiera iPad (`TARGETED_DEVICE_FAMILY = "1,2"`), więc musisz przygotować **zrzuty ekranu iPad** i zrobić sanity‑check UI (czytelność na szerokich ekranach, orientacje, nawigacja).
3. **Mac (uruchamianie na macOS)**:
   - najprostsza ścieżka to „**iPad app na Macu (Apple silicon)**” — zwykle bez zmian w kodzie, ale wymaga testu UX (okno, klawiatura/mysz/scroll) i upewnienia się, że nie polegasz na sprzętowych feature’ach iPhone’a,
   - iPhone‑only funkcje sprzętowe: „tryb ucha” (proximity) jest już ukryty/wyłączony poza iPhone (✅); nadal warto sanity‑przejść inne miejsca, gdzie UI/UX mogłoby zakładać iPhone’a.
4. **Powiadomienia push**:
   - w tej wersji **Release** push są wyłączone w UI i logice rejestracji (celowo, żeby nie dostarczać „pozornej” funkcji),
   - jeśli wrócą w kolejnej iteracji: wymagają APNs (capability/entitlements + klucze) i realnej wysyłki w `push-service`.

### Co jest mocne (duże plusy pod App Store i jakość)
- **Dostępność (VoiceOver)**: wiele `accessibilityLabel/Hint/Identifier`, sensowne akcje na wierszach list, Magic Tap (globalny i kontekstowy).
- **Audio**: przejście na `AVPlayer` + pilot systemowy (`MPRemoteCommandCenter`) + wznawianie + prędkość.
- **Bezpieczne renderowanie HTML**: `SafeHTMLView` bez JS, non‑persistent storage, kontrola nawigacji i schematów URL.
- **Testy**: unit tests + UI smoke tests z deterministycznym stubowaniem sieci (`StubURLProtocol`, `UITestURLProtocol`) + testy regresji dla cache/HTML/plainText.
- **Higiena repo/CI**: SwiftFormat jako lint w CI zmniejsza ryzyko „rozjeżdżania się” stylu i ułatwia review.

## 1) Dobre praktyki, architektura i utrzymanie

### Co jest dobrze zrobione
- **Wstrzykiwanie zależności i tryb UI testów**: `Tyflocentrum/TyflocentrumApp.swift` rozdziela konfigurację produkcyjną i testową (in‑memory Core Data, osobne `UserDefaults`, stub sieci).
- **Wyraźne warstwy „store”**: `FavoritesStore`, `SettingsStore`, `PushNotificationsManager` trzymają stan poza widokami i ograniczają „logikę w SwiftUI”.
- **Model audio**: `AudioPlayer` ma klarowny stan (co gra, czy live, czas/duration, rate) oraz sprzątanie observerów w `deinit`.
- **Lepsza odporność na awarie**: usunięcie `fatalError` z Core Data (`DataController`) — aplikacja nie wywraca się w runtime, tylko ma fallback.

### Rzeczy do dopracowania (bez zmiany „feature scope”, ale dla jakości kodu)
- **Cache a semantyka `no-store`**: `TyfloAPI` ma in‑memory cache (TTL + limity pamięci) dla odpowiedzi z `Cache-Control: no-store`. To jest świadome obejście dla UX — warto upewnić się, że nie dotyczy endpointów, gdzie `no-store` jest wymogiem prywatności/per‑user.
- **Logowanie a prywatność**: `Logger` jest wdrożony, ale utrzymuj zasadę „nie logujemy treści wiadomości/głosówek” i nie logujemy pełnych URL z query (obecnie jest helper do bezpiecznego logowania endpointów).
- **Try! w regex**: `ShowNotesParser` używa `try!` do kompilacji regex (praktycznie bezpieczne przy stałych patternach); jeśli chcesz dopiąć „zero `try!` w prod”, można to przerobić na bezpieczny fallback.

## 2) Optymalizacja (wydajność i responsywność)

### Potencjalne hot‑spoty
- **HTML → plain text w modelach**: wcześniej było kosztowne; teraz jest **memoizacja + szybka ścieżka** w `Podcast.PodcastTitle.plainText`. Jeżeli dalej pojawią się przycięcia, kolejnym krokiem jest pre‑computing plain‑text w warstwie VM (dla list) zamiast w widoku.
- **Cache / sieć**: obecnie:
  - WordPress requesty: `.useProtocolCachePolicy`,
  - endpointy „na żywo”: `reloadIgnoringLocalCacheData`,
  - dodatkowo in‑memory TTL cache dla `no-store`.
  Upewnij się, że to zachowanie jest OK dla oczekiwań „świeżości” w feedach (szczególnie jeśli serwer daje `no-store` na treści, które mają być zawsze live).

### Co już wygląda sensownie
- Paginacja i ładowanie partiami w feedach (`NewsFeedViewModel`, `PagedFeedViewModel`) ograniczają jednorazowe „przebranie” 100+ elementów.
- `SafeHTMLView.optimizeHTMLBody` ogranicza koszt obrazków (lazy/async) bez JS.

## 3) Bezpieczeństwo

### Aplikacja iOS
- **Transport**: endpointy są HTTPS, brak widocznych ATS‑wyjątków w `Tyflocentrum/Info.plist` (dobrze).
- **HTML**: `SafeHTMLView`:
  - non‑persistent `WKWebsiteDataStore`,
  - JS wyłączony,
  - linki otwierane poza webview,
  - whitelist schematów (`http/https/mailto/tel`) i ograniczenie nawigacji głównej do hosta bazowego.
  To jest jeden z najważniejszych punktów „hardeningu” w tej aplikacji — duży plus.
- **Upload głosówki**: `Tyflocentrum/TyfloAPI.swift` buduje `multipart/form-data` w pliku tymczasowym i sprząta go `defer` (OK). `VoiceMessageRecorder` usuwa nagranie po wysłaniu/reset.

### Backend push (`push-service/`)
- Publiczne endpointy rejestracji tokenów są OK dla MVP, ale:
  - absolutnie wymagane jest **rate limiting** na reverse proxy,
  - konieczne jest zabezpieczenie pliku stanu (`state.json`) i katalogu danych (dostęp tylko serwis/administrator),
  - docelowo rozważ trzymanie tokenów w storage z lepszym modelem (DB) + rotacja/TTL.
- **Kluczowe**: brak wysyłki do APNs (obecnie tylko logi) → push nie działa (i w tej wersji iOS jest to celowo „debug‑only”).

## 4) Prywatność i dane użytkownika

### Jakie dane przetwarza aplikacja (praktycznie)
- **Kontakt z radiem**:
  - imię/podpis (`ContactViewModel.name`),
  - treść wiadomości tekstowej (`ContactViewModel.message`),
  - plik audio głosówki + metadane (czas trwania).
- **Powiadomienia push (stan na dziś)**:
  - w buildzie **Release** UI i rejestracja są wyłączone, więc aplikacja nie powinna zbierać/zgłaszać tokenów push,
  - kod i preferencje nadal istnieją (debug‑only) pod przyszłe wdrożenie APNs.
- **Lokalnie na urządzeniu**: ulubione i ustawienia (UserDefaults).

### Konsekwencje pod App Store
- W App Store Connect przygotuj:
  - **Privacy Policy URL** (wymóg) + spójny opis retencji i celu danych (kontakt z radiem, głosówki),
  - „App Privacy” (kategorie danych i ich cel) — zgodnie z tym, co realnie wysyłasz na serwer.
- Jeśli planujesz włączać push po 1.0, uwzględnij to w roadmapie prywatności (tokeny/prefsy + retencja).

## 5) Testowalność i testy

### Co jest na plus
- Unit testy obejmują kluczowe elementy:
  - budowanie requestów i query (`TyflocentrumTests/TyfloAPITests.swift`),
  - `MultipartFormDataBuilder`,
  - modele i persystencję ustawień/ulubionych,
  - logikę feedów (paged/news),
  - aspekty audio session dla nagrywania,
  - regresje: `plainText`, cache policy i cache dla `no-store`.
- UI smoke testy mają sensowną strategię:
  - deterministyczne stubowanie sieci,
  - identyfikatory dostępności jako kontrakt testowy,
  - scenariusze awaryjne (stall/timeouts) i retry.

### Co bym dodał jako minimum „release confidence”
- Testy regresji dla:
  - `ShowNotesParser` (różne formaty znaczników czasu/linków),
  - `SafeHTMLView` (czy linki nie nawigują w webview, tylko otwierają zewnętrznie),
  - jeśli push wróci: `PushNotificationsManager` (kiedy prosi o zgodę / kiedy rejestruje token / co robi po odmowie).

## 6) Dostępność (VoiceOver, Dynamic Type, ergonomia)

### Co jest bardzo dobre
- Konsekwentne `accessibilityIdentifier` (UI tests + debug).
- Akcje dostępności na wierszach (np. „Słuchaj”, „Skopiuj link”, „Ulubione”).
- Wsparcie **Magic Tap** globalnie + w ekranie głosówek (dobry UX dla VO).
- Player ma osobne opisy kontrolek i wartości (czas, prędkość).

### Rekomendacje (raczej „polish”, nie blokery)
- Dopracować copy/hinty tam, gdzie UI jest „techniczne” (na dziś dotyczy głównie debug‑only fragmentów).
- Na iPad i Mac: „tryb ucha” (proximity) jest już ukryty/wyłączony (✅) — zostaje ogólny sanity‑check UX (układ, scroll, fokus, klawiatura).

## 7) Wytyczne Apple / publikacja w App Store (checklista praktyczna)

Poniżej jest lista rzeczy, które realnie weryfikuje review (stabilność, kompletność, prywatność, uczciwość opisu) oraz elementy, które często blokują submission na etapie App Store Connect.

### 7.1 Minimalne wymagania „submission-ready”
- App nie może crashować i musi być testowalny bez „tajnych kroków” (wszystkie feature’y dostępne, backendy działają).
- Wypełnione pola w App Store Connect:
  - nazwa, opis, kategoria, wiek,
  - zrzuty ekranu (iPhone + iPad, jeśli wspierasz iPad),
  - **Support URL** i **Privacy Policy URL**,
  - „App Privacy” zgodne z realnym działaniem aplikacji.
- Export compliance (szyfrowanie): aplikacja używa HTTPS/TLS; w App Store Connect trzeba odpowiedzieć na pytania eksportowe. Jeśli nie używasz własnej kryptografii, zwykle kwalifikujesz się do wyjątku (warto też rozważyć ustawienie `ITSAppUsesNonExemptEncryption = NO`, jeśli to pasuje do Twojej sytuacji).

### 7.2 Punkty ryzyka specyficzne dla Tyflocentrum
#### Powiadomienia push
- Status na dziś: push jest **wyłączone w Release** (debug‑only).
- Jeśli chcesz je włączyć w kolejnej wersji:
  - włącz capability **Push Notifications** dla bundle ID i dodaj entitlements,
  - backend musi faktycznie wysyłać do APNs (a nie tylko logować),
  - dopracuj moment pytania o zgodę + komunikaty w UI,
  - zaktualizuj „App Privacy”.

#### iPad i Mac
- iPad jest włączony w projekcie — do App Store potrzebujesz iPad screenshots i testu UI na dużych szerokościach.
- Jeśli chcesz, żeby aplikacja „dało się odpalić na Macu” bez blokowania:
  - w praktyce oznacza nie opt‑outować „iPad app on Mac” w App Store Connect i wykonać sanity‑testy UX,
  - unikaj eksponowania funkcji zależnych od sensorów iPhone’a (np. proximity/„tryb ucha”) na iPad/Mac — w tej wersji to jest już ukryte/wyłączone (✅).

#### Mikrofon (głosówki)
- `NSMicrophoneUsageDescription` jest — super.
- Upewnij się, że w opisie aplikacji / notatkach do review jest jasne:
  - po co mikrofon,
  - że nagrywanie jest inicjowane wyłącznie przez użytkownika,
  - do kogo trafia głosówka i jaka jest retencja (to już część polityki prywatności).

#### Treści zewnętrzne (WordPress + radio)
- W opisie App Store i w notatkach do review warto zaznaczyć:
  - skąd pochodzą treści (Tyflopodcast/Tyfloswiat/Tyfloradio),
  - że masz prawa do używania nazwy i treści (albo jesteś oficjalnym klientem/partnerem).

### 7.3 Notatki do App Review (co im napisać)
- Krótki opis przepływów:
  - gdzie jest player,
  - gdzie jest kontakt (i że pojawia się tylko podczas audycji interaktywnej),
  - że aplikacja jest projektowana pod VoiceOver.
- Jeśli jakaś funkcja zależy od „czy trwa audycja” lub backendu (kontakt, ramówka), daj im informację jak to przetestować lub zapewnij stabilny tryb testowy na czas review.

## 8) Rekomendowana lista działań przed wysyłką (priorytety)

### Blokery (jeśli dotyczy)
- App Store Connect: Privacy Policy URL + Support URL + poprawne „App Privacy” (na podstawie realnych danych).
- iPad: odpowiednie zrzuty ekranu + sanity‑check UI.

### Wysoki priorytet (polish pod stabilność i wizerunek)
- (Opcjonalnie) dodać `PrivacyInfo.xcprivacy` (jeśli wymagane przez aktualne zasady publikacji i/lub używane API).
- (Opcjonalnie) rozważyć `ITSAppUsesNonExemptEncryption` (jeśli kwalifikujesz się do wyjątku; i tak trzeba odpowiedzieć w App Store Connect).
- (Produktowo) jeśli chcesz wspierać uruchamianie na Macu: sanity‑testy „iPad app on Mac” (okno, scroll, fokus, skróty klawiaturowe w formularzach).

### Dodatkowe uwagi do kodu (do wdrożenia)
- ✅ Zamieniono `print(...)` na `Logger` i ograniczono logowanie URL (bez querystringów).
- ✅ `SafeHTMLView` reaguje na zmianę Dynamic Type.
- ✅ Cache `no-store` ma limity pamięci + testy ewikcji.
- ✅ Ujednolicono `IPHONEOS_DEPLOYMENT_TARGET`.
- ✅ `Podcast.formattedDate` zabezpieczone pod concurrency (lock wokół `DateFormatter`).
- (Opcjonalnie) `PodcastTitle.plainTextCache`: można dodać `totalCostLimit` (np. po długości stringa), jeśli w praktyce cache rośnie za bardzo pamięciowo.

### Niski priorytet (po wydaniu 1.0)
- Doprecyzować strategię cache (np. per‑endpoint TTL, cache invalidation) jeśli użytkownicy zgłaszają „nieaktualne” treści.
