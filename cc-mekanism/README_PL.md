# Sterownik reaktora Mekanism — Project Infinity

Wersja 3.0 (eksperymentalna, regulator SPS/Antimatter z monitorowaniem Solar Neutron Activatorów). Wymaga CC:Tweaked oraz połączenia **Wired Modem** z blokami: **Fission Reactor Logic Adapter**, **Turbine Valve**, **SPS Port** oraz **wszystkimi Solar Neutron Activatorami**, **Boiler Valve**, **Induction Matrix Port**. Do sterowania dotykiem można dołączyć Advanced Monitor.

## Instalacja i aktualizacja

W konsoli komputera CC:Tweaked wpisz:

    wget run https://raw.githubusercontent.com/damian2603/Reactor/main/cc-mekanism/install.lua

Następnie:

    cc-mekanism/monitor-test
    cc-mekanism/probe
    cc-mekanism/controller

Program wykrywa maszyny na sieci modemowej, jeżeli danej klasy maszyny jest tylko jedna. W przypadku wielu reaktorów/turbin wpisz konkretne nazwy peripheralów w pliku **/cc-mekanism/settings**. Skrypt **probe** zapisuje listę dostępnych metod i danych w **/cc-mekanism/probe.txt**.

## Automatyczne wykrywanie rozmiarów

Nie podajesz ręcznie wielkości reaktora, turbiny ani SPS. Program odczytuje:
- reaktor: długość/szerokość/wysokość, Fuel Assemblies, maksymalny burn rate, boil efficiency i zbiorniki;
- turbina: wymiary, liczbę łopatek, cewek, kondensatorów, wentylatorów, limit przepływu pary i maksymalną produkcję;
- SPS: wymiary, liczbę cewek, poziom Polonium/Antimatter, rzeczywistą produkcję Antimatter/t;
- wszystkie Solar Neutron Activatory: aktualny potencjał produkcyjny Polonium/t (z uwzględnieniem pogody i słońca), maksymalne tempo oraz zapełnienie zbiorników;
- opcjonalnie boiler i Induction Matrix.

AUTO ma domyślnie **autoBurnCeiling=0**, co oznacza dostosowanie do odczytanego maksimum reaktora, z dodatkowym ograniczeniem wynikającym z **realnej wydajności turbiny**, o ile program zebrał już odpowiednie próbki. Regulacja narasta stopniowo (domyślnie 0,5% max burn rate co 15 sekund, min. 0,1 mB/t). Na początku brak wyuczonych parametrów przepływu, dlatego działanie w AUTO wymaga obserwacji.

## Sterowanie

- **M** — MANUAL; **F** — AUTO FE; **P** — AUTO SPS;
- **B** — ustaw burn rate; **+/-** — zmiana ręczna;
- **C** — dodatkowy limit AUTO; **0** = znowu automatycznie wg możliwości maszyny;
- **S** — SCRAM; **R** dwa razy — ręczna aktywacja po kontroli bezpieczeństwa;
- **Q** — wyjście z próbą SCRAM.

Ustawienia: **/cc-mekanism/settings**. Historia: **/cc-mekanism/history.csv**.



## AUTO SPS — domyślnie najważniejszy tryb optymalizacji

**Kluczowa zależność w Project Infinity:**

- Fission Reactor spala 1 mB Fissile Fuel i tworzy 1 mB Nuclear Waste.
- Receptura Solar Neutron Activatora: **10 mB Nuclear Waste → 1 mB Polonium**.
- SPS wymaga **1000 mB Polonium → 1 mB Antimatter**, przy koszcie **1 000 000 J za 1 mB przetworzonego Polonium**.
- Paczka ma konwersję **2,5 J = 1 FE**, więc uzyskanie 1 mB Antimatter to około **400 milionów FE**.

