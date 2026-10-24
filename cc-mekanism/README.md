# Project Infinity: Mekanism Fission / Turbine / SPS controller

Standalone ComputerCraft / CC:Tweaked controller for **Mekanism Fission Reactor + Industrial Turbine + SPS**, developed for Minecraft 1.20.1 / Project Infinity 0.1. The separate NuclearCraft optimizer in this repository is untouched.

**Status: v4 beta experimental (autodetection of multiblock sizes).** Tested against inspected Mekanism API source, **not yet validated in an actual running Project Infinity world**. Do not rely on this program as your only reactor safety mechanism.

## v4 beta — SPS-first adaptive controller (2026-10-24)

This section supersedes the older v2/v3 and Beta 1 descriptions below where they conflict.

**Objective:** raise antimatter production as far as the measured SPS processing,
Solar Neutron Activators, turbine/boiler heat handling, and sustained Fissile Fuel
production permit. When the SPS does not use added polonium, reduce unnecessary
fission. Turbine FE is a by-product, not the controller's primary objective.

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

Tests: `.github/workflows/cc-mekanism-checks.yml` performs Lua syntax checks
and independent calculation tests. It is not an in-world integration test.
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
