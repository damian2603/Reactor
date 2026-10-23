# Project Infinity Reactor Studio 4.1

Generator reaktorów dla **NuclearCraft: Neoteric 1.20.1 / Project Infinity 0.1**.

## Uruchomienie GitHub Pages
1. Stwórz **publiczne** repozytorium na GitHub.
2. Prześlij do jego katalogu głównego pliki `index.html`, `optimizer.worker.js`, `.nojekyll` (wszystkie z tego ZIP).
3. Otwórz **Settings → Pages → Build and deployment → Deploy from a branch → main → /(root) → Save**.
4. Otwórz adres `https://TWOJ-LOGIN.github.io/NAZWA-REPO/`.

`index.html` działa offline, jednak **Web Workers wymagają uruchomienia przez HTTP(S)**; w trybie `file://` aplikacja automatycznie przełącza się na silnik jednowątkowy. Podczas lokalnego programowania możesz użyć `python -m http.server 8000`.

## Algorytm
- 1–4 Web Workers prowadzą niezależne, równoległe przeszukiwania. Wysyłają kandydatów do wątku interfejsu.
- Każdy kandydat jest **ponownie walidowany** na głównym wątku przed przyjęciem.
- Symmetry-pruning ignoruje odbicia i obroty poziome zachowujące wymiary. Nie zamienia wysokości z szerokością.
- Tabu tenure ogranicza bezproduktywne cofanie zamian chłodnic.
- Archiwum wariantów pozostaje Pareto; crowding-distance utrzymuje różnorodność przy obcinaniu pojemności. To jeszcze nie pełny NSGA-II (brak pełnej selekcji populacji według rang NSGA-II).

## Ważne ograniczenia
- Wyszukiwanie heurystyczne **nie dowodzi globalnego maksimum**.
- Nie każda konfiguracja moda/paczki jest obsługiwana. Zawsze potwierdzaj aktywność bloków i Heat/t, Cooling/t w Designerze.
- Web Workers zwiększają przepustowość optymalizacji zależnie od sprzętu i limitu pamięci; 4 wątki nie oznaczają automatycznie 4x wydajności.
- Dane wsadowe są osadzone w `index.html` i `optimizer.worker.js`; w razie aktualizacji konfiguracji paczki oba muszą zostać odświeżone.
- Działa bez serwera backend; eksportowane NBT/MBTool wymagają testu w kopii świata.

## Aktualizacje i testy
Uruchom test regresji w interfejsie. Sprawdź import i eksport NBT/Building Gadgets 2.