Przykład: burn rate 400 mB/t umożliwia 0,040 mB Antimatter/t, pod warunkiem że aktywatory i SPS mają odpowiednią wydajność. Dla burn 1920 mB/t potencjał wynosi 0,192 mB/t, ale najczęściej ograniczają go transport odpadów, aktywatory, turbina lub FE dostarczane do cewek SPS.

Tryb **P / AUTO SPS**:

1. Skanuje wszystkie Solar Neutron Activatory widoczne w sieci CC. Każdy aktywator musi mieć **Wired Modem** przyczepiony do boku (nie zasłaniaj miejsca nad nim); wszystkie modemy połącz Networking Cable z komputerem.
2. Sumuje `getProductionRate()`, uwzględniając słońce/pogodę/biom, i oblicza przepustowość odpadów: `10 × sum(getProductionRate())` mB/t. Przyjmuje 92% tej wartości, żeby pozostawić niewielki zapas.
3. Uwzględnia `getMaxBurnRate()`, wydajność przepływu pary/ograniczenia chłodzenia oraz opcjonalny limit ustawiony przez użytkownika.
4. Zwiększa burn rate stopniowo w odstępach 12 s, dopóki pozwalają na to realne warunki. Ogranicza spalanie, gdy rosną odpady, blokują się zbiorniki Polonium, SPS przetwarza za wolno lub nie można już odprowadzić pary.
5. Gdy Solar Neutron Activatory mają `getProductionRate()=0` (np. noc) — obniża burn rate do 0, aby nie produkować Nuclear Waste bez możliwości przerobienia.
6. Pokazuje `getProcessRate()` SPS jako faktyczną produkcję antimaterii/tick, potencjalne wartości i diagnozę wąskiego gardła: `SPS COIL FE / PROCESSING LIMIT`, `POLONIUM PIPE`, `SNA TOO SLOW`, `TURBINE STEAM FLOW LIMIT`, itd.

Program nie może sam zmieniać ilości energii dostarczanej przez kable do SPS, ale z szybkości produkcji i poziomu Polonium identyfikuje prawdopodobny problem z zasilaniem albo transferem. **Nie interpretuje samej produkcji turbiny jako wystarczającej ilości FE w SPS** — to oddzielne systemy.

**Wymagane:** podłączenie wszystkich Solar Neutron Activatorów do sieci CC. W razie braku telemetrycznych odczytów opcja P odmówi rozpoczęcia automatyzacji (domyślne `spsNoSolarHold=true`). Tryb MANUAL i AUTO FE nadal są dostępne. Zabezpieczenia termiczne i poziomu Nuclear Waste pozostają aktywne. Nie ma automatycznego restartu wyłączonego reaktora.

**Dane na panelu:** liczba aktywnych aktywatorów, potencjał Polonium/t, prawdziwe Antimatter/t, szacowane zużycie FE SPS i produkcja turbiny poprawnie przekonwertowana z dżuli na FE. Wartości w FE/t są szacunkowe dla SPS (wynikają z produkcji), ponieważ standardowe API SPS nie udostępnia bezpośredniego odczytu energii doprowadzonej do cewek.

## AUTO FE 2.2 — regulacja według produkcji energii

Najważniejszy odczyt to **Turbine Production Rate / Max Production**. Podczas AUTO FE komputer dąży do **95% maksymalnej mocy turbiny** (zmiana klawiszem **T**, zakres 20–100%), porównuje zmierzoną produkcję z celem i zwiększa burn rate stopniowo. Stosuje wygładzanie pomiarów i **co najmniej 12 sekund stabilizacji po zmianie nastawy**. Maksymalny burn rate nadal pochodzi z reaktora, a przy chłodzeniu wodą dodatkowy pułap szacowany jest z faktycznego stosunku Steam/Burn i maksymalnego przepływu turbiny.

