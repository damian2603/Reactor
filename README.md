# Project Infinity Reactor Studio 4.2

Generator reaktorów dla **NuclearCraft: Neoteric 1.20.1 / Project Infinity 0.1**.

## Uruchomienie GitHub Pages
1. Stwórz **publiczne** repozytorium na GitHub.
2. W katalogu głównym umieść `index.html`, `optimizer.worker.js`, `fuel_data.js`, `fuel_ui.js`, `fe_optimizer.js` i `.nojekyll`.
3. Otwórz **Settings → Pages → Build and deployment → Deploy from a branch → main → /(root) → Save**.
4. Otwórz adres `https://TWOJ-LOGIN.github.io/NAZWA-REPO/`.

`index.html` działa offline, jednak **Web Workers wymagają uruchomienia przez HTTP(S)**; w trybie `file://` aplikacja automatycznie przełącza się na silnik jednowątkowy. Podczas lokalnego programowania możesz użyć `python -m http.server 8000`.

## Optymalizacja produkcji FE/t (nowość 4.2)
1. Wybierz w sekcji **Cel generatora → Maksymalna produkcja FE/t**.
2. Tryb automatycznie ustawia **0 Irradiatorów** — reaktor energetyczny nie wymaga Irradiation Chambers. Wartość moderacji 100% jest korzystna dla FE, ale możesz ją zmienić.
3. Ustaw paliwo, rozmiar, limit Fuel Cells, zapas chłodzenia i liczbę prób; uruchom **Run**.
4. W wynikach zobaczysz **FE/t**, Fuel Cells i Net Heat. Kliknij wariant, aby obejrzeć warstwy, a potem wyeksportuj projekt jako NBT/MBTool.
5. Wynik FE/t jest **modelem stabilnego, wychłodzonego reaktora przy 100% reactivity**, obliczanym z logiki Neoteric i mnożników Project Infinity. Rzeczywista produkcja może się zmieniać podczas rozruchu, przy zgromadzonym cieple i innych stanach maszyny. Przed uruchomieniem potwierdź wartości w grze.

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
- Katalog paliw jest współdzielony przez stronę i Workery w `fuel_data.js`. Zależności chłodnic i domyślne presety nadal znajdują się w `index.html`/`optimizer.worker.js`.
- Działa bez serwera backend; eksportowane NBT/MBTool wymagają testu w kopii świata.

## Aktualizacje i testy
Uruchom test regresji w interfejsie. Sprawdź import i eksport NBT/Building Gadgets 2.