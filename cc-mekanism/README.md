# Project Infinity: Mekanism Fission / Turbine / SPS controller

Standalone ComputerCraft / CC:Tweaked controller for **Mekanism Fission Reactor + Industrial Turbine + SPS**, developed for Minecraft 1.20.1 / Project Infinity 0.1. The separate NuclearCraft optimizer in this repository is untouched.

**Status: v4 beta experimental (autodetection of multiblock sizes).** Tested against inspected Mekanism API source, **not yet validated in an actual running Project Infinity world**. Do not rely on this program as your only reactor safety mechanism.

## v4 beta — SPS-first adaptive controller (2026-10-24)

This section supersedes the older v2/v3 and Beta 1 descriptions below where they conflict.

**Objective:** raise antimatter production as far as the measured SPS processing,
Solar Neutron Activators, turbine/boiler heat handling, and sustained Fissile Fuel
production permit. When the SPS does not use added polonium, reduce unnecessary
fission. Turbine FE is a by-product, not the controller's primary objective.

### Thermal safety overhaul: measured Mekanism heat capacity (2026-10-24)

The user ran an **18x18x18 water-cooled standard Mekanism Fission
Reactor** with a normal measured temperature of **889.6 K at
448 mB/t**. The old blanket `tempWarn=850` caused SPS AUTO to trim
a healthy burn setting and `tempTrip=1000` left almost no headroom
above the user's manually tested 540 mB/t. That was a controller
policy mistake, *not* evidence of a cooling failure.