**Zwykły wzrost pary oraz jej zapełnienie np. 72,5% nie powodują już throttlingu.** Steam to sygnał bezpieczeństwa: przy około 89% program wstrzymuje zwiększanie burn rate; przy około 93% i braku spadku bufora ostrożnie obniża burn; przy 95% wykonuje SCRAM (domyślne progi nowej wersji). Takie progi NIE oznaczają gwarantowanego bezpieczeństwa — kontroluj przepływ chłodziwa i fizyczne zabezpieczenia.

Program **nie zwiększa spalania w nieskończoność**, jeżeli energia z turbiny nie jest odbierana: napełnienie bufora energii >93% oznacza ograniczony odbiór i powoduje wyhamowanie burn rate. Jeśli podłączysz Induction Matrix, jego odczyty są również pokazywane na panelu. Produkcja turbiny a energia faktycznie dostarczona odbiornikom to różne wielkości.

AUTO SPS nadal uwzględnia zapełnienie zbiorników Polonium / Antimatter, ale stosuje ten sam bazowy regulator mocy; połączenie z maszynami produkującymi Polonium nie jest jeszcze źródłem szczegółowej telemetrii przepustowości.

**Skróty:** `F` AUTO FE, `P` AUTO SPS, `M` MANUAL, `B` burn rate, `C` dodatkowy limit burn, **`T` procent docelowej produkcji turbiny**, `S` awaryjny SCRAM.

Jeśli przechodzisz z wersji 2.1, instalator zachowuje istniejący plik `settings`. Automatycznie zmienia tylko dawne, oryginalne wartości domyślne `steamTrip=0.86` i `steamWarn=0.65`, pozostawiając indywidualnie zmienione progi.

## Ważne ograniczenia

Odczytanie rozmiarów nie oznacza, że da się matematycznie poznać pełną przepustowość **wszystkich rur, pomp, Solar Neutron Activators czy przetwarzania Nuclear Waste do Polonium**. Program wyciąga wnioski z napełnienia zbiorników i dynamiki ich zmian. Przy chłodzeniu sodowym warto podłączyć również Boiler Valve — nie należy utożsamiać ciepła z reaktora z ilością pary na wejściu turbiny.

**W tej paczce meltdown jest włączony.** Sterownik nie jest zastępstwem dla niezależnego zabezpieczenia reaktora (Mekanism Fission Reactor Logic Adapters). Awaria CC, brak prądu, rozładowanie chunka lub przerwanie połączenia nie może być jedynym kryterium bezpieczeństwa. Tryb AUTO **nigdy sam nie uruchamia** wyłączonego reaktora.

Kod był sprawdzony względem udokumentowanych metod Mekanism 1.20.1, **ale nie został jeszcze przetestowany w działającym świecie Project Infinity**.


## Jeśli Advanced Monitor jest czarny

Uruchom **cc-mekanism/monitor-test** w innej zakładce konsoli albo na drugim komputerze podłączonym do tej samej sieci. **Uwaga: klawisz Q w sterowniku próbuje wykonać SCRAM i wyłączyć reaktor!** Wychodź przez Q tylko wtedy, gdy planujesz jego zatrzymanie. Test wypisze nazwy wszystkich widocznych urządzeń i wyświetli niebieskie tło z napisem **MONITOR CONNECTED!** na każdym wykrytym monitorze. Jeśli w konsoli pojawi się **NO MONITOR FOUND**, monitor nie jest widoczny w sieci — zamontuj **Wired Modem** na monitorze, połącz go kablem **Networking Cable** z modemem komputera i kliknij PPM na modemie, aby udostępnić urządzenie. Monitor dotykowy wymaga Advanced Monitor; zwykły monitor wyświetla dane bez obsługi dotyku.

Jeśli widocznych jest kilka monitorów, w pliku **/cc-mekanism/settings** ustaw np. `monitor = "monitor_0"`, używając rzeczywistej nazwy z diagnostyki. Sterownik automatycznie wyszukuje pojedynczy monitor również w trakcie działania i wyświetla jawny komunikat o błędzie renderowania.
