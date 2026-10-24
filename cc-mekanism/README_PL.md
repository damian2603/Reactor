# Sterownik reaktora Mekanism — Project Infinity

Wersja 2.2 (eksperymentalna, regulator produkcji FE). Wymaga CC:Tweaked oraz połączenia **Wired Modem** z blokami: **Fission Reactor Logic Adapter**, **Turbine Valve** i opcjonalnie **SPS Port**, **Boiler Valve**, **Induction Matrix Port**. Do sterowania dotykiem można dołączyć Advanced Monitor.

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
- SPS: wymiary, liczbę cewek, poziom Polonium/Antimatter, przetwarzanie;
- opcjonalnie boiler i Induction Matrix.

AUTO ma domyślnie **autoBurnCeiling=0**, co oznacza dostosowanie do odczytanego maksimum reaktora, z dodatkowym ograniczeniem wynikającym z **realnej wydajności turbiny**, o ile program zebrał już odpowiednie próbki. Regulacja narasta stopniowo (domyślnie 0,5% max burn rate co 15 sekund, min. 0,1 mB/t). Na początku brak wyuczonych parametrów przepływu, dlatego działanie w AUTO wymaga obserwacji.

## Sterowanie

- **M** — MANUAL; **F** — AUTO FE; **P** — AUTO SPS;
- **B** — ustaw burn rate; **+/-** — zmiana ręczna;
- **C** — dodatkowy limit AUTO; **0** = znowu automatycznie wg możliwości maszyny;
- **S** — SCRAM; **R** dwa razy — ręczna aktywacja po kontroli bezpieczeństwa;
- **Q** — wyjście z próbą SCRAM.

Ustawienia: **/cc-mekanism/settings**. Historia: **/cc-mekanism/history.csv**.


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
