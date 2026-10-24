-- Pure, testable math used by Project Infinity SPS optimizer v4 beta.
local M={}
local function num(x) return type(x)=="number" and x==x and x~=math.huge and x~=-math.huge end
function M.fuelProduction(consumed,totalStoredDelta,ticks)
  if not num(consumed) or not num(totalStoredDelta) or not num(ticks) or ticks<=0 then return nil end
  return math.max(0,(consumed+totalStoredDelta)/ticks)
end
function M.spsBurn(rate,wastePerPolonium,poloniumPerAntimatter)
  if not num(rate) or not num(wastePerPolonium) or not num(poloniumPerAntimatter) then return nil end
  return math.max(0,rate*wastePerPolonium*poloniumPerAntimatter)
end
function M.feBurnLimit(fe,joulesPerFE,wastePerPolonium,joulesPerPolonium,margin)
  if not num(fe) or not num(joulesPerFE) or not num(wastePerPolonium) or
      not num(joulesPerPolonium) or joulesPerPolonium<=0 then return nil end
  return math.max(0,fe*joulesPerFE*wastePerPolonium/joulesPerPolonium*(margin or 1))
end
function M.feedback(trend,capacity,tps,wastePerPolonium,gain,base)
  if not num(trend) or not num(base) or not num(gain) or not num(wastePerPolonium) then return 0 end
  local correction
  if num(capacity) and capacity>0 then
    correction=-trend*capacity/math.max(1,num(tps) and tps or 20)*wastePerPolonium*gain
  else
    correction=-math.max(-0.05,math.min(0.05,trend*250))*math.max(10,base)
  end
  local lim=math.max(2,base*0.1)
  return math.max(-lim,math.min(lim,correction))
end
-- FE reference analysis. fluxLimitFE is a manually supplied LIMIT,
-- not a direct reading of real FE delivered to the SPS coils.
function M.feForBurn(burn,joulesPerFE,wastePerPolonium,joulesPerPolonium)
  if not num(burn) or not num(joulesPerFE) or joulesPerFE<=0 or
      not num(wastePerPolonium) or wastePerPolonium<=0 or
      not num(joulesPerPolonium) then return nil end
  return math.max(0,burn/wastePerPolonium*joulesPerPolonium/joulesPerFE)
end
function M.feForAntimatter(rate,poloniumPerAntimatter,joulesPerPolonium,joulesPerFE)
  if not num(rate) or not num(poloniumPerAntimatter) or
      not num(joulesPerPolonium) or not num(joulesPerFE) or
      joulesPerFE<=0 then return nil end
  return math.max(0,rate*poloniumPerAntimatter*joulesPerPolonium/joulesPerFE)
end

-- Classifies evidence, not the physical delivery rate. A Flux Point limit
-- can be above actual draw, especially when Polonium is unavailable.
function M.assessFE(o)
  o=o or {}
  local ref=o.limitFE
  local needed=o.neededFE
  local used=o.usedFE
  local input=o.poloniumFill
  local slope=o.poloniumTrend
  local spEnergy=o.energyFill
  local output=o.outputFill
  if not num(ref) or ref<=0 or not num(needed) or not num(used) then
    return {state="UNKNOWN",text="FE REF UNKNOWN / DISABLED"}
  end
  local extra=math.max(0,needed-ref)
  local rounded=math.ceil(math.max(0,needed)*1.05/1000000)*1000000
  local target=math.max(1000000,rounded)
  local res={requiredFE=needed,observedEquivalentFE=used,
    limitFE=ref,shortfallFE=extra,trialFE=target,
    confirmedDeliveryFE=false}
  if num(output) and output>=0.90 then
    res.state="OUTPUT_FULL"
    res.text="AM OUTPUT STORAGE NEAR FULL"
  elseif used>ref*1.15 then
    res.state="CONFIG_OR_REF_MISMATCH"
    res.text="OBSERVED SPS FE EQUIVALENT EXCEEDS FE REF; CHECK CONFIG"
  elseif needed>ref*1.025 then
    if (num(input) and input>0.04 and num(slope) and slope>0.000025) or
        (num(input) and input>0.10 and used>=ref*0.83) then
      res.state="FE_LIMIT_LIKELY"
      res.text="FE PROBABLY LIMITS SPS; TRY +1M ON FLUX & CC"
    else
      res.state="FE_BELOW_BURN_REQUIREMENT"
      res.text="FE REF BELOW BURN DEMAND; WATCH POLONIUM"
    end
  elseif num(input) and input>0.10 and
      num(slope) and slope>0.000025 and
      (not num(spEnergy) or spEnergy<0.10) then
    res.state="SPS_INPUT_BACKLOG"
    res.text="POLONIUM BACKLOG; CHECK ACTUAL SPS FE DELIVERY"
  elseif needed<ref*0.70 and used<ref*0.70 and
      not (num(o.opportunityFE) and o.opportunityFE>ref*1.10) then
    res.state="REFERENCE_HEADROOM"
    res.text="FE REF ABOVE CURRENT NEED; NOT WASTED POWER"
  elseif num(o.opportunityFE) and o.opportunityFE>ref*1.10 and
      num(input) and input<0.25 and
      (not num(slope) or slope<=0.000025) then
    res.state=o.fuelVerified and "FE_GROWTH_LIMIT" or
      "FE_GROWTH_POSSIBLE"
    res.text=o.fuelVerified and
      "MORE FE MAY INCREASE AM; TRY +1M FE/T" or
      "MORE FE MAY HELP; FIRST VERIFY FISSILE FUEL SUPPLY"
    res.trialFE=ref+1000000
  elseif needed<ref*0.70 and used<ref*0.70 then
    res.state="REFERENCE_HEADROOM"
    res.text="FE REF ABOVE CURRENT NEED; NOT WASTED POWER"
  else
    res.state="FE_REF_SUFFICIENT"
    res.text="FE REF ADEQUATE FOR CURRENT BURN (EST.)"
  end
  return res
end
return M
