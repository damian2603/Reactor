# 4.3 — Duże reaktory i setki Fuel Cells
- Naprawiono przycisk „Zastosuj nowe wymiary”: dotychczas przycinał wymiary do 12 i wnętrze do 400 pól.
- Edytor pozwala na 16×16×16 (wnętrze 2744 pól), a pole Fuel Cells do 1400.
- Dodano nowy, szybszy algorytm wielowątkowy do dużych reaktorów FE/t, obsługujący setki ogniw i pasywne Redstone Heat Sinki.
- Poprawiono krytyczny błąd walidatora: puste pola i bloki rdzenia nie powinny podlegać limitowi 999 sztuk.
- Domyślne limity pasywnych chłodnic podniesiono do 9999; wpisane przez użytkownika mniejsze limity są nadal respektowane.
- Wyniki dużych Workerów podlegają ponownej walidacji przez główny symulator.
- Duży tryb obecnie obsługuje FE/t, bez gwarancji globalnego optimum. Pozostałe cele dla wielkich wnętrz są jawnie ograniczone.

# 4.1 (GitHub Pages)

- Równoległe, niezależne wyszukiwania Web Workers (1–4).
- Symmetry/rotation pruning z zachowaniem osi pionowej.
- Tabu Search dla lokalnego strojenia chłodnic.
- Warianty Pareto z crowding-distance przy ograniczeniu liczby zapisanych projektów.
- Kontrola kandydata z Workera przez główny symulator.
- Pakiet do publikacji na GitHub Pages.
# 4.2 — Generator FE/t i pełna baza paliw

- Naprawiony tryb maksymalizacji FE/t w przeglądarce i Web Workers.
- Układy energetyczne mogą pracować z 0 Irradiatorów i 0 Irradiation Lines.
- Osobne mutacje i losowanie rdzenia Fuel Cells / moderatorów dla FE/t.
- Ranking i archiwum prezentują FE/t zamiast nieadekwatnej produkcji Neutronium.
- Automatyczne przełączenie liczby Irradiatorów na 0 w trybie energii oraz powrót do wcześniejszych ustawień po zmianie celu.
- Wspólna baza 136 odmian paliw NuclearCraft, w tym automatycznie obliczane irradiation.
- Pamiętaj: FE/t to przewidywanie, ostateczny wynik należy potwierdzić w Designerze.
