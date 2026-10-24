-- Project Infinity: conservative Mekanism Fission thermal model.
-- Based on 1.20.1 Mekanism 10.4 heat capacity/energy settings and
-- cc-mek-scada reactor temperature model (CC BY? independent equations).
-- Pure and separately testable: no CC peripheral calls here.
local M={}
local BASE_BOIL_K=373.15
local ENERGY_PER_FUEL=1000000
local function valid(n)
  return type(n)=="number" and n==n and n~=math.huge and n~=-math.huge
end
local function clamp(n,a,b) return math.max(a,math.min(b,n)) end

M.BASE_BOIL_K=BASE_BOIL_K
M.ENERGY_PER_FUEL=ENERGY_PER_FUEL

function M.expected(burn,heatCapacity,isSodium,energyPerFuel)
  if not valid(burn) or burn<0 or not valid(heatCapacity) or
      heatCapacity<=0 then return nil end
  local energy=valid(energyPerFuel) and energyPerFuel>0 and
    energyPerFuel or ENERGY_PER_FUEL
  local factor=isSodium and 1 or 2
  return BASE_BOIL_K+burn*factor*energy/heatCapacity
end

function M.thermalCap(heatCapacity,isSodium,warningK,margin,energyPerFuel)
  if not valid(heatCapacity) or heatCapacity<=0 or not valid(warningK) or
      warningK<=BASE_BOIL_K then return nil end
  local energy=valid(energyPerFuel) and energyPerFuel>0 and
    energyPerFuel or ENERGY_PER_FUEL
  local factor=isSodium and 1 or 2
  return math.max(0,(warningK-BASE_BOIL_K)*heatCapacity/
    (factor*energy)*clamp(valid(margin) and margin or 0.985,0.1,1))
end

-- Returns a *recommendation* for optimizer. Independent RPS must still
-- SCRAM at or below 1150K and always on actual reactor damage.
function M.assess(o)
  o=o or {}
  local temp=o.temp
  local trend=valid(o.trend) and o.trend or nil -- K / real second
  local warn=clamp(valid(o.warn) and o.warn or 1100,900,1120)
  local trip=clamp(valid(o.trip) and o.trip or 1150,1000,1150)
  warn=math.min(warn,trip-25)
  local expected=M.expected(o.burn,o.heatCapacity,o.isSodium,
    o.energyPerFuel)
  local errorTolerance=clamp(valid(o.errorTolerance) and
    o.errorTolerance or 55,15,200)
  local out={state="UNKNOWN",reason="NO TEMPERATURE MEASUREMENT",
    expected=expected,trend=trend,softWarn=warn,hardTrip=trip,
    errorK=expected and valid(temp) and temp-expected or nil}
  if not valid(temp) then return out end
  if temp>=trip then
    out.state="TRIP"
    out.reason="REACTOR ABSOLUTE TEMPERATURE TRIP"
  elseif temp>=trip-30 then
    out.state="TRIM_FAST"
    out.reason="REACTOR TEMPERATURE NEAR SCRAM"
  elseif trend and trend>0.4 and temp+trend*20>=trip-20 then
    out.state="TRIM_FAST"
    out.reason="REACTOR TEMP RISING TOWARD SCRAM"
  elseif temp>=warn then
    out.state="TRIM"
    out.reason="REACTOR ABOVE THERMAL SOFT CEILING"
  elseif expected and temp>=expected+errorTolerance and
      (not trend or trend>=-0.05) then
    out.state="TRIM"
    out.reason="REACTOR HOTTER THAN HEAT MODEL"
  elseif trend and trend>0.40 and temp+trend*30>=warn then
    out.state="HOLD"
    out.reason="REACTOR TEMP APPROACHING SOFT CEILING"
  elseif expected and temp>=expected+errorTolerance*0.6 and
      trend and trend>0.10 then
    out.state="HOLD"
    out.reason="REACTOR TEMP ABOVE EXPECTED AND RISING"
  else
    out.state="OK"
    out.reason=expected and "TEMPERATURE NEAR EXPECTED MODEL" or
      "TEMPERATURE OK; HEAT CAPACITY UNKNOWN"
  end
  return out
end
return M
