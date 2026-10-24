-- Lightweight ram-only patch for legacy packed Project Infinity controller.
-- Allows turbine DUMPING_EXCESS fixes without downloading another 72KB blob
-- to a ComputerCraft disk with only ~6KB free.
local test=rawget(_G,"CC_MEKANISM_PAYLOAD_TEST")==true
local path=test and "cc-mekanism/controller.packed.lua" or
  "/cc-mekanism/controller.packed.lua"
if not test and not fs.exists(path) then error("Missing packed controller",0) end
local previous=rawget(_G,"CC_MEKANISM_PAYLOAD_TEST")
_G.CC_MEKANISM_PAYLOAD_TEST=true
local ok,source=pcall(dofile,path)
_G.CC_MEKANISM_PAYLOAD_TEST=previous
if not ok or type(source)~="string" then
  error("Packed controller cannot decode: "..tostring(source),0)
end
local changes={
  {[[  spsTurbineFlowHardCap=false, -- SPS prioritizes antimatter; turbine FE is secondary]],[[  spsTurbineFlowHardCap=false, -- SPS prioritizes antimatter; turbine FE is secondary
  -- Project Infinity Mekanism general.toml dumpExcessKeepRatio=0.9.
  -- DUMPING_EXCESS is expected to FILL TO 90%, then vent over 90%.
  spsDumpKeepRatio=0.90, spsDumpPressureHoldLevel=0.93,
  spsDumpPressureTrimLevel=0.955, spsDumpPressureCriticalLevel=0.975,
  spsDumpPressureRecoverLevel=0.925, spsDumpSteamTrip=0.985,]]},
  {[[  t.dumpExcess=t.dump~=nil and tostring(t.dump):lower():find("excess",1,true)~=nil]],[[  t.dumpExcess=t.dump~=nil and tostring(t.dump):lower():find("excess",1,true)~=nil
  t.steamDumpKeepRatio=t.dumpExcess and c.spsDumpKeepRatio or nil
  t.steamDumpingActive=t.dumpExcess and t.steam and
    t.steam>=c.spsDumpKeepRatio or false
  t.steamTripEffective=t.dumpExcess and c.spsDumpSteamTrip or c.steamTrip]]},
  {[[  elseif t.steam and t.steam>=c.feSteamHold then
    t.spsDiagnosis="TURBINE STEAM FLOW LIMIT"]],[[  elseif t.steam and (not t.dumpExcess and t.steam>=c.feSteamHold or
      t.dumpExcess and t.steam>=c.spsDumpPressureTrimLevel) then
    t.spsDiagnosis="TURBINE STEAM BACKPRESSURE"]]},
  {[[  if t.steam and t.steam>=c.steamTrip then return false,"turbine steam full" end]],[[  if t.steam and t.steam>=t.steamTripEffective then
    return false,"turbine steam near full (dump-aware)" end]]},
  {[[  local pressure=optimizerMath.spsPressure({
    steam=t.steam,slope=t.steamTrend,
    holdLevel=c.spsPressureHoldLevel,
    trimLevel=c.spsPressureTrimLevel,
    criticalLevel=c.spsPressureCriticalLevel,
    trendWarn=c.spsPressureGrowthWarn,
    trendFast=c.spsPressureGrowthFast
  })]],[[  -- Turbine DUMPING_EXCESS does not start until the configured keep level.
  -- The climb toward 90% is normal, not runaway backpressure.
  local dump=t.dumpExcess==true
  local pressure=optimizerMath.spsPressure({
    steam=t.steam,
    slope=(dump and t.steam and t.steam<c.spsDumpKeepRatio)
        and 0 or t.steamTrend,
    holdLevel=dump and c.spsDumpPressureHoldLevel or c.spsPressureHoldLevel,
    trimLevel=dump and c.spsDumpPressureTrimLevel or c.spsPressureTrimLevel,
    criticalLevel=dump and c.spsDumpPressureCriticalLevel or
      c.spsPressureCriticalLevel,
    trendWarn=c.spsPressureGrowthWarn,
    trendFast=c.spsPressureGrowthFast
  })]]},
  {[[  elseif steamPressureRecovery and t.steam and
      t.steam<=c.spsPressureRecoverLevel and
      (not t.steamTrend or t.steamTrend<=c.spsPressureGrowthWarn) then]],[[  elseif steamPressureRecovery and t.steam and
      (dump and t.steam<=c.spsDumpKeepRatio or
       t.steam<=(dump and c.spsDumpPressureRecoverLevel or
           c.spsPressureRecoverLevel) and
       (not t.steamTrend or t.steamTrend<=c.spsPressureGrowthWarn)) then]]},
  {[[    elseif q.steam and q.steam>=c.steamTrip then reason="RPS: turbine steam full"]],[[    elseif q.steam and q.steam>=(
      (q.dump and tostring(q.dump):lower():find("excess",1,true)) and
      c.spsDumpSteamTrip or c.steamTrip) then
      reason="RPS: turbine steam near full (dump-aware)"]]},
  {[[  "steam","steamIn","steamTrend","steamTrendWindow",]],[[  "steam","steamIn","steamTrend","steamTrendWindow",
  "steamDumpKeepRatio","steamDumpingActive","steamTripEffective",]]},
  {[[    paint(24,"Temperature soft "..n(current.thermalWarnEffective,0)..
      "K / SCRAM "..n(current.thermalTripEffective,0).."K",colors.orange)]],[[    paint(24,"Temperature soft "..n(current.thermalWarnEffective,0)..
      "K / SCRAM "..n(current.thermalTripEffective,0).."K",colors.orange)
    if current.dumpExcess then
      paint(25,"DUMP EXCESS retains "..p(current.steamDumpKeepRatio)..
        " steam; protective SCRAM "..p(current.steamTripEffective),colors.lightBlue)
    end]]}
}
for i,pair in ipairs(changes) do
  local a,b=source:find(pair[1],1,true)
  if not a or source:find(pair[1],b+1,true) then
    error("Packed controller patch incompatible at step "..i,0)
  end
  source=source:sub(1,a-1)..pair[2]..source:sub(b+1)
end
if test then return source end
local program,err=load(source,"@/cc-mekanism/controller.lua","t",_ENV)
if not program then error("Patched controller Lua invalid: "..tostring(err),0) end
return program()