The controller now reads **`getHeatCapacity()`** from the formed
Fission Reactor's actual CC:Tweaked peripheral and uses the validated
steady-state approximation from
[cc-mek-scada Reactor Temperature Calculation](https://github.com/MikaylaFischler/cc-mek-scada/wiki/Reactor-Temperature-Calculation):

```text
Water:   expected K = 373.15 + burn(mB/t) * (2 * energyPerFissionFuel / heatCapacity)
Sodium:  expected K = 373.15 + burn(mB/t) * (    energyPerFissionFuel / heatCapacity)
```

The [Project Infinity Mekanism Generators config](https://github.com/BOLTMAGIC/Project-Infinity-0.1/blob/main/config/Mekanism/generators.toml)
sets `energyPerFissionFuel=1000000` Joules/mB,
`casingHeatCapacity=1000` J/K and
`meltdownsEnabled=true`.
At 18x18x18, a shell of 1736 blocks gives approximately
**1,736,000 J/K**, confirmed if `getHeatCapacity()` returns this
number. This predicts:

| Water-cooled burn | Model temperature |
| --- | --- |
| 400 mB/t | 834 K |
| 448 mB/t | 889 K |
| 540 mB/t | 995 K |
| 600 mB/t | 1064 K |
| 650 mB/t | 1122 K |

The approximation assumes stable, effective cooling. If your coolant
flow, water feed, heating characteristics or modpack configs differ,
**actual measured temperature and its direction of change override
model expectations**. Model-vs-actual errors and the rolling
12–20-second K/s trend are logged and shown on the REACTOR, DIAG and
computer terminal views. In AUTO, unexpected measured overheating
pauses or reduces burn without waiting for a fixed 850K threshold.

**New thermal policy:**
- **1100 K** default steady thermal soft warning: controlled trim and
  calibrated max burn cap. The physical model estimates a
  conservative **~618 mB/t** upper cap for the user's reactor
  at default settings and a 2% safety margin, before SPS/FE/fuel/flow
  constraints.
- **1150 K** absolute software SCRAM and autonomous RPS SCRAM (also
  clamps custom higher values to 1150). Structural damage begins
  around **1200 K** in standard Mekanism, so we keep at least 50 K
  pre-damage headroom. Any actual damage >0 remains an SCRAM condition.
- Rising temperature unexpectedly far above calculated equilibrium,
  a rapidly rising temperature on a path to the hard limit, dropping
  coolant, heated-coolant backup, waste pressure or steam buildup can
  force a hold/trim or SCRAM sooner.
- If `getHeatCapacity()` is missing, **AUTO SPS will not increase burn**
  while `thermalRequireHeatCapacity=true`. The independent RPS still
  checks measured temperature and coolant.

**Settings migration:** if an existing CC configuration still has
the exact old defaults `tempWarn=850` and `tempTrip=1000`, only
that unmodified pair is upgraded to 1100/1150 during startup. An
explicitly customized lower trip threshold is preserved. Other
settings, including your manually configured `autoBurnCeiling`,
remain unchanged.

Thermal readouts and settings: `heatCapacity`, `expectedTemp`,
`thermalExpectedError`, `tempTrend`, `thermalState`,
`thermalReason`, `thermalModelCap`, `thermalTrendSeconds=20`,
`thermalMinTrendSeconds=12`, `thermalModelBurnMargin=0.98`,
`thermalRequireHeatCapacity=true` and
`thermalEnergyPerFuel=1000000`. The existing CSV header changed,
so the new log file retains all new thermal columns rather than
mixing incompatible rows with old history.

**Mods and addons reviewed:**
- **Mekanism 10.4.16 + Mekanism Generators:** these implement the
  standard Fission Reactor, turbine, SNA and SPS controlled here;
  actual reactor API and `generators.toml` settings govern heat physics.
- **Mekanism Extra / MekanismExtras**, **Evolved Mekanism**,
  **Compact Mekanism Machines** and **Better Fusion Reactor for
  Mekanism** occur in Project Infinity. They add other equipment,
  recipes or reactor variants; a Naquadah Reactor or an addon
  fusion/compact reactor must **not** be assumed to have the same
  fission temperature formula or CC methods. This program will only
  apply the standard fission model to a formed peripheral exposing
  the standard Mekanism Fission methods.
- **Advanced Peripherals** is available for optional environment
  sensing, but its radiation readout is not required for burn-rate
  control; the pack's published configuration disables global
  radiation mechanics. No radiation-based safety promises are made.

Thermal telemetry now uses `/cc-mekanism/history_v5_thermal.csv` so previous
`history_v4_stable.csv` remains intact with its original CSV column header.
Check `expectedTemp`, `tempTrend`, `thermalState`, `thermalModelCap`,
`spsCapReason`, `fuelRapidNet`, `steamPressureState`, and `spRate` to explain
why SPS AUTO is or is not increasing burn rate.

Tests perform Lua syntax checking, independent thermal-model tests,
and full mocked controller scenarios at 448 / 540 / 600 mB/t,
with safe 995K operation, abnormal heating and a hard 1150K
SCRAM. A passing simulated test is NOT a replacement for an in-game
commissioning run or an independent physical Fission Logic Adapter.

### Fix: SPS AUTO hunting 414 → 330 mB/t (2026-10-24)

The user's new screenshots showed a reactor falling between approximately
**414, 378 and 330 mB/t** despite a **100% coolant buffer**,
approximately **809 K** temperature, **full Fissile Fuel Tank**
and a rising SPS Antimatter rate. The monitor reported
`HOLD: PROTECTION COOLDOWN`, steam was approximately **64%**, and
the measured fuel buffer change was only **-0.06 mB/t**.

Two independent control mistakes caused excessive hesitation/hunting:

1. The old SPS AUTO immediately trimmed 15% of burn every 12 seconds
   if turbine steam was over 50% **and even a single measurement showed
   a slight rise**. At 64% steam (with `Dumping Excess`) this was
   unnecessarily aggressive. The new steam controller uses a ~16-second
   rolling trend and separates `OK`, `HOLD`, `TRIM`, `TRIM_FAST`.
   * Steady/modestly rising steam at **64%** does **not** throttle.
   * Sustained growth at **78%+** blocks ramp increases.
   * **88%+** trims by approximately **4.5%** with ≥28 seconds between
     ordinary cuts.
   * **93%+** or rapidly predicted approach to critical steam receives
     stronger protection. Reactor RPS steam SCRAM at 95% remains intact.
   * After a high-steam trim, ramps are held until the buffer recovers to
     approximately **83%**. This prevents repeated 88%→87%→88% cycling.
2. The old fuel-ramp condition refused increases for nearly *any* negative
   fuel tank trend below **-0.005 mB/t**, despite its own safety deficit
   estimator accepting as normal fluctuations of approximately 1% burn.
   The new single `fuelDeficit()` predicate consistently treats tiny
   measurements such as **-0.06 mB/t at 400 burn** as insignificant;
   true deficits >max(1 mB/t, 1% of actual burn) prevent ramping
   and reduce the cap with a production estimate.

A **1.2% / 4 mB/t burn deadband** now prevents chase of tiny instantaneous
SPS output fluctuations. Each protection decision writes an actual cause
to SCADA and history, rather than a generic `PROTECTION COOLDOWN`.

**Another independent limiter from the screenshot:** the user's CC
setting `autoBurnCeiling=495.00` was still in effect. Even after
the stability fixes, SPS AUTO cannot reach the user's manually tested
544.1 mB/t until that setting is deliberately raised. On the CC computer
press **C** and type a **new** ceiling in mB/t (the editor now starts
empty); recommend trying **550 mB/t** first and verifying heat, cooling,
SPS conversion and fuel balance before a higher cap. Setting 0 removes
the manual ceiling and exposes the structure maximum, which is **not**
recommended as a first automatic test.

New settings include `spsPressureTrendSeconds=16`,
`spsPressureHoldLevel=0.78`, `spsPressureTrimLevel=0.88`,
`spsPressureCriticalLevel=0.93`, `spsPressureRecoverLevel=0.83`,
`spsFuelDeficitFraction=0.01`, `spsFuelDeficitMinimum=1.0`,
`spsBurnDeadbandAbs=4`, `spsBurnDeadbandFraction=0.012`.
The revised logger writes `/cc-mekanism/history_v4_stable.csv` and
preserves earlier CSV files.

The screenshot shows **64% steam but does not contain its trend**, so this
is a code-grounded diagnosis, not a measured causal confirmation.
After updating, examine `steamPressureState`, `steamTrend`,
`protectionCause`, `fuelDeficitMaterial`, and `spsCapReason`
in the new log to validate whether the measured installation is stable.
The controller is still a beta and independent reactor hardware
protection is required.

### Fix: reactor stuck near 123 mB/t (2026-10-24)

Real monitor screenshots showed **AUTO CAP 123.02 mB/t** and SPS output
**0.0120 mB/t**, despite six Solar Neutron Activators producing a combined
potential of ~280.3 mB/t Polonium and a user-recorded **20 MFE/t** Flux limit.

Cause: the earlier `safeCap()` **always** applied an empirical Steam-per-Burn
ratio against the turbine's `getMaxFlowRate()`, inherited from the FE
controller. This treated the *secondary turbine throughput* as a hard cap on
the primary SPS production, preventing active exploration.

SPS AUTO now defaults to `spsTurbineFlowHardCap=false`. It does NOT impose
the turbine's maximum steam flow as a hard upper bound when searching for
higher antimatter throughput. The **FE turbine optimization mode still
applies its turbine flow cap**. For SPS AUTO, temperature, coolant, waste,
reactor heated-coolant buffer, boiler/turbine steam buffers, rapidly rising
backpressure and hardware RPS continue to constrain or stop operation.

This is NOT a license to exceed the installation's steam-removal capacity
indefinitely. If steam or heated coolant accumulates, the controller will
reduce the burn rate; persistent overload can require SCRAM. If you cannot
safely export or dump surplus steam, set `spsTurbineFlowHardCap=true` in
`/cc-mekanism/settings` to restore the conservative prior limitation.

SCADA Reactor page and the CSV now report the exact active `spsCapReason`:
`FLUX FE REFERENCE`, `FUEL PRODUCTION (LONG)`,
`FUEL PRODUCTION (RAPID)`, `SOLAR ACTIVATORS`,
`SPS PROCESSING PLATEAU`, or `REACTOR / MANUAL CEILING`.
With **20 MFE/t entered**, the current theoretical soft FE cap is about
**550 mB/t burn** including the configurable 10% exploratory margin,
not a measured FE throughput guarantee.

The regression scenario reproduces the screenshots, verifies that
the controller ramps **above 123 mB/t**, and separately verifies that
**rising steam backpressure still throttles the reactor**.

### SPS AUTO and FE diagnosis at 525 mB/t (2026-10-24)

The controller now compares three separate quantities in the **SPS** and **FE**
pages and `history_v4_fe.csv`:

* **Observed FE equivalent**: calculated from actual SPS `getProcessRate()`
  and the default Mekanism recipe (approximately 400 MFE per 1 mB
  Antimatter). This is **not** a direct FE meter.
* **FE required for current burn rate**: how much power SPS would need to
  consume the Polonium implied by `getBurnRate()` if all Nuclear Waste is
  converted with normal 10:1 and Polonium 1000:1 recipes.
* **Flux Point FE reference**: the number the operator set on the physical
  Flux Point and entered in CC with `L` or the monitor's `+1M/-1M` buttons.
  The program **cannot change or directly read the Flux Point**.

At **525 mB/t burn** the default recipe implies **0.0525 mB/t Antimatter**
and **21 MFE/t** demand. With the configured limit at **20 MFE/t**, the
theoretical maximum is **0.0500 mB/t Antimatter**, so there may be an
FE bottleneck. Increasing the *real* Flux Point limit and the CC reference
toward at least 21 MFE/t (about 23 MFE/t for a 5% experimental allowance
rounded up) could help **if enough Polonium and Fissile Fuel are available**.
An FE reference above the current SPS use is not proof of wasted FE: it may
simply be unused transfer capacity.

If FE currently sustains the chosen burn rate but the reactor and SNA have
unused capacity, an additional `FE_GROWTH_POSSIBLE` message can recommend
a careful **+1M FE/t trial**. It labels the opportunity *conditional* while
Fissile Fuel production remains uncalibrated (for example, a tank that stays
100% full). Once fuel production is measured, `FE_GROWTH_LIMIT` indicates
the verified fuel ceiling supports a higher test. This is a suggestion,
not a command that modifies physical Flux Point hardware.

New diagnostics classify `FE_LIMIT_LIKELY`,
`FE_BELOW_BURN_REQUIREMENT`, `SPS_INPUT_BACKLOG`,
`REFERENCE_HEADROOM`, `FE_REF_SUFFICIENT`, and measurement/configuration
mismatches. A low SPS internal FE buffer *alone* does not prove shortage;
the algorithm also considers Polonium trends, configured energy ceiling,
observed conversion and Antimatter output fill.

**Burn regulation still primarily maximizes sustained Antimatter**.
It probes higher burn only when the SPS consumes supplied Polonium, and
uses thermal, Solar Activator, Fissile Fuel production and manually recorded
FE constraints to hold or trim burn. It does not deliberately produce
unused excess Polonium indefinitely.

### Turbine Dumping Excess / makeup water safety

Turning on `Dumping Excess` can prevent steam accumulation, allowing the
SPS controller to optimize the reactor without prioritizing turbine FE
production. **However, excess steam vented from the turbine is not condensed
into water and is not returned to the reactor.** Without a reliable
independent water source, reactor coolant can deplete very quickly.

The controller reads the turbine's `getDumpingMode()` and recognizes
`DUMPING_EXCESS` (or a compatible mode string containing `excess`).
When that is active, a falling reactor coolant buffer prevents ramping.
Rising steam/heated coolant continues to force throttling. A coolant level
below `spsDumpCoolantTrip=0.98` triggers a latched software SCRAM from
both the main safety checks and the independent RPS checks.

This is a **backup guard, not a water-supply guarantee**. Verify a capable
water makeup system and independent Fission Logic Adapter protections
before increasing burn. Optional settings `spsDumpCoolantWarn=0.997`,
`spsDumpCoolantDropWarn=0.0002`, and `spsDumpCoolantTrip=0.98`
control the water-loss safeguards. Lowering these thresholds is unsafe
unless you understand the consequences. The logic depends on the actual
dumping-mode value exposed by CC:Mekanism.

The controller also estimates the difference between reactor
`getHeatingRate()` and turbine `getFlowRate()` during steam dumping.
This is only a **possible missing water-return rate**, not an actual vent
or pump-output meter. If it is positive, verify makeup water capacity.
For standard water cooling, 525 mB/t burn can boil roughly **10.5 million
mB of water into Steam every tick**. If the turbine is consuming less than
that, the deficit can be severe.

Telemetry schema changed, so new log samples go to
`/cc-mekanism/history_v4_fe.csv`; older `history_v4.csv` remains intact.
Run `cc-mekanism/probe` to confirm `getDumpingMode` is available.

### Controller operation

1. `AUTO SPS` estimates the burn needed for observed antimatter production:
   **1 mB/t antimatter ≈ 10,000 mB/t fission burn** at default Mekanism
   polonium/waste ratios. It adds restrained buffer-trend feedback.
2. If the SPS is actually consuming nearly all incoming polonium and inventory
   is not growing, it probes a higher burn rate in limited steps to discover
   additional output. If processing plateaus and buffers grow, it learns a
   temporary throughput cap and backs off.
3. Fuel is measured from the connected `fuelTank` (preferred), or the
   Fission Reactor's `getFuel()` inventory as a fallback. Integrated burn
   consumption plus tank inventory change estimates sustained fuel production.
   It runs a faster ~30s depletion monitor and a longer ~120–180s estimate.
   A 30%/40% fuel-fill hysteresis enables more restrictive limiting.
4. Caps from observed fuel supply, SNA capacity, heat/steam limits, reactor
   physical maximum, and *manually recorded* Flux Point FE/t are combined.
   Increased burn is allowed only with sufficient fuel reserve/calibration,
   valid sensors and healthy coolant. Cuts are rate-limited except hard limits
   and process stops.
5. Parallel, independent rapid RPS telemetry checks temperature, coolant,
   damage, waste, hot coolant, turbine/boiler buffers and sensor failures.
   The main SCADA collects peripheral readings in parallel and caches static
   machine geometry for 30 seconds.
6. When sunlight is unavailable, it enters **0.01 mB/t idle** (configurable) rather
   than wasting fuel or forcing an automatic restart. Normal SPS optimization
   resumes when solar conversion returns. It deliberately **SCRAMs and switches
   to MANUAL** at ≥98% antimatter output fill or critically draining fuel
   reserve. It **never auto-restarts** a stopped reactor.

**Important:** Exact *instantaneous* `burn ≤ fuel production` cannot be
mathematically guaranteed from buffered inventories alone. Estimates lag supply
changes, and tank transport may be bottlenecked. The automatic mode aims for
sustained balance with margin, rapid depletion detection and conservative
manual commissioning. It is **not a replacement for hardware fission safety**.

### Fuel wiring and measurements

Connect an Isotopic Centrifuge output to a Mekanism Chemical Tank, and the tank
to the reactor fuel input with Mekanism chemical pipes. The tank should be in
the main flow path (not a parallel side branch). The user reports that the
pipes normally fill first and the tank drains before the pipe buffers.

**Make sure the tank output throughput is sufficient for the planned burn rate.**
A very small/basic Chemical Tank may become the transfer bottleneck. Check
the `getStored()` / `getCapacity()` data with:

```lua
cc-mekanism/probe
```

If more than one chemical tank is visible, edit `/cc-mekanism/settings`
and set `fuelTank` to its exact wired peripheral name. The probe writes
`/cc-mekanism/probe.txt`. Fuel estimates are labelled as estimates.

### Visible ComputerCraft computer keyboard editor (2026-10-24)

The ComputerCraft computer connected to a large SCADA monitor previously printed
only a short eight-line status dump. The input loop captured keyboard characters,
but **never displayed the active edit field or typed digits**, so pressing
**C** required entering a ceiling blind. Repeated `screen.clear()` calls also
flickered the computer terminal.

The computer now has its own readable operator console, **separate** from the
large monitor. It shows live reactor burn, current `autoBurnCeiling`, Flux Point
reference, cooling status, control decision and a clearly visible editing pane.

- Press **C** on the **computer keyboard**: yellow
  `EDIT: AUTO BURN CEILING (mB/t)` banner, current ceiling, and a green
  `> _` input field appear. Typed digits update the terminal immediately.
- Type a new limit, e.g. `550`, and press **Enter** to save; **Backspace**
  corrects a digit and **Esc** cancels. `0` means detected reactor maximum,
  not a conservative default. Do not use `0` for early SPS testing.
- **B** opens a manual burn editor; **L** the recorded Flux Point FE/t value;
  **T** the turbine FE target percentage. All numeric fields start empty,
  show their existing value separately, and keep the editor open on invalid
  input rather than silently discarding it.
- Only the **small computer terminal** redraws in reaction to keystrokes.
  It caches unchanged lines to avoid visible flashing. The **large monitor
  remains the sole SCADA drawing surface** in the main telemetry coroutine,
  preserving touchscreen controls and preventing render conflicts.

Headless tests check current-value display, live typing, Save, invalid-input
handling, saved cap and Flux limit, and that repeated edits do not clear the
computer screen. Existing in-game installation remains unverified.

### Touchscreen Flux Point reference and smoother monitor (v4 UI)

The full SCADA touchscreen now has two always-visible touch controls near the
bottom of **every page**: **[-1M]** and **[+1M]**. Each press updates the saved
`fluxLimitFE` reference by exactly **1,000,000 FE/t**, including the SPS
optimizer's manually configured FE ceiling. Repeated touches may be grouped
as a single FE A/B trial. The UI displays the current value as `FLUX REF`.

**This changes the saved value in the CC controller only.** The computer
does **not** change the physical Flux Point automatically. Match its transfer
limit manually; otherwise the program's FE estimate is no longer valid. The
touch minus button stops at 1 MFE/t to avoid accidentally setting 0, which
would disable the soft FE cap. Press `L` on the computer to enter an exact
FE/t number (the editor now starts empty), if needed.

Monitor redraw now skips unchanged text rows, avoids clearing the entire monitor
every telemetry cycle, avoids resetting text scale unnecessarily, and draws
only from the main monitor loop rather than racing input and telemetry
coroutines. A full clear happens only on page, monitor or resolution changes.
The first draw after installing remains a full redraw.

### FE Advisor — manual A/B comparison

Flux Point is **not** directly adjustable or measured through the current
peripherals. `fluxLimitFE` is an operator-entered reference, not measured power.

- Start with an unchanged Flux Point limit; leave the SPS stable ≥60s.
- Press **L** in the CC computer, enter the proposed *new* FE/t cap.
- **Immediately after recording** the new reference, change the Flux Point
  itself to that limit manually.
- After ≥180s the advisor compares stabilized before/after antimatter and
  records the result to `/cc-mekanism/fe_trials.csv`. Unrelated changes in
  weather, fuel supply or machines can invalidate the comparison.

The FE-timed test may suggest maintaining or reverting a changed limit. It
does not infer an actual SPS electricity meter from Induction Matrix totals.

### Installation and testing

```text
wget run https://raw.githubusercontent.com/damian2603/Reactor/main/cc-mekanism/install.lua
cc-mekanism/probe
cc-mekanism/controller
```

Installer now also downloads `optimizer_math.lua`. Old settings survive.
Telemetry history is now stored in `/cc-mekanism/history_v4.csv`; previous
`history.csv` is preserved.

Tests: `.github/workflows/cc-mekanism-checks.yml` performs Lua syntax checks,
independent calculation tests, and headless runtime scenarios against the actual
controller (SPS ramps, fuel limits, night idle, SCRAM and fuel integration).
These checks pass, but are **not** an in-world integration test.
Use a conservative manual `autoBurnCeiling`, keep independent reactor
hardware protection, and first verify the tank API/throughput in your pack.

Useful v4 settings: `fuelRapidSeconds=30`,
`fuelMinSampleSeconds=120`, `fuelTrendSeconds=180`,
`fuelMargin=0.90`, `fuelLimitStart=0.30`,
`fuelLimitRelease=0.40`, `spsRampSeconds=5`,
`spsRampMaxFraction=0.02`, `spsSettleSeconds=60`,
`spsNightIdleBurn=0.01`, `spsNightStopSeconds=0` (0 = keep idle),
`fastSafetySeconds=0.2`, `safetyBadReads=3`. Modify cautiously.

**Conceptual inspirations:** the independent RPS, EMA fuel limiting,
hysteresis, ramp states and cooldown monitoring in
[cc-mek-scada](https://github.com/MikaylaFischler/cc-mek-scada),
particularly `reactor-plc/plc.lua`, `reactor-plc/spctl.lua`,
`reactor-plc/threads.lua`, `supervisor/facility_update.lua`, and
`supervisor/unit.lua`. The SPS objective, feed-forward, fuel balance and
implementation here are independent and tailored for Project Infinity.

---

## Install in ComputerCraft

Use an **Advanced Computer**, a wired-modem network and optional **Advanced Monitor (at least 5x3 blocks, larger preferred)**. Attach and activate wired modems on:

- **Fission Reactor Logic Adapter** (mandatory for control)
- **Industrial Turbine Valve** (mandatory for standard direct-steam layout)
- **SPS Port** (recommended)
- Optional: **Boiler Valve** (if sodium cooled), **Induction Matrix Port**, Advanced Monitor

Run on the CC:Tweaked computer:

~~~text
wget run https://raw.githubusercontent.com/damian2603/Reactor/main/cc-mekanism/install.lua
cc-mekanism/probe
cc-mekanism/controller
~~~

If the installer is unavailable, direct install:

~~~text
wget https://raw.githubusercontent.com/damian2603/Reactor/main/cc-mekanism/controller.lua cc-mekanism/controller.lua
wget https://raw.githubusercontent.com/damian2603/Reactor/main/cc-mekanism/probe.lua cc-mekanism/probe.lua
~~~

Re-run the installer to update the code. It preserves existing settings and history. HTTP access must be enabled in CC:Tweaked.

The read-only probe generates **/cc-mekanism/probe.txt**. Check its method readings before relying on automatic control. Send the report if your peripherals have non-standard names or methods.

### Multiple reactors/turbines

Autodiscovery only selects devices when exactly **one** matches each device class. If there are several, set explicit names in **/cc-mekanism/settings**, for example:

~~~lua
{
  reactor = "fissionReactorLogicAdapter_0",
  turbine = "turbineValve_0",
  sps = "spsPort_0",
  -- the other entries are preserved
}
~~~

Do **not** replace the file with only those three fields; instead edit their values in the settings table generated by the program.

## Controls

- **M** — MANUAL mode (temperature/waste/coolant emergency SCRAM stays enabled).
- **F** — AUTO FE: throttles on steam accumulation, turbine FE fill and (if connected) Induction Matrix fill.
- **P** — AUTO SPS: also throttles if SPS Polonium / Antimatter tanks are near full.
- **B** — manually enter burn rate; switches to MANUAL.
- **+ / -** — burn rate step up/down; switches to MANUAL.
- **C** — change the cap on AUTO burn rate.
- **S** — immediate emergency SCRAM, latched alarm.
- **R, R** within 7 seconds — manually attempt to activate after safety checks. **No automatic restart.**
- **Q** — exit with SCRAM attempt.
- With Advanced Monitor, buttons near its bottom offer +/- , cap +/-, modes, SCRAM, START.

The program starts in **MANUAL** after every reboot. The AUTO cap initially follows the detected machine maximum, but the ramp is slow (0.5% of reactor max per 15 seconds, minimum 0.1 mB/t). You may set an explicit cap for cautious first tests, and must validate operation before allowing high burn rates. The limit of this code is for AUTO; in MANUAL you can set up to the reactor's own maximum.

### Automatic machine sizing (v2.1)

On every sample, the controller retrieves geometry and operating limits directly from Mekanism:

- **Fission Reactor:** `getLength/getWidth/getHeight`, `getFuelAssemblies`, `getBoilEfficiency`, `getMaxBurnRate`, and capacities of fuel/waste/coolant tanks.
- **Industrial Turbine:** size, blades, coils, vents, condensers, `getMaxFlowRate`, `getMaxWaterOutput`, steam buffer, and production ceiling.
- **SPS:** size, coil count, Polonium and Antimatter buffer capacities, `getProcessRate`.
- **Optional boiler:** rated boil capacity, steam/hot-coolant/water fill. The program does not equate sodium heating directly to steam output.

**No dimensions have to be entered manually.** The default AUTO burn ceiling is now **0 = follow detected physical limits**; the AUTO ramp step is proportional to the detected reactor capacity (default 0.5% every 15 seconds, minimum 0.1 mB/t). As the turbine flow and the real steam produced per burn unit become measurable, the controller can automatically derive a lower ceiling to avoid flooding the turbine. The emergency temperatures/fill percentages remain independent safety limits.

To impose your own additional cap, press **C** and enter a value >0; enter **0** to return to detected maximum. The cap +/- monitor buttons adjust by 5% of the detected max reactor rate. If updating from v2.0, the old **default 1.0 mB/t cap is not carried over**; a previous custom cap above 1.0 is migrated.

This is **adaptive, but not omniscient**: there is no Mekanism peripheral that exposes an entire pipe network's true safe throughput. For example, Polonium production may be bottlenecked by Solar Neutron Activators or chemical tanks. The controller detects symptoms via Nuclear Waste and SPS buffers, then throttles. Keep the independent reactor safety logic connected.

The program **never silently changes turbine dumping mode**. Inspect your water return loop and turbine vent/dump mode manually.


### v3.0 — SPS-first antimatter governor

**SPS production is the primary optimization objective.** Wired modems must expose the **SPS Port** and **all Solar Neutron Activators** to the same ComputerCraft computer, in addition to the reactor and turbine. Do not cover the sky-facing side of Solar Neutron Activators. Press **P** to engage SPS AUTO; it starts in MANUAL after every reboot.

Mekanism's actual processing ratios:
- 1 mB burned fuel → 1 mB Nuclear Waste.
- 10 mB Nuclear Waste → 1 mB Polonium (Solar Neutron Activator).
- 1000 mB Polonium → 1 mB Antimatter in SPS.
- SPS requires **1 million Mekanism Joules per Polonium mB**, and Project Infinity converts **2.5 J to 1 FE**. Hence 1 mB Antimatter requires approximately **400 million FE**.

At 400 mB/t burn, the upper bound is **0.040 mB Antimatter/t**; at 1920 mB/t it is **0.192 mB/t**, *if* solar conversion, SPS power and transport can sustain it.

The controller detects any number of connected Solar Neutron Activators, reads weather/biome-sensitive `getProductionRate`, and targets up to 92% of the current total Solar throughput (10 waste per operation). It further respects the reactor burn capacity, physical cooling/steam flow limits, changing waste fills, Polonium backpressure and Antimatter export backpressure. If solar conversion rate drops to zero (e.g. night), it pauses burn instead of accumulating Nuclear Waste. It uses SPS `getProcessRate()` as the observed Antimatter/t, and diagnoses likely energy, polonium feed, waste transfer or steam bottlenecks.

**This is a telemetry-based adaptive estimator, not a perfect closed-loop full-chain throughput model**: the native SPS API doesn't reveal the actual total FE accepted through all its coils, and Solar Neutron Activator `getProductionRate` reports its weather-adjusted capability rather than guaranteed executed operations when starved or backed up. The controller cannot directly power the SPS or change its external energy input.

**Important unit correction:** Mekanism's turbine energy readings are **J/t, not FE/t**. New UI converts those using pack-specific 2.5 J/FE. For example 79.98 MJ/t = 31.99 MFE/t; 0.040 AM/t SPS consumes ~16 MFE/t equivalent.

Optional setting `spsNoSolarHold=false` allows SPS AUTO without SNA peripheral data, but lacks live throughput caps and is *not recommended*. AUTO FE remains separate. On first trial use a moderate `autoBurnCeiling`, and keep independent redstone fission safeguards and stable coolant supply.

### v2.2 turbine-generation governor

AUTO FE now targets **95% of rated turbine production** instead of reacting to every positive steam tank delta. Real-time `getProductionRate / getMaxProduction` determines power utilization; the controller smooths measurements and waits 12 seconds for the turbine to stabilize after a burn change, adopting cc-mek-scada's explicit generation target and stability-delay ideas (not its code).

- Press **T** in the controller to change the rated production target (20–100%, default 95%).
- `steam growth` by itself **does not throttle**. Steam limits remain safety backstops: ramp hold near 89%, throttling near 93% when not draining, default SCRAM at 95%. Independent reactor logic adapters remain required.
- High turbine energy buffer (default >=93%) means power isn't leaving efficiently and reduces burn.
- For **direct water** cooling, the adaptive flow-based ceiling is estimated from observed steam created per fuel burnt, and calculated against **95% of real max turbine flow**. Do not equate sodium heating rate with actual steam generation.
- AUTO never automatically activates a stopped reactor. Existing temperature, coolant, waste and damage SCRAMs remain.
- A production measurement is not identical to net delivered FE. The optional Induction Matrix gives useful additional observability.

To change the generation target persistently you can use `T`, or edit `feTarget = 0.95` in `/cc-mekanism/settings` while the controller is not running.

### Logging and optimization

Every 10 seconds data is appended to **/cc-mekanism/history.csv**:

- Configured / actual burn, reactor temperature, damage, coolant, waste, steam generated.
- Turbine steam capacity, steam flow, generation, energy-buffer fill.
- SPS Polonium in / Antimatter out and production rate.
- Optional boiler / Induction Matrix readings.

AUTO ramping is **conservative, not a theoretical global optimum**. It uses observed steam/burn ratios, turbine capacity, trends in waste/steam/coolant, and SPS buffering. If Solar Neutron Activators, pipes or Polonium production cannot keep up, **the high Nuclear Waste fill will cause throttling**; the program cannot infer a precise chain throughput from SPS alone.

Mekanism's SPS uses **1000 mB Polonium per 1 mB Antimatter** in this pack. Reactor Nuclear Waste **cannot be piped directly into SPS**: it must first be processed to Polonium.

### Safety

The supplied Mekanism config has **meltdowns enabled**. You should build **separate hardware safeguards** with Fission Reactor Logic Adapters configured for Temperature / Excess Waste / Activation; make sure a signal *physically disables* the reactor when necessary. A frozen ComputerCraft computer, unloaded chunk, removed modem, broken script or server shutdown cannot be made reliably safe by Lua alone.

Default trips: temperature >=1000 K, any damage, coolant <60%, rising coolant loss >8 percentage points/sec, nuclear waste >=85%, heated coolant >=85%, turbine steam >=86%. Warnings cause throttling before the trip. These are conservative starting parameters, **not certified operating limits**. Adjust only after validating coolant and water circuits.

Loss of required telemetry while status is unknown triggers a best-effort SCRAM and latches an alarm. Restoration of telemetry does not automatically reactivate the reactor.

The system attempts SCRAM on exit or error, but **cannot promise shutdown if the computer itself fails**. Do not modify physical redstone safety based solely on this program.

### Related projects used as design references

Independent implementation, informed by patterns seen in:
- [CC-MEK-SCADA](https://github.com/MikaylaFischler/cc-mek-scada) — multi-reactor monitoring and safety design.
- [Mekanism Fission Reactor Control](https://github.com/tralalax/Mekanism-Fission-Reactor-Control) — simple monitor layout and safe manual operation.
- [Mekanism Fission Reactor Manager](https://github.com/jandie1505/computercraft-programs/tree/master/mekanism-fission-reactor-manager) — alarm thresholds and monitor UI.

Mekanism API references:
- [Fission](https://github.com/mekanism/Mekanism/blob/1.20.x/src/generators/java/mekanism/generators/common/content/fission/FissionReactorMultiblockData.java)
- [Turbine](https://github.com/mekanism/Mekanism/blob/1.20.x/src/generators/java/mekanism/generators/common/content/turbine/TurbineMultiblockData.java)
- [SPS](https://github.com/mekanism/Mekanism/blob/1.20.x/src/main/java/mekanism/common/content/sps/SPSMultiblockData.java)

## Beta 1: SPS-first fuel efficiency (experimental)

This beta uses a measured SPS Polonium input buffer trend to seek a sustainable minimum fission burn rate. It **does not** automatically change Flux Point settings.

Optional Fissile Fuel tank: connect a Mekanism Chemical Tank to the wired modem network, with fuel routed through it. The experimental tank adapter expects `getStored()` and `getCapacity()`; verify the methods and returned units with `peripheral.getMethods(name)` and the probe before enabling fuel-based AUTO. If autodetection does not find it, set `fuelTank="peripheral_name"` in `/cc-mekanism/settings`. **The beta does not yet calibrate the hidden fuel buffers in Mekanism pipes.** A measured fuel balance is only approximate and should never be treated as a safety guarantee.

New settings:
- `fluxLimitFE=16000000`: **manual reference value**, not a measured FE draw; press **L** on the computer to update it after changing the Flux Point.
- `fuelReserve=0.15`: soft fuel reserve.
- `fuelMargin=0.90`: margin on inferred sustainable fuel supply.
- `fuelTrendSeconds=180`: measurement horizon.

The FE advisor uses SPS production and Polonium buffer trends. It provides **qualitative trial recommendations**, not measured FE savings or a proven optimal Flux Point value. Only increase FE manually if the power network can support it; compare stabilized antimatter production before and after.

Safety: independent hardware Fission Logic Adapters are still strongly recommended. The program does not automatically start the reactor. Test the tank peripheral API, pipe buffering, alarm behavior, and rate changes at a conservative manual cap before trusting automatic control.

**Beta limitations:** no independent Reactor PLC implementation; no actual SPS FE input metering; no automatic Flux Point adjustment; no validated closed-loop maximum fuel-production search; no in-game test yet. These are future improvements, not completed features.
