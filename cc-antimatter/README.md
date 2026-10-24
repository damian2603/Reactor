# Project Infinity — Antimatter Controller v1 (completely rewritten)

An independent CC:Tweaked / Mekanism 1.20.1 Fission Reactor + SNA + SPS controller. This is NOT a patch of the legacy cc-mekanism script. Separate settings, safety coroutine, optimizer, monitor UI, and bounded logs. Old files remain untouched.

## Goals and mechanics

1. Prioritize avoiding a Fission Reactor meltdown. Observe real temperature, damage, coolant, heated coolant and nuclear waste, rather than turbine steam fill.
2. Maximize sustainable antimatter output. Use actual SPS getProcessRate(), SPS Polonium fill, sunlight and production reported by the Solar Neutron Activators.
3. Match burn rate to the Fissile Fuel produced by the user's Isotopic Centrifuge line. Inline Chemical Tank inventory is mandatory for accurate long-term calibration. Estimate fuel production as average actual burn plus net inventory change per game tick. Tank saturation censors readings: a full tank reveals only that production is at least current consumption, so the program probes carefully before settling. A valid estimate is retained until the operator requests RECAL rather than forgotten after a timeout.
4. Turbine is secondary. It may have 90–100% steam without directly triggering SCRAM. The controller still reacts when reactor cooling or heated-coolant removal actually fails.

At default 20 TPS, the fuel estimate is:
production_mB_per_tick = mean_actual_burn_mB_per_tick + delta_fuel_tank_mB / (elapsed_real_seconds * 20).
This is an estimate, not a direct measurement of the centrifuge. If server TPS differs, adjust ticksPerSecond in settings. Fast ~20-second drain monitoring and ~95-second steady production measurements are separate. A temporary drain of a large full tank is intentional for calibration, provided the reserve remains healthy.

Thermal model: expected_K ~ 373.15 + actual_burn * (2 * 1,000,000 / reactor_heat_capacity) for direct water cooling. With 1,736,000 J/K it predicts ~889 K at 448 burn and ~995 K at 540 burn, consistent with screenshots. The controller reads the reactor heat capacity, and defaults to a soft temperature ceiling of 1080 K and software SCRAM at 1135 K. No software-only mechanism can guarantee against crashes, unloaded chunks, disconnections or meltdowns. **Keep a separately wired Fission Logic Adapter hardware SCRAM.**

## Research sources and modpack considerations

