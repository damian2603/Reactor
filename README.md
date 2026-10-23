# Project Infinity Reactor Studio 4.4

Generator reaktorów dla **NuclearCraft: Neoteric 1.20.1 / Project Infinity 0.1**.

## Uruchomienie GitHub Pages
1. Stwórz **publiczne** repozytorium na GitHub.
2. W katalogu głównym umieść `index.html`, `optimizer.worker.js`, `large_energy.worker.js`, `large_irradiation.worker.js`, `fuel_data.js`, `fuel_ui.js`, `fe_optimizer.js` i `.nojekyll`.
3. Otwórz **Settings → Pages → Build and deployment → Deploy from a branch → main → /(root) → Save**.
4. Otwórz adres `https://TWOJ-LOGIN.github.io/NAZWA-REPO/`.

`index.html` działa offline, jednak **Web Workers wymagają uruchomienia przez HTTP(S)**; w trybie `file://` aplikacja automatycznie przełącza się na silnik jednowątkowy. Podczas lokalnego programowania możesz użyć `python -m http.server 8000`.

## Optymalizacja produkcji FE/t (nowość 4.2)
1. Wybierz w sekcji **Cel generatora → Maksymalna produkcja FE/t**.
2. Tryb automatycznie ustawia **0 Irradiatorów** — reaktor energetyczny nie wymaga Irradiation Chambers. Wartość moderacji 100% jest korzystna dla FE, ale możesz ją zmienić.
3. Ustaw paliwo, rozmiar, limit Fuel Cells, zapas chłodzenia i liczbę prób; uruchom **Run**.
4. W wynikach zobaczysz **FE/t**, Fuel Cells i Net Heat. Kliknij wariant, aby obejrzeć warstwy, a potem wyeksportuj projekt jako NBT/MBTool.
5. Wynik FE/t jest **modelem stabilnego, wychłodzonego reaktora przy 100% reactivity**, obliczanym z logiki Neoteric i mnożników Project Infinity. Rzeczywista produkcja może się zmieniać podczas rozruchu, przy zgromadzonym cieple i innych stanach maszyny. Przed uruchomieniem potwierdź wartości w grze.

## Duże reaktory do 16×16×16 (4.4) — FE/t oraz Irradiation
1. Wybierz cel: **Maksymalna produkcja FE/t**, **Irradiation Lines** lub **Neutronium/min**. Włącz **Web Workers** i uruchom przez GitHub Pages (nie `file://`).
2. Wpisz **16 × 16 × 16** i kliknij **Zastosuj nowe wymiary**. Wnętrze ma wtedy **14 × 14 × 14 = 2744** pola.
3. Ustaw **Maks. Fuel Cells** na 344 (lub inny limit). **To wartość maksymalna**, nie wymaganie wykorzystania dokładnie tylu ogniw.
4. Dla **FE/t** kliknij **Run** — szybki konstruktor dobiera Fuel Cells i pasywne Redstone Heat Sinki. Dla **Irradiation/Neutronium** ustaw np. HEU-235, moderację 0%, limit 8 Irradiatorów, włącz automatyczny dobór maszyn i kliknij **Run**. Generator łączy prawidłowe **Fuel Cell → Moderator → Irradiation Chamber** z chłodnicami, przechodząc od rzadszych do gęstszych rdzeni.
5. Wyniki z Workerów są zawsze ponownie przeliczane przez główny silnik, sprawdzający reguły chłodnic i Net Heat. Bezpieczne konfiguracje można eksportować do MBTool.
6. Dla wnętrz do **220 pól** działa dokładniejsze wyszukiwanie memetyczne. Dla większych uruchamiają się osobne szybkie algorytmy **FE/t** i **Irradiation/Neutronium**. Duży tryb Irradiation wykorzystuje na razie pasywne Redstone, Cryotheum, Quartz, Cobalt, Liquid Helium, Magnesium i Boron Heat Sinki, nie wszystkie chłodnice ani globalny solver. Wyniki są dalej walidowane przez wspólny symulator przed dodaniem do archiwum.

**Przykład — 16×16×16 dla Neutronium:** wybierz `Neutronium/min`, `HEU-235`, `Moderation 0%`, `Maks. Fuel Cells 344`, `Pracujące Irradiatory 8`, zaznacz automatyczny dobór, `2 Web Workers` i `400–1200 prób`. W wynikach zobaczysz projekty z aktywnymi liniami oraz oszacowanie Neutronium/min.

**Uwaga:** liczby Fuel Cells, produkcja FE/t i margines chłodzenia są prognozą symulatora. W grze sprawdź rzeczywistą produkcję, moderację i aktywność chłodnic; model nie gwarantuje maksimum globalnego ani nie uwzględnia każdej sytuacji pracy.

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