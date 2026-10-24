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
return M
