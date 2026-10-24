-- Tiny RAM-only delta for the CC:Mekanism packed controller.
-- Full readable source: github.com/damian2603/Reactor/cc-mekanism/controller.lua
local test=rawget(_G,"CC_MEKANISM_PAYLOAD_TEST")==true
local path=test and "cc-mekanism/controller.packed.lua" or
  "/cc-mekanism/controller.packed.lua"
if not test and not fs.exists(path) then error("Missing packed controller",0) end
local flag=rawget(_G,"CC_MEKANISM_PAYLOAD_TEST")
_G.CC_MEKANISM_PAYLOAD_TEST=true
local ok,src=pcall(dofile,path)
_G.CC_MEKANISM_PAYLOAD_TEST=flag
if not ok or type(src)~="string" then error("Packed decode: "..tostring(src),0) end
local edits={
  {[[E is secondary]],[[E is secondary
  -- Project Infinity Mekanism general.toml dumpExcessKeepRatio=0.9.
  -- DUMPING_EXCESS is expected to FILL TO 90%, then vent over 90%.
  spsDumpKeepRatio=0.90, spsDumpPressureHoldLevel=0.93,
  spsDumpPressureTrimLevel=0.955, spsDumpPressureCriticalLevel=0.975,
  spsDumpPressureRecoverLevel=0.925, spsDumpSteamTrip=0.985,]]},
  {[[s",1,true)~=nil]],[[s",1,true)~=nil
  t.steamDumpKeepRatio=t.dumpExcess and c.spsDumpKeepRatio or nil
  t.steamDumpingActive=t.dumpExcess and t.steam and
    t.steam>=c.spsDumpKeepRatio or false
  t.steamTripEffective=t.dumpExcess and c.spsDumpSteamTrip or c.steamTrip]]},
  {[[t.steam>=c.feSteamHold then
    t.spsDiagnosis="TURBINE STEAM FLOW LIMIT]],[[(not t.dumpExcess and t.steam>=c.feSteamHold or
      t.dumpExcess and t.steam>=c.spsDumpPressureTrimLevel) then
    t.spsDiagnosis="TURBINE STEAM BACKPRESSURE]]},
  {[[c.steamTrip then return false,"turbine steam full]],[[t.steamTripEffective then
    return false,"turbine steam near full (dump-aware)]]},
  {[[local pressure=optimizerMath.spsPressure({
    steam=t.steam,slope=t.steamTrend,
    holdLevel=c.spsPressureHoldLevel,
    trimLevel=c.spsPressureTrimLevel,
    criticalLevel=]],[[-- Turbine DUMPING_EXCESS does not start until the configured keep level.
  -- The climb toward 90% is normal, not runaway backpressure.
  local dump=t.dumpExcess==true
  local pressure=optimizerMath.spsPressure({
    steam=t.steam,
    slope=(dump and t.steam and t.steam<c.spsDumpPressureHoldLevel)
        and 0 or t.steamTrend,
    holdLevel=dump and c.spsDumpPressureHoldLevel or c.spsPressureHoldLevel,
    trimLevel=dump and c.spsDumpPressureTrimLevel or c.spsPressureTrimLevel,
    criticalLevel=dump and c.spsDumpPressureCriticalLevel or
      ]]},
  {[[t.steam<=c.spsPressureRecoverLevel and
      (not t.steamTrend or t.steamTrend<=c.spsPressureGrowthWarn]],[[(dump and t.steam<=c.spsDumpKeepRatio or
       t.steam<=(dump and c.spsDumpPressureRecoverLevel or
           c.spsPressureRecoverLevel) and
       (not t.steamTrend or t.steamTrend<=c.spsPressureGrowthWarn)]]},
  {[[c.steamTrip then reason="RPS: turbine steam full]],[[(
      (q.dump and tostring(q.dump):lower():find("excess",1,true)) and
      c.spsDumpSteamTrip or c.steamTrip) then
      reason="RPS: turbine steam near full (dump-aware)]]},
  {[[mTrendWindow",]],[[mTrendWindow",
  "steamDumpKeepRatio","steamDumpingActive","steamTripEffective",]]},
  {[[K",colors.orange)]],[[K",colors.orange)
    if current.dumpExcess then
      paint(25,"DUMP EXCESS retains "..p(current.steamDumpKeepRatio)..
        " steam; protective SCRAM "..p(current.steamTripEffective),colors.lightBlue)
    end]]}
}
for i,e in ipairs(edits) do
  local a,b=src:find(e[1],1,true)
  if not a or src:find(e[1],b+1,true) then
    error("Incompatible compressed controller patch "..i,0)
  end
  src=src:sub(1,a-1)..e[2]..src:sub(b+1)
end
if test then return src end
local fn,err=load(src,"@/cc-mekanism/controller.lua","t",_ENV)
if not fn then error("Updated Lua invalid: "..tostring(err),0) end
return fn()