- [Mekanism Fission 1.20.x source](https://github.com/mekanism/Mekanism/blob/1.20.x/src/generators/java/mekanism/generators/common/content/fission/FissionReactorMultiblockData.java): getActualBurnRate is the actual fuel use; reactor's cooling and output buffers determine thermal safety.
- [Mekanism Turbine 1.20.x source](https://github.com/mekanism/Mekanism/blob/1.20.x/src/generators/java/mekanism/generators/common/content/turbine/TurbineMultiblockData.java): Dumping Excess retains steam to the configured percentage and has a finite venting rate.
- [Project Infinity generators.toml](https://github.com/BOLTMAGIC/Project-Infinity-0.1/blob/main/config/Mekanism/generators.toml): fission energy 1,000,000 J/mB, casing thermal capacity 1000 J/K per casing, meltdowns enabled.
- [Project Infinity general.toml](https://github.com/BOLTMAGIC/Project-Infinity-0.1/blob/main/config/Mekanism/general.toml): dumpExcessKeepRatio=0.9.
- [cc-mek-scada reactor-plc/spctl.lua](https://github.com/MikaylaFischler/cc-mek-scada/blob/main/reactor-plc/spctl.lua): fuel trend, hysteresis, concurrent reactor queries and ramps. Unlike power-generation SCADA, this new controller optimizes SPS antimatter and sustained fissile supply.
- [cc-mek-scada supervisor/unit_logic.lua](https://github.com/MikaylaFischler/cc-mek-scada/blob/main/supervisor/unit_logic.lua): distinguishes steam relief valve mode from actual turbine flow obstruction.
- Project Infinity includes Mekanism Extras / Evolved Mekanism / Compact Mekanism Machines / Integrated Mekanism. The [Mekanism Extras addon config](https://github.com/BOLTMAGIC/Project-Infinity-0.1/blob/main/config/MekanismExtras/generator_extras.toml) includes a Naquadah Reactor, which is NOT equivalent to the standard Mekanism Fission reactor. [Integrated Mekanism config](https://github.com/BOLTMAGIC/Project-Infinity-0.1/blob/main/config/integratedmekanism-common.toml) allows additional chemical transport. This program only assumes the verified standard Fission peripheral API, not addon-specific reactor physics.

The manually set Flux Point reference (default 22 MFE/t) is NOT a real SPS power measurement. The theoretical energy cap is approximately 0.055 mB antimatter per tick at 22 MFE/t, if the coils are actually supplied. Changes to burn are judged by actual SPS AM production and Polonium fill. With 430 mB/t actual fissile production, stable operation around 430 is preferable to setting 550 and draining the fuel tank.

## Near-full Elite Chemical Tank: oscillating but steady is normal

The user's observed tank reading **1,023,465 / 1,024,000 mB** is
**99.9478% full**: its gap is only **535 mB**. That gap is comparable
to one tick of a ~535 mB/t Fission Reactor burn rate, suggesting
a tick/transfer-cycle offset, not a sustained deficit. This is a
diagnostic possibility, not proof of the precise pipe transfer order.

With healthy supply, the amount can settle at a slightly different
near-full equilibrium for *every burn rate*, moving up and down by
tens or hundreds of mB as adjacent inventory transfers occur.
A different stable level after changing burn is NOT evidence that
the maximum Fissile Fuel production rate was found.

The new diagnostic line reads:
`Fuel: NEAR FULL: BURN SUPPORTED, MAX UNKNOWN | gap 535 mB`.
It means the amount stayed near full across a sampled window and
its net drift was smaller than a small noise deadband. The tank
can sustain current burn, but actual maximal centrifuge throughput
is still unknown because incoming supply may be throttled by
backpressure. AUTO remains free to probe higher while SPS and
reactor safety permit. A sustained negative slope with clearly
falling tank inventory and enough time below the full-tank
censoring band is required to infer a true production limit.

`fuelNet` should be judged over multi-second windows, not from
the raw GUI number every tick. Individual positive and negative
samples do not establish sustained fuel surplus or starvation.
The former controller's assumption that zero tank trend meant
an exact fuel-production ceiling would be incorrect here.

## 2026-10-24: empirical review of user's 104-row `history.csv`

We received **104 rows covering 26.58 minutes** of real in-game
telemetry from the first `cc-antimatter` controller. The source
recorded burn **499–575 mB/t**, mean AM rate **0.05503 mB/t**,
minimum coolant **92.8%**, and maximum temperature **1035.5 K**.
Maximum absolute difference between observed and predicted reactor
temperature was only **0.1 K**; heated-coolant fill stayed below
**0.9%** and nuclear waste was **0%** in these snapshots.

Twelve rows explicitly report
`REACTOR COOLANT/OUTPUT BACKPRESSURE`. In each, reactor coolant
was **92.8–94.9%**, but there was no corresponding high heated-coolant
or waste pressure. The old `coolantWarn=0.95` overreacted to
this ordinary circulation fluctuation. The old ramp controller
could request **+12 mB/t every 6 seconds** and cut **−38 mB/t**;
logs therefore displayed jumps like 575 → 511 → 547.

**Even more importantly, all 104 rows satisfy the exact identity:**

```text
Elite Chemical Tank amount = 1,024,000 - getActualBurnRate()
```

Examples: 535 burn → 1,023,465 stored; 550 burn →
1,023,450 stored; 575 burn → 1,023,425 stored. This is strong
evidence of a **one-tick fuel transport gap**, not evidence that
the centrifuge was underproducing. Raw tank inventory derivatives
can become falsely negative simply because burn increased, and
would poison a model that attempts to estimate supply from raw
inventory. This identity was checked for all 104 real samples;
the *cause* (tick/pipe transfer order) remains an inference.

**Revised control (regression-tested):**

- Actuator normally changes by **+1 mB/t per command**, or trims
  **−2 mB/t**; minimum 2 seconds between regular commands.
  Configure `rampStep=0.5` if even smaller steps are desired.
  Larger immediate safety trims are reserved for *clearly severe*
  reactor cooling, temperature or waste problems.
- A coolant dip from 100% to **92.8%** no longer automatically
  drops burn. At/below **92%**, AUTO pauses an increase and
  observes for several seconds. Persistent coolant below **88%**
  leads to controlled reductions; below **80%** accelerates
  reduction. Independent software SCRAM at **65% coolant**,
  1135K temperature, true outlet backing-up or reactor damage
  remains in effect.
- After **5 separate corroborating observations**, the controller
  detects `capacity - tankAmount ≈ actualBurn` while nearly
  full. It then computes fuel-balance trends from
  `min(capacity,tankAmount + actualBurn)`, removing this
  reproducible 1-tick transfer gap **in the model only**.
  No change is made to the actual tank or Mekanism pipes.
- While this corrected amount is saturated, no exact *maximum*
  upstream production rate is claimed. Only if an additional,
  accumulating deficit appears beyond the 1-tick gap can the
  controller infer that the Isotopic Centrifuge line cannot
  sustain its burn.
- The monitor explicitly says
  `1-TICK GAP: BURN SUPPORTED, MAX UNKNOWN` for a
  stable corrected tank.

The tests now include a **104-row replay** of the user's exact
burn/coolant pattern, a sustained 87.5% coolant case that
first holds and only gradually trims, and an actual **520 mB/t
fuel-production shortage** superimposed on the one-tick gap.
All scenarios continue to test independent reactor protection,
SPS output and complete turbine irrelevance.

## Installation

**A fresh CC computer is recommended.** The old one had only ~2–6KB free. The new controller needs ~32KB for program modules, plus a free reserve for settings and history. This installer refuses to delete or overwrite old cc-mekanism files.

1. Stop the OLD controller. Never let two CC computers adjust the same Fission Reactor simultaneously. Preserve your separately wired hardware SCRAM.
2. Connect the Fission Reactor, SPS, all 6 SNAs, inline Fissile Fuel Chemical Tank, and advanced monitor through wired modems. Turbine connection is optional.
3. Install using:

    wget run https://raw.githubusercontent.com/damian2603/Reactor/main/cc-antimatter/install.lua

4. Start the NEW program:

    cc-antimatter/main

5. It **always starts in MANUAL and never activates the reactor**. Confirm health status and peripherals. Start the reactor manually using your existing verified startup procedure. Enable AUTO with keyboard A or the monitor AUTO button.

Do not run the old cc-mekanism/controller while this program is active.

## Touchscreen and keyboard

Bottom monitor controls: [AUTO] [MAN] [SCRAM] [FE-] [FE+] [CAP-] [CAP+] [RECAL].
- FE buttons change the **recorded Flux Point limit by 1 MFE/t**. Match the actual Flux Point manually; this is not a hardware setting.
- CAP buttons adjust the user burn ceiling by 25 mB/t. Default is 550.
- RECAL (or keyboard R) discards learned fuel capacity after upgrading the fuel production line, and starts a new measured search.
- A = AUTO; M = MANUAL; X/S = SCRAM; Q = exit with SCRAM attempt; +/- in MANUAL = burn +/-5 mB/t.
- The monitor uses differential line updates instead of clearing the entire screen on every sample.

If multiple chemical tanks or reactors are on the network, automatic selection will fail safe. The program prefers the only Chemical Tank whose stored chemical name contains fissile. Otherwise edit the new cc-antimatter/settings text file and specify the actual peripheral names, e.g. a Lua table with reactor="...", sps="...", fuelTank="...", monitor="...", userCap=550, fluxFE=22000000, ticksPerSecond=20. Find real names with peripheral.getNames(); sample names are not guaranteed IDs. Then restart.

Settings are stored at cc-antimatter/settings. History is cc-antimatter/history.csv (bounded to about 90KB plus one previous segment, skipped on low disk rather than crashing the control process).

## Independent safety policy

No automatic reactor START on reboot. SCRAM on: measured damage, temperature >=1135K, coolant <=65%, heated coolant >=88%, waste >=91%, dangerous rapid loss of coolant or thermal runaway. Start reducing burn earlier if coolant falls below 95%, heated coolant grows above 55%, or waste above 65%. Turbine steam percentage is purely a diagnostic; if steam buildup causes genuine cooling failure, reactor-level safety triggers. Three consecutive failed fast safety snapshots while reactor may be active trigger SCRAM. On program error or operator exit, SCRAM is attempted.

The software thresholds and modeling are conservative **beta defaults**. Safety hardware is essential. Check the real world at low burn before using AUTO or adjusting maximum burn.

## Tests

.github/workflows/cc-antimatter-tests.yml runs syntax validation, 430/500/600 mB/t Fissile Fuel supply simulations (including starting with a completely full tank), sustained convergence, independent safety trips, zero direct steam-only trip, and simulated Mekanism reactor, tank, SPS, SNA and turbine peripherals. These tests do not substitute for in-game commissioning.
