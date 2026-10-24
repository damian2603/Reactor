-- Project Infinity / Mekanism Fission-Turbine-SPS Controller 4.0 beta (SPS-first antimatter optimizer)
-- CC:Tweaked 1.20.1. Standalone, no dependencies.
-- Adapted from analysis of Mekanism's CC API; inspired by cc-mek-scada's
-- fail-safe alarm philosophy. Not a copy of upstream code.
-- IMPORTANT: independent Fission Logic Adapters are still required.
local ROOT = "/cc-mekanism"
local CONF, CSV = ROOT.."/settings", ROOT.."/history_v5_thermal.csv"
if not fs.exists(ROOT) then fs.makeDir(ROOT) end
local optimizerMath=dofile(ROOT.."/optimizer_math.lua")
local thermalModel=dofile(ROOT.."/thermal_model.lua")
local defaults = {
  reactor="", turbine="", sps="", boiler="", matrix="", monitor="",
  fuelTank="", fluxLimitFE=16000000, fuelReserve=0.15,
  fuelMargin=0.90, fuelTrendSeconds=180,
  fuelRapidSeconds=30, fuelEstimateInterval=25, fuelLimitStart=0.30,
  spsFuelDeficitMinimum=1.0, spsFuelDeficitFraction=0.01,
  fuelLimitRelease=0.40, fuelGraceSeconds=45,
  spsRampSeconds=5, spsRampMaxFraction=0.02,
  spsOutputResume=0.75, spsStopOutput=0.98,
  spsNightIdleBurn=0.01, spsNightStopSeconds=0,
  fastSafetySeconds=0.2, safetyBadReads=3,
  spsFeedbackGain=0.50, spsFeedForwardMargin=0.01,
  spsManualFeCapMargin=1.10,
  sampleSeconds=1, logSeconds=10,
  historyMaxBytes=140000, historyMinFreeBytes=16000,
  historyKeepPrevious=true, -- bounded rolling CSV plus one backup segment
  maxAutoBurn=1.0, step=0.1, stepSeconds=15,
  autoBurnCeiling=0, -- 0=use detected reactor maximum; manual override only
  autoRampFraction=0.005, -- 0.5% of detected max burn per ramp interval
  tempTrip=1150, tempWarn=1100, damageTrip=0,
  thermalEnergyPerFuel=1000000, -- Project Infinity 0.1 fission Generators config
  thermalTrendSeconds=20, thermalModelBurnMargin=0.98,
  thermalMinTrendSeconds=12, thermalExpectedTolerance=55,
  thermalRequireHeatCapacity=true, -- block unverified AUTO ramps
  coolantTrip=0.60, coolantWarn=0.85, coolantDropTrip=0.08,
  wasteTrip=0.85, wasteWarn=0.68, heatedTrip=0.85, heatedWarn=0.68,
  steamTrip=0.95, steamWarn=0.89, turbineEnergyWarn=0.92,
  feTarget=0.95, feDeadband=0.025, feEnergyHigh=0.93,
  feSteamHold=0.89, feSteamThrottle=0.93,
  feRateStabilitySeconds=12, -- allow turbine flow to settle after each change
  spsInputWarn=0.85, spsOutputWarn=0.90,
  spsSolarUtilization=0.92, -- solar peak throughput headroom
  spsSteamFlowFraction=0.96, -- used only if spsTurbineFlowHardCap=true
  spsTurbineFlowHardCap=false, -- SPS prioritizes antimatter; turbine FE is secondary
  -- Project Infinity Mekanism general.toml dumpExcessKeepRatio=0.9.
  -- DUMPING_EXCESS is expected to FILL TO 90%, then vent over 90%.
  spsDumpKeepRatio=0.90, spsDumpPressureHoldLevel=0.93,
  spsDumpPressureTrimLevel=0.955, spsDumpPressureCriticalLevel=0.975,
  spsDumpPressureRecoverLevel=0.925, spsDumpSteamTrip=0.985,
  spsSteamEarlyWarn=0.50, -- fraction where rising steam buffer prevents further ramp
  spsSteamGrowthWarn=0.0004, -- legacy parameter; superseded below
  spsPressureTrendSeconds=16, -- smooth turbine steam fill observations
  spsPressureHoldLevel=0.78, -- hold ramp only on sustained rising steam
  spsPressureTrimLevel=0.88, -- gently trim when steam buffer is high
  spsPressureCriticalLevel=0.93, -- quicker trim near RPS SCRAM level
  spsPressureGrowthWarn=0.0007, -- per-second sustained rising fill
  spsPressureGrowthFast=0.005, -- require forecast overflow for early hold
  spsPressureTrimSeconds=28, -- non-emergency throttle spacing
  spsPressureTrimFraction=0.045, -- small, measured non-emergency cut
  spsPressureRecoverLevel=0.83, -- pressure hysteresis before ramp resumes
  spsBurnDeadbandAbs=4.0, -- ignore trivial fluctuations in AM-derived burn
  spsBurnDeadbandFraction=0.012,
  spsRampSteadySeconds=12, -- minimum time between SPS ramp increases
  spsDumpCoolantWarn=0.997, -- dumping excess vents steam: guard coolant reserve
  spsDumpCoolantTrip=0.98, -- stop early if water makeup cannot sustain dumping
  spsDumpCoolantDropWarn=0.0002,
  spsRateChangeSeconds=12,
  spsRampFraction=0.01, -- fraction of actual max burn rate per step
  spsNoSolarHold=true, -- require Solar Neutron Activator telemetry
  spsBufferLow=0.08, spsBufferHigh=0.22,
  spsTrendDeadband=0.000025, spsMinTrendSeconds=45,
  spsSettleSeconds=60, fuelMinSampleSeconds=120,
  safetyFlowFactor=0.78, requireTurbine=true,
  returnWaterRequired=false,
  alarmRedstoneSide="", -- optional output (e.g. "right"), true when latched
}
local c = {}
for k,v in pairs(defaults) do c[k]=v end
if fs.exists(CONF) then
  local f=fs.open(CONF,"r")
  if f then
    local ok,loaded=pcall(textutils.unserialize,f.readAll())
    f.close()
    if ok and type(loaded)=="table" then
      for k,v in pairs(defaults) do
        if type(loaded[k])==type(v) then c[k]=loaded[k] end
      end
      -- v2 used a hard default 1 mB/t; new AUTO is capped by actual
      -- structure telemetry, not the old fixed starter cap.
      if type(loaded.autoBurnCeiling)~="number" and
          type(loaded.maxAutoBurn)=="number" and loaded.maxAutoBurn>1.0 then
        c.autoBurnCeiling=loaded.maxAutoBurn
      end
      -- Migrate only the original v2.1 defaults, not customized limits.
      if loaded.steamTrip==0.86 and loaded.steamWarn==0.65 then
        c.steamTrip=0.95
        c.steamWarn=0.89
      end
      -- Legacy stock thermal pair forced 540 mB/t down despite normal
      -- heat equilibrium (~995K in 18x18x18 water-cooled reactor).
      -- Only migrate this exact original pair; keep custom stricter limits.
      if loaded.tempWarn==850 and loaded.tempTrip==1000 then
        c.tempWarn=1100
        c.tempTrip=1150
      end
    end
  end
else
  local f=fs.open(CONF,"w")
  if f then f.write(textutils.serialize(c));f.close() end
end
-- Never truncate the ONLY copy of saved settings when disk is nearly full.
local function spaceFree()
  if not fs.getFreeSpace then return nil end
  local ok,free=pcall(fs.getFreeSpace,ROOT)
  return ok and type(free)=="number" and free or nil
end
local function save()
  local body=textutils.serialize(c)
  local free=spaceFree()
  if free and free<#body+1024 then
    return false,"disk full: settings NOT saved"
  end
  local tmp=CONF..".new"
  if fs.exists(tmp) then pcall(fs.delete,tmp) end
  local ok,err=pcall(function()
    local f=assert(fs.open(tmp,"w"),"cannot open temporary settings")
    local written,reason=pcall(f.write,body)
    pcall(f.close)
    if not written then error(reason) end
    if fs.getSize and fs.getSize(tmp)~=#body then
      error("partial settings write")
    end
  end)
  if not ok then
    if fs.exists(tmp) then pcall(fs.delete,tmp) end
    return false,"settings staging failed: "..tostring(err)
  end
  local moved,moveErr=pcall(function()
    if fs.exists(CONF) then fs.delete(CONF) end
    fs.move(tmp,CONF)
  end)
  if not moved then return false,"settings rename failed: "..tostring(moveErr) end
  return true
end
local function N(x)
  if type(x)=="table" then x=x.amount or x.value or x.stored or x.energy end
  if type(x)=="string" then x=tonumber(x) or tonumber(x:match("[%d%.]+")) end
  if type(x)=="number" and x==x and x~=math.huge and x~=-math.huge then return x end
end
local function clamp(x,a,b) return math.max(a,math.min(x,b)) end
local function p(x) return N(x) and string.format("%4.1f%%",x*100) or "--.-%" end
local function n(x,d) return N(x) and string.format("%."..(d or 1).."f",x) or "--" end
local function fmt(x)
  x=N(x); if not x then return "--" end
  if math.abs(x)>=1e12 then return n(x/1e12,2).."T"
  elseif math.abs(x)>=1e9 then return n(x/1e9,2).."G"
  elseif math.abs(x)>=1e6 then return n(x/1e6,2).."M"
  elseif math.abs(x)>=1e3 then return n(x/1e3,1).."k" end
  return n(x,1)
end
local staticCache={}
local staticMethods={getLength=true,getWidth=true,getHeight=true,getFuelAssemblies=true,
  getFuelCapacity=true,getWasteCapacity=true,getCoolantCapacity=true,
  getMaxBurnRate=true,getHeatCapacity=true,getSteamCapacity=true,getMaxFlowRate=true,
  getMaxProduction=true,getMaxWaterOutput=true,getBlades=true,
  getCoils=true,getVents=true,getCondensers=true,getDispersers=true,
  getInputCapacity=true,getOutputCapacity=true,getMaxEnergy=true,
  getBoilCapacity=true,getCapacity=true,
  getTankCapacity=true}
local telemetryCache=nil
local MISSING_READ={}
local function pcRaw(name,method,...)
  if not name or not peripheral.isPresent(name) then return nil end
  local ok,v=pcall(peripheral.call,name,method,...)
  if ok then return v end
  return nil
end
local function pc(name,method,...)
  if telemetryCache and name then
    local val=telemetryCache[name.."|"..method]
    if val~=nil then
      if val==MISSING_READ then return nil end
      return val
    end
  end
  if staticMethods[method] and name and peripheral.isPresent(name) then
    local key=name.."|"..method
    local now=os.epoch("utc")/1000
    local entry=staticCache[key]
    if entry and now-entry.ts<30 then return entry.value end
    local value=pcRaw(name,method,...)
    if value~=nil then staticCache[key]={ts=now,value=value} end
    return value
  end
  return pcRaw(name,method,...)
end
local function has(name,method)
  local ok,methods=pcall(peripheral.getMethods,name)
  if not ok or type(methods)~="table" then return false end
  for _,v in ipairs(methods) do if v==method then return true end end
  return false
end
local schema={
  reactor={"setBurnRate","scram","getTemperature"},
  turbine={"getMaxFlowRate","getProductionRate"},
  sps={"getProcessRate","getInputFilledPercentage"},
  boiler={"getBoilCapacity","getSteamFilledPercentage"},
  matrix={"getLastInput","getLastOutput","getEnergyFilledPercentage"},
  monitor={"setTextScale","getSize"},
  fuelTank={"getStored","getCapacity"},
}
local order={"reactor","turbine","sps","boiler","matrix","monitor","fuelTank"}
local SPS_POLONIUM_PER_ANTIMATTER=1000
local WASTE_PER_POLONIUM=10
local SPS_JOULES_PER_POLONIUM=1000000
local JOULES_PER_FE=2.5
local names,duplicates={},{}
local function isMonitorPeripheral(name)
  -- The device type is more reliable than assuming every peripheral
  -- exposes a particular method list.
  if peripheral.hasType then
    local ok,result=pcall(peripheral.hasType,name,"monitor")
    if ok and result then return true end
  end
  local ok,kind=pcall(peripheral.getType,name)
  if ok and kind=="monitor" then return true end
  return has(name,"getSize") and has(name,"setTextScale") and has(name,"write")
end
local function discover()
  local all=peripheral.getNames()
  table.sort(all)
  names.sna={}
  for _,per in ipairs(all) do
    if has(per,"getPeakProductionRate") and
        has(per,"getProductionRate") and has(per,"canSeeSun") and
        has(per,"getInputFilledPercentage") and
        has(per,"getOutputFilledPercentage") then
      names.sna[#names.sna+1]=per
    end
  end
  for _,kind in ipairs(order) do
    local matches={}
    for _,per in ipairs(all) do
      local valid=true
      if kind=="monitor" then
        valid=isMonitorPeripheral(per)
      else
        for _,method in ipairs(schema[kind]) do
          if not has(per,method) then valid=false;break end
        end
      end
      if valid then matches[#matches+1]=per end
    end
    local selected=c[kind]
    if selected~="" then
      names[kind]=peripheral.isPresent(selected) and selected or nil
      duplicates[kind]=nil
    elseif #matches==1 then
      names[kind]=matches[1];duplicates[kind]=nil
    else
      names[kind]=nil
      duplicates[kind]=#matches>1 and table.concat(matches,", ") or nil
    end
  end
end
discover()
-- Batched telemetry. Protection uses pcRaw() and runs independently.
local sampleMethods={
  reactor={"getActualBurnRate","getBoilEfficiency","getBurnRate","getCoolant","getCoolantCapacity","getCoolantFilledPercentage","getDamagePercent","getFuelAssemblies","getFuelCapacity","getFuel","getFuelFilledPercentage","getHeatedCoolantFilledPercentage","getHeatingRate","getHeatCapacity","getHeight","getLength","getMaxBurnRate","getStatus","getTemperature","getWasteCapacity","getWasteFilledPercentage","getWidth","isForceDisabled","isFormed"},
  turbine={"getBlades","getCoils","getCondensers","getDispersers","getDumpingMode","getEnergyFilledPercentage","getFlowRate","getHeight","getLastSteamInputRate","getLength","getMaxFlowRate","getMaxProduction","getMaxWaterOutput","getProductionRate","getSteamCapacity","getSteamFilledPercentage","getVents","getWidth","isFormed"},
  boiler={"getBoilCapacity","getHeatedCoolantFilledPercentage","getSteamFilledPercentage","getWaterFilledPercentage","isFormed"},
  sps={"getCoils","getEnergy","getEnergyFilledPercentage","getMaxEnergy","getHeight","getInput","getInputCapacity","getInputFilledPercentage","getLength","getOutput","getOutputCapacity","getOutputFilledPercentage","getProcessRate","getWidth","isFormed"},
  sna={"canSeeSun","getInput","getInputFilledPercentage","getOutput","getOutputFilledPercentage","getPeakProductionRate","getProductionRate"},
  fuelTank={"getCapacity","getStored","getStoredChemical","getStoredGas","getTankCapacity"},
  matrix={"getEnergyFilledPercentage","getLastInput","getLastOutput"},
}
local function prefetchTelemetry()
  local jobs,cache={},{}
  for kind,methods in pairs(sampleMethods) do
    local devices=kind=="sna" and (names.sna or {}) or {names[kind]}
    for _,name in ipairs(devices) do
      if name and peripheral.isPresent(name) then
        for _,method in ipairs(methods) do
          if not staticMethods[method] then
            local device,api=name,method
            jobs[#jobs+1]=function()
              local value=pcRaw(device,api)
              cache[device.."|"..api]=value==nil and MISSING_READ or value
            end
          end
        end
      end
    end
  end
  if #jobs>0 then parallel.waitForAll(table.unpack(jobs)) end
  return cache
end
local mode="MANUAL" -- NEVER persist automatic operation or auto-start
local uiPage=1
local rateHistory={}
local alarmHistory={}
local lastAlarmText=""
local spsEMA=nil
local spsWindow={}
local spsInputWindow={}
local steamPressureWindow={}
local reactorTemperatureWindow={}
local steamPressureRecovery=false
local spsBaseline=nil
local fuelWindow={}
local fuelCap=nil
local fuelCapTimestamp=0
local fuelLastEstimate=0
local fuelCumulative=0
local fuelRapidWindow={}
local fuelSourceName=nil
local fuelPrevTickSample=nil
local fuelRateLimited=false
local fuelUnknownSince=0
local fastSafetyHealthy=true
local fastSafetyLast=0
local tpsEstimate=20
local telemetryBadCount=0
local stopReason=nil
local spsOutputHold=false
local spsNoSolarSince=nil
local spsThroughputLimit=nil
local spsThroughputExpires=0
local spsKnownFeLimit=0
local feTrial=nil
local feTrialResult=nil
local fuelCapTimestamp=0
local fuelSampleBurn=nil
local fuelSampleStart=0
local spsTrendResetAt=0
local spsControlWindow={}
local lastSpsDecision="WAITING FOR SAMPLES"
local lastSpsChange=0
local latched=false
local alarm,info="","Boot: MANUAL, auto-start disabled"
local current, previous = {}, nil
local recentValid=0
local lastChange,lastLog=0,0
local learnedSteamPerBurn=nil
local smoothedPowerRatio=nil
local stableSince=0
local startConfirmUntil=0
local active=true
local screen=term.current()
local buttons={}
local function redstoneAlarm(on)
  if c.alarmRedstoneSide~="" then
    pcall(redstone.setOutput,c.alarmRedstoneSide,on)
  end
end
local function trip(reason)
  latched=true;alarm=tostring(reason)
  if alarm~=lastAlarmText then
    alarmHistory[#alarmHistory+1]={time=os.epoch("utc")/1000,message=alarm}
    if #alarmHistory>30 then table.remove(alarmHistory,1) end
    lastAlarmText=alarm
  end
  mode="MANUAL"
  redstoneAlarm(true)
  if names.reactor and peripheral.isPresent(names.reactor) then
    local ok,err=pcall(peripheral.call,names.reactor,"scram")
    info=ok and "SCRAM: "..alarm or "SCRAM attempted: "..tostring(err)
  else
    info="ALARM: "..alarm.." (reactor unreachable)"
  end
end
local function burn(rate)
  local r=names.reactor
  if not r or not current.maxBurn then return false,"reactor unavailable" end
  rate=N(rate);if not rate then return false,"invalid rate" end
  rate=math.floor(clamp(rate,0,current.maxBurn)*100+0.5)/100
  local ok,err=pcall(peripheral.call,r,"setBurnRate",rate)
  return ok,ok and rate or tostring(err)
end
local function read()
  telemetryCache=prefetchTelemetry()
  local t={ts=os.epoch("utc")/1000}
  local r,u,sp,b,im=names.reactor,names.turbine,names.sps,names.boiler,names.matrix
  t.formed=pc(r,"isFormed")
  t.on=pc(r,"getStatus")
  t.burn=N(pc(r,"getBurnRate"))
  t.actual=N(pc(r,"getActualBurnRate"))
  t.maxBurn=N(pc(r,"getMaxBurnRate"))
  t.rLength=N(pc(r,"getLength"))
  t.rWidth=N(pc(r,"getWidth"))
  t.rHeight=N(pc(r,"getHeight"))
  t.assemblies=N(pc(r,"getFuelAssemblies"))
  t.boilEfficiency=N(pc(r,"getBoilEfficiency"))
  t.heatCapacity=N(pc(r,"getHeatCapacity"))
  t.fuelCapacity=N(pc(r,"getFuelCapacity"))
  t.wasteCapacity=N(pc(r,"getWasteCapacity"))
  t.coolantCapacity=N(pc(r,"getCoolantCapacity"))
  t.temp=N(pc(r,"getTemperature"))
  t.damage=N(pc(r,"getDamagePercent"))
  t.coolant=N(pc(r,"getCoolantFilledPercentage"))
  local coolantStack=pc(r,"getCoolant")
  t.coolantType=type(coolantStack)=="table" and
    tostring(coolantStack.name or coolantStack.id or "") or ""
  t.sodiumCoolant=t.coolantType:lower():find("sodium",1,true)~=nil
  t.expectedTemp=thermalModel.expected(t.actual or t.burn,
    t.heatCapacity,t.sodiumCoolant,c.thermalEnergyPerFuel)
  t.expectedAtMaxBurn=thermalModel.expected(t.maxBurn,
    t.heatCapacity,t.sodiumCoolant,c.thermalEnergyPerFuel)
  t.thermalModelCap=thermalModel.thermalCap(t.heatCapacity,
    t.sodiumCoolant,math.min(c.tempWarn,c.tempTrip-40),
    c.thermalModelBurnMargin,c.thermalEnergyPerFuel)
  t.heated=N(pc(r,"getHeatedCoolantFilledPercentage"))
  t.waste=N(pc(r,"getWasteFilledPercentage"))
  t.fuel=N(pc(r,"getFuelFilledPercentage"))
  t.steamMade=N(pc(r,"getHeatingRate"))
  t.disabled=pc(r,"isForceDisabled")
  t.tFormed=pc(u,"isFormed")
  t.steam=N(pc(u,"getSteamFilledPercentage"))
  t.flow=N(pc(u,"getFlowRate"))
  t.maxFlow=N(pc(u,"getMaxFlowRate"))
  t.tLength=N(pc(u,"getLength"))
  t.tWidth=N(pc(u,"getWidth"))
  t.tHeight=N(pc(u,"getHeight"))
  t.blades=N(pc(u,"getBlades"))
  t.coils=N(pc(u,"getCoils"))
  t.vents=N(pc(u,"getVents"))
  t.condensers=N(pc(u,"getCondensers"))
  t.dispersers=N(pc(u,"getDispersers"))
  t.maxProduction=N(pc(u,"getMaxProduction"))
  -- Mekanism CC reports J/t; this pack uses 2.5 J per FE.
  t.maxProductionFE=t.maxProduction and t.maxProduction/JOULES_PER_FE
  t.steamCapacity=N(pc(u,"getSteamCapacity"))
  t.steamIn=N(pc(u,"getLastSteamInputRate"))
  t.power=N(pc(u,"getProductionRate"))
  t.powerFE=t.power and t.power/JOULES_PER_FE
  t.energy=N(pc(u,"getEnergyFilledPercentage"))
  if t.power and t.maxProduction and t.maxProduction>0 then
    t.productionFraction=clamp(t.power/t.maxProduction,0,5)
  end
  t.waterOut=N(pc(u,"getMaxWaterOutput"))
  t.dump=pc(u,"getDumpingMode")
  t.dumpExcess=t.dump~=nil and tostring(t.dump):lower():find("excess",1,true)~=nil
  t.steamDumpKeepRatio=t.dumpExcess and c.spsDumpKeepRatio or nil
  t.steamDumpingActive=t.dumpExcess and t.steam and
    t.steam>=c.spsDumpKeepRatio or false
  t.steamTripEffective=t.dumpExcess and c.spsDumpSteamTrip or c.steamTrip
  if t.dumpExcess and t.steamMade and t.flow and not t.sodiumCoolant then
    -- Heat-to-steam conversion minus condensed turbine flow. Conservative
    -- indication of possible missing water recycling, NOT measured venting.
    t.waterReturnGapEstimate=math.max(0,t.steamMade-t.flow)
  end
  t.bFormed=pc(b,"isFormed")
  t.bSteam=N(pc(b,"getSteamFilledPercentage"))
  t.bHot=N(pc(b,"getHeatedCoolantFilledPercentage"))
  t.bWater=N(pc(b,"getWaterFilledPercentage"))
  t.bBoilCapacity=N(pc(b,"getBoilCapacity"))
  t.spFormed=pc(sp,"isFormed")
  t.spInput=N(pc(sp,"getInputFilledPercentage"))
  t.spOutput=N(pc(sp,"getOutputFilledPercentage"))
  t.spRate=N(pc(sp,"getProcessRate"))
  t.spEnergyFill=N(pc(sp,"getEnergyFilledPercentage"))
  t.spEnergyStored=N(pc(sp,"getEnergy"))
  t.spMaxEnergy=N(pc(sp,"getMaxEnergy"))
  t.spInputAmount=N(pc(sp,"getInput"))
  t.spOutputAmount=N(pc(sp,"getOutput"))
  t.spEnergyUsedFE=optimizerMath.feForAntimatter(t.spRate,
    SPS_POLONIUM_PER_ANTIMATTER,SPS_JOULES_PER_POLONIUM,JOULES_PER_FE)
  t.spFeRequiredBurn=optimizerMath.feForBurn(t.actual or t.burn,
    JOULES_PER_FE,WASTE_PER_POLONIUM,SPS_JOULES_PER_POLONIUM)
  t.spFeRequiredSetpoint=optimizerMath.feForBurn(t.burn,
    JOULES_PER_FE,WASTE_PER_POLONIUM,SPS_JOULES_PER_POLONIUM)
  t.spLength=N(pc(sp,"getLength"))
  t.spWidth=N(pc(sp,"getWidth"))
  t.spHeight=N(pc(sp,"getHeight"))
  t.spCoils=N(pc(sp,"getCoils"))
  t.spInputCapacity=N(pc(sp,"getInputCapacity"))
  t.spOutputCapacity=N(pc(sp,"getOutputCapacity"))
  -- Sum production potential from ALL connected Solar Neutron Activators.
  -- getProductionRate() is weather/sun/biome dependent: capacity, not
  -- guaranteed actual output if waste input is missing or output is blocked.
  t.snaCount=#(names.sna or {})
  t.snaActive=0
  t.snaSun=0
  t.snaBroken=0
  t.snaPeak=0
  t.snaProduction=0
  t.snaMaxOutputFill=0
  t.snaMaxInputFill=0
  t.snaTotalOutput=0
  t.snaTotalInput=0
  for _,dev in ipairs(names.sna or {}) do
    local rate=N(pc(dev,"getProductionRate"))
    local peak=N(pc(dev,"getPeakProductionRate"))
    local inFill=N(pc(dev,"getInputFilledPercentage"))
    local outFill=N(pc(dev,"getOutputFilledPercentage"))
    local gasIn=N(pc(dev,"getInput"))
    local gasOut=N(pc(dev,"getOutput"))
    local sunlight=pc(dev,"canSeeSun")
    if rate==nil or peak==nil or inFill==nil or outFill==nil or sunlight==nil then
      t.snaBroken=t.snaBroken+1
    else
      t.snaPeak=t.snaPeak+math.max(0,peak)
      t.snaMaxInputFill=math.max(t.snaMaxInputFill,inFill)
      t.snaMaxOutputFill=math.max(t.snaMaxOutputFill,outFill)
      t.snaTotalOutput=t.snaTotalOutput+(gasOut or 0)
      t.snaTotalInput=t.snaTotalInput+(gasIn or 0)
      if sunlight then t.snaSun=t.snaSun+1 end
      if rate>0 then t.snaActive=t.snaActive+1 end
      -- A blocked output prevents useful conversion even when peak speed
      -- remains high. Avoid demanding more waste when output cannot leave.
      if outFill<0.90 then t.snaProduction=t.snaProduction+math.max(0,rate) end
    end
  end
  t.snaWasteCapacity=t.snaProduction*WASTE_PER_POLONIUM
  t.snaAntimatterPotential=t.snaProduction/SPS_POLONIUM_PER_ANTIMATTER
  t.fissionAntimatterPotential=t.actual and
      t.actual/(WASTE_PER_POLONIUM*SPS_POLONIUM_PER_ANTIMATTER) or nil
  t.spsEfficiency=t.spRate and t.fissionAntimatterPotential and
      t.fissionAntimatterPotential>0 and
      t.spRate/t.fissionAntimatterPotential or nil
  -- This is the equivalent SPS FE spent on observed processing;
  -- it is NOT a direct measurement of incoming FE at the SPS coils.
  local ft=names.fuelTank
  t.fuelStored=N(pc(ft,"getStored")) or N(pc(ft,"getStoredGas")) or N(pc(ft,"getStoredChemical"))
  t.fuelTankCapacity=N(pc(ft,"getCapacity")) or N(pc(ft,"getTankCapacity"))
  t.reactorFuelAmount=N(pc(r,"getFuel"))
  t.fuelSource=t.fuelStored~=nil and "TANK" or
    (t.reactorFuelAmount~=nil and "REACTOR" or nil)
  t.fuelAvailable=t.fuelStored or t.reactorFuelAmount
  t.fuelTankFill=t.fuelStored and t.fuelTankCapacity and t.fuelTankCapacity>0 and
    clamp(t.fuelStored/t.fuelTankCapacity,0,1) or nil
  t.imEnergy=N(pc(im,"getEnergyFilledPercentage"))
  t.imIn=N(pc(im,"getLastInput"));t.imOut=N(pc(im,"getLastOutput"))
  t.imInFE=t.imIn and t.imIn/JOULES_PER_FE
  t.imOutFE=t.imOut and t.imOut/JOULES_PER_FE
  -- Smoothed pressure trend: never react to a one-tick blip at 64% steam.
  if t.steam~=nil then
    steamPressureWindow[#steamPressureWindow+1]={ts=t.ts,value=t.steam}
    while #steamPressureWindow>1 and
        t.ts-steamPressureWindow[1].ts>c.spsPressureTrendSeconds do
      table.remove(steamPressureWindow,1)
    end
    local origin=steamPressureWindow[1]
    local elapsed=t.ts-origin.ts
    if elapsed>=c.spsPressureTrendSeconds*0.6 then
      t.steamTrend=(t.steam-origin.value)/elapsed
      t.steamTrendWindow=elapsed
    end
  else
    steamPressureWindow={}
  end
  -- Slow thermal physics: evaluate 12-20 second Kelvin/sec slopes.
  if t.temp~=nil then
    reactorTemperatureWindow[#reactorTemperatureWindow+1]={
      ts=t.ts,value=t.temp}
    while #reactorTemperatureWindow>1 and
        t.ts-reactorTemperatureWindow[1].ts>c.thermalTrendSeconds do
      table.remove(reactorTemperatureWindow,1)
    end
    local first=reactorTemperatureWindow[1]
    local dt=t.ts-first.ts
    if dt>=c.thermalMinTrendSeconds then
      t.tempTrend=(t.temp-first.value)/dt
      t.tempTrendSeconds=dt
    end
  else
    reactorTemperatureWindow={}
  end
  local model=thermalModel.assess({
    temp=t.temp,trend=t.tempTrend,
    burn=t.actual or t.burn,heatCapacity=t.heatCapacity,
    isSodium=t.sodiumCoolant,energyPerFuel=c.thermalEnergyPerFuel,
    warn=c.tempWarn,trip=c.tempTrip,
    errorTolerance=c.thermalExpectedTolerance
  })
  t.thermalState=model.state
  t.thermalReason=model.reason
  t.thermalExpectedError=model.errorK
  t.thermalWarnEffective=model.softWarn
  t.thermalTripEffective=model.hardTrip
  if previous then
    local dt=t.ts-previous.ts
    if dt>0.2 and dt<15 then
      for _,field in ipairs({"coolant","waste","heated","steam","energy","spInput"}) do
        if t[field] and previous[field] then t[field.."Delta"]=(t[field]-previous[field])/dt end
      end
    end
  end
  t.spsDiagnosis="DATA INCOMPLETE"
  if t.spOutput and t.spOutput>=c.spsOutputWarn then
    t.spsDiagnosis="EMPTY ANTIMATTER OUTPUT"
  elseif t.snaCount==0 then
    t.spsDiagnosis="CONNECT SNA MODEMS"
  elseif t.snaBroken>0 then
    t.spsDiagnosis="SOLAR TELEMETRY LOST"
  elseif t.snaProduction<=0 then
    t.spsDiagnosis="SNA OFFLINE / NIGHT / WEATHER"
  elseif t.snaMaxOutputFill>=0.90 then
    t.spsDiagnosis="POLONIUM PIPE / EXTRACTION"
  elseif t.waste and t.waste>=0.25 and t.wasteDelta and
       t.wasteDelta>0.001 then
    t.spsDiagnosis="SNA TOO SLOW / WASTE TRANSFER"
  elseif t.spInput and t.spInput>=0.15 and
       t.spEnergyFill and t.spEnergyFill<0.05 and t.spRate and
       t.fissionAntimatterPotential and
       t.spRate<t.fissionAntimatterPotential*0.85 then
    t.spsDiagnosis="SPS FE SUPPLY / COILS LIMIT SUSPECTED"
  elseif t.spInput and t.spInput>=0.40 and t.spRate and
       t.fissionAntimatterPotential and
       t.spRate<t.fissionAntimatterPotential*0.75 then
    t.spsDiagnosis="SPS COIL FE / PROCESSING LIMIT"
  elseif t.spInput and t.spInput<0.07 and t.spsEfficiency and
       t.spsEfficiency<0.75 then
    t.spsDiagnosis="SPS POLONIUM STARVED"
  elseif t.steam and (not t.dumpExcess and t.steam>=c.feSteamHold or
      t.dumpExcess and t.steam>=c.spsDumpPressureTrimLevel) then
    t.spsDiagnosis="TURBINE STEAM BACKPRESSURE"
  else
    t.spsDiagnosis="SPS RUNNING / BALANCED"
  end
  t.tps=tpsEstimate
  if t.spRate then
    rateHistory[#rateHistory+1]={time=t.ts,rate=t.spRate,input=t.spInput}
    if #rateHistory>300 then table.remove(rateHistory,1) end
  end
  if t.spRate then
    spsEMA=spsEMA and (0.18*t.spRate+0.82*spsEMA) or t.spRate
    t.spRateEMA=spsEMA
    spsWindow[#spsWindow+1]={time=t.ts,rate=t.spRate}
    while #spsWindow>0 and t.ts-spsWindow[1].time>120 do table.remove(spsWindow,1) end
    local sum=0
    for _,v in ipairs(spsWindow) do sum=sum+v.rate end
    t.spRate120=sum/#spsWindow
    t.spWindowSeconds=t.ts-spsWindow[1].time
    if t.spInput~=nil then
      spsInputWindow[#spsInputWindow+1]={time=t.ts,value=t.spInput}
      while #spsInputWindow>0 and t.ts-spsInputWindow[1].time>120 do table.remove(spsInputWindow,1) end
      local first=spsInputWindow[1]
      if #spsInputWindow>=2 and t.ts-first.time>=20 then
        t.spInputTrend120=(t.spInput-first.value)/(t.ts-first.time)
      end
      if t.ts-spsTrendResetAt>=c.spsSettleSeconds then
        spsControlWindow[#spsControlWindow+1]={time=t.ts,value=t.spInput}
        while #spsControlWindow>1 and t.ts-spsControlWindow[1].time>c.spsMinTrendSeconds do
          table.remove(spsControlWindow,1)
        end
        local start=spsControlWindow[1]
        if #spsControlWindow>=2 and t.ts-start.time>=c.spsMinTrendSeconds*0.9 then
          t.spInputControlTrend=(t.spInput-start.value)/(t.ts-start.time)
          t.spControlSeconds=t.ts-start.time
        end
      end
    end
  end
  if #rateHistory>=2 then
    local first=rateHistory[1]
    local total=0
    for _,v in ipairs(rateHistory) do total=total+v.rate end
    t.spRateAverage=total/#rateHistory
    t.spRateTrend=t.spRate-first.rate
  end
  -- Integrate actual fuel use across setpoint changes. This avoids the
  -- calibration never completing when SPS AUTO is actively ramping.
  -- Tank is preferred: the user's Mekanism pipes remain filled first.
  local fuelName=t.fuelSource
  if t.fuelAvailable~=nil and t.actual~=nil and t.on==true then
    if fuelSourceName~=fuelName or not fuelPrevTickSample or
        (previous and previous.on~=true) then
      fuelWindow={}
      fuelRapidWindow={}
      fuelCumulative=0
      fuelSourceName=fuelName
      fuelPrevTickSample=nil
      fuelCap=nil
      fuelCapTimestamp=0
    end
    if fuelPrevTickSample then
      local seconds=t.ts-fuelPrevTickSample.ts
      if seconds>0 and seconds<60 then
        fuelCumulative=fuelCumulative+
          ((t.actual+fuelPrevTickSample.actual)/2)*seconds*tpsEstimate
      end
    end
    fuelPrevTickSample={ts=t.ts,actual=t.actual}
    fuelWindow[#fuelWindow+1]={
      ts=t.ts,amount=t.fuelAvailable,consumed=fuelCumulative,
      fill=t.fuelTankFill or t.fuel
    }
    fuelRapidWindow[#fuelRapidWindow+1]={
      ts=t.ts,amount=t.fuelAvailable,consumed=fuelCumulative
    }
    while #fuelRapidWindow>1 and
        t.ts-fuelRapidWindow[1].ts>c.fuelRapidSeconds do
      table.remove(fuelRapidWindow,1)
    end
    local rapidStart=fuelRapidWindow[1]
    local rapidDt=t.ts-rapidStart.ts
    if rapidDt>=c.fuelRapidSeconds*0.75 then
      local rapidTicks=rapidDt*tpsEstimate
      t.fuelRapidNet=(t.fuelAvailable-rapidStart.amount)/rapidTicks
      t.fuelRapidProduction=optimizerMath.fuelProduction(
        fuelCumulative-rapidStart.consumed,
        t.fuelAvailable-rapidStart.amount,rapidTicks)
    end
    while #fuelWindow>1 and t.ts-fuelWindow[1].ts>c.fuelTrendSeconds do
      table.remove(fuelWindow,1)
    end
    local first=fuelWindow[1]
    local seconds=t.ts-first.ts
    local ticks=seconds*tpsEstimate
    if seconds>=c.fuelRapidSeconds and ticks>0 then
      t.fuelNetPerTick=(t.fuelAvailable-first.amount)/ticks
      t.fuelProducedEstimate=optimizerMath.fuelProduction(
        fuelCumulative-first.consumed,t.fuelAvailable-first.amount,ticks)
      t.fuelSampleSeconds=seconds
      -- A full or empty tank hides true inflow: do not treat it as
      -- a reliable calibrated production cap near either boundary.
      local fill=t.fuelTankFill or t.fuel
      if seconds>=c.fuelMinSampleSeconds and
          t.ts-fuelLastEstimate>=c.fuelEstimateInterval and
          first.fill and first.fill>0.04 and first.fill<0.96 and
          fill and fill>0.04 and fill<0.96 and
          t.fuelProducedEstimate>0 then
        fuelCap=fuelCap and
          (0.65*fuelCap+0.35*t.fuelProducedEstimate) or
          t.fuelProducedEstimate
        fuelCapTimestamp=t.ts
        fuelLastEstimate=t.ts
      end
    end
  else
    fuelWindow={}
    fuelRapidWindow={}
    fuelSourceName=nil
    fuelPrevTickSample=nil
    fuelCumulative=0
  end
  t.fuelCap=fuelCap
  t.fuelCapFresh=fuelCapTimestamp>0 and t.ts-fuelCapTimestamp<300
  t.fuelMeasured=t.fuelAvailable~=nil
  t.fuelFillForControl=t.fuelTankFill or t.fuel
  if t.fuelFillForControl and t.fuelFillForControl<c.fuelLimitStart then
    fuelRateLimited=true
  elseif t.fuelFillForControl and t.fuelFillForControl>=c.fuelLimitRelease then
    fuelRateLimited=false
  end
  t.fuelRateLimited=fuelRateLimited
  if t.fuelMeasured then fuelUnknownSince=0
  elseif fuelUnknownSince==0 then fuelUnknownSince=t.ts end
  t.fuelMeterLostFor=fuelUnknownSince>0 and t.ts-fuelUnknownSince or 0
  local observedFE=optimizerMath.feForAntimatter(
    t.spRate120 or t.spRate,SPS_POLONIUM_PER_ANTIMATTER,
    SPS_JOULES_PER_POLONIUM,JOULES_PER_FE)
  -- Opportunity is the physical/Solar ceiling with known fuel constraints.
  -- At full tank, Fissile Fuel output is NOT proven: mark opportunity
  -- conditional rather than claiming an obtainable optimum.
  local opportunityBurn=t.maxBurn or 0
  if c.autoBurnCeiling>0 then
    opportunityBurn=math.min(opportunityBurn,c.autoBurnCeiling)
  end
  if t.snaWasteCapacity and t.snaCount>0 then
    opportunityBurn=math.min(opportunityBurn,
      t.snaWasteCapacity*c.spsSolarUtilization)
  else
    opportunityBurn=0
  end
  if t.thermalModelCap then
    opportunityBurn=math.min(opportunityBurn,t.thermalModelCap)
  end
  local verifiedFuel=t.fuelCapFresh and t.fuelCap~=nil
  if verifiedFuel then
    opportunityBurn=math.min(opportunityBurn,t.fuelCap*c.fuelMargin)
  end
  if t.fuelRapidProduction and t.fuelRapidNet and t.actual and
      t.fuelRapidNet < -math.max(1,t.actual*0.01) then
    opportunityBurn=math.min(opportunityBurn,
      t.fuelRapidProduction*c.fuelMargin)
    verifiedFuel=true
  end
  t.feOpportunityBurn=opportunityBurn
  t.fePotentialRequired=optimizerMath.feForBurn(opportunityBurn,
    JOULES_PER_FE,WASTE_PER_POLONIUM,SPS_JOULES_PER_POLONIUM)
  local feOpportunitySafe=t.temp and t.temp<c.tempWarn and
    t.coolant and t.coolant>=c.coolantWarn and
    t.heated and t.heated<c.heatedWarn and
    t.waste and t.waste<c.wasteWarn and
    t.spOutput and t.spOutput<c.spsOutputWarn and
    t.snaProduction and t.snaProduction>0
  local assessment=optimizerMath.assessFE({
    limitFE=c.fluxLimitFE,
    neededFE=t.spFeRequiredSetpoint,
    usedFE=observedFE,
    poloniumFill=t.spInput,
    poloniumTrend=t.spInputTrend120,
    energyFill=t.spEnergyFill,
    outputFill=t.spOutput,
    opportunityFE=feOpportunitySafe and t.fePotentialRequired or nil,
    fuelVerified=verifiedFuel
  })
  t.feState=assessment.state
  t.feAdvice=assessment.text
  t.feSuggestedLimit=assessment.trialFE
  t.feShortfall=assessment.shortfallFE
  t.feEquivalentObserved=assessment.observedEquivalentFE
  t.feLimitedRate=c.fluxLimitFE>0 and
    c.fluxLimitFE*JOULES_PER_FE/
    (SPS_POLONIUM_PER_ANTIMATTER*SPS_JOULES_PER_POLONIUM) or nil
  -- A change in SPS buffered energy + theoretical processing energy estimates
  -- input to SPS. This is NOT a Flux Point throughput measurement.
  if previous and t.spEnergyStored and previous.spEnergyStored and
      t.spRate and t.ts>previous.ts and t.ts-previous.ts<30 then
    local energyDeltaFE=(t.spEnergyStored-previous.spEnergyStored)/
      ((t.ts-previous.ts)*tpsEstimate*JOULES_PER_FE)
    t.feDeliveryInferred=math.max(0,(t.spEnergyUsedFE or 0)+energyDeltaFE)
  end
  if feTrial then
    local age=t.ts-feTrial.started
    if age<180 then
      t.feAdvice="FE TRIAL: "..n(math.max(0,180-age),0).."s remaining"
    elseif t.spRate120 and t.spWindowSeconds and t.spWindowSeconds>=110 then
      local gain=t.spRate120-feTrial.beforeRate
      local percent=feTrial.beforeRate>0 and
        gain/feTrial.beforeRate*100 or 0
      local deltaFE=feTrial.newLimit-feTrial.oldLimit
      if deltaFE>0 then
        feTrialResult=gain>math.max(0.0005,feTrial.beforeRate*0.025) and
          ("FE + "..fmt(deltaFE)..": AM +"..n(percent,2).."% (benefit)") or
          ("FE + "..fmt(deltaFE)..": little AM gain; consider reverting")
      elseif deltaFE<0 then
        feTrialResult=gain>=-math.max(0.0005,feTrial.beforeRate*0.02) and
          ("LOWER FE: AM stable; keep lower cap") or
          ("LOWER FE: AM loss "..n(percent,2).."%")
      else feTrialResult="FE limit unchanged" end
      local path=ROOT.."/fe_trials.csv"
      local logged,logError=pcall(function()
        local existed=fs.exists(path)
        local f=assert(fs.open(path,"a"),"FE CSV unavailable")
        local success,err=pcall(function()
          if not existed then
            f.writeLine("timestamp,old_limit_fe,new_limit_fe,before_am_per_tick,after_am_per_tick,change_percent")
          end
          f.writeLine(table.concat({
            tostring(math.floor(t.ts)),tostring(feTrial.oldLimit),
            tostring(feTrial.newLimit),tostring(feTrial.beforeRate),
            tostring(t.spRate120),tostring(percent)},","))
        end)
        pcall(f.close)
        if not success then error(err) end
      end)
      if not logged then t.storageWarning="FE trial CSV write failed: "..tostring(logError) end
      feTrial=nil
      t.feAdvice=feTrialResult
    else t.feAdvice="FE TRIAL: WAIT FOR STABLE AM WINDOW" end
  elseif feTrialResult then
    t.feAdvice=feTrialResult
  end
  previous=t
  telemetryCache=nil
  return t
end
local function required(t)
  if not names.reactor then return false,duplicates.reactor and "multiple reactors: configure settings" or "reactor disconnected" end
  local fields={"formed","on","burn","actual","maxBurn","temp","damage","coolant","heated","waste","fuel"}
  for _,field in ipairs(fields) do if t[field]==nil then return false,"reactor read failed: "..field end end
  if t.formed~=true then return false,"reactor not formed" end
  if c.requireTurbine then
    if not names.turbine then return false,"turbine disconnected/ambiguous" end
    if t.tFormed~=true or t.steam==nil or t.maxFlow==nil or t.energy==nil then
      return false,"turbine telemetry failed"
    end
  end
  return true
end
local function safety(t)
  local good,why=required(t)
  if not good then return false,why end
  if t.disabled==true then return false,"reactor force disabled" end
  if t.temp>=math.min(c.tempTrip,1150) then
    return false,"reactor temperature reached software SCRAM threshold"
  end
  if t.damage>c.damageTrip then return false,"reactor damage" end
  if t.coolant<c.coolantTrip then return false,"coolant too low" end
  if t.dumpExcess and t.coolant<c.spsDumpCoolantTrip then
    return false,"water reserve critical while turbine dumps steam"
  end
  if t.waste>=c.wasteTrip then return false,"nuclear waste full" end
  if t.heated>=c.heatedTrip then return false,"heated coolant full" end
  if t.steam and t.steam>=t.steamTripEffective then
    return false,"turbine steam near full (dump-aware)" end
  if t.bSteam and t.bSteam>=c.steamTrip then return false,"boiler steam full" end
  if t.bHot and t.bHot>=c.heatedTrip then return false,"boiler heated coolant full" end
  if t.coolantDelta and t.coolantDelta<=-c.coolantDropTrip then return false,"coolant dropping quickly" end
  return true
end
local function bottleneck(t)
  local reasons={}
  local function add(test,msg) if test then reasons[#reasons+1]=msg end end
  -- Steam is a pressure/buffer safety parameter, not a standalone
  -- reason to reduce power if the turbine is still ramping normally.
  add(t.temp and t.temp>=c.tempWarn,"TEMP")
  add(t.coolant and t.coolant<c.coolantWarn,"COOLANT")
  add(t.coolantDelta and t.coolantDelta< -0.004,"COOLANT FALL")
  add(t.dumpExcess and t.coolant and t.coolant<c.spsDumpCoolantWarn,
    "DUMPING STEAM: WATCH MAKEUP WATER")
  add(t.waste and t.waste>=c.wasteWarn,"WASTE OUT")
  add(t.wasteDelta and t.wasteDelta>0.001,"WASTE GROWTH")
  add(t.heated and t.heated>=c.heatedWarn,"HOT COOLANT")
  add(t.bSteam and t.bSteam>=c.steamWarn,"BOILER STEAM")
  add(t.bHot and t.bHot>=c.heatedWarn,"BOILER HOT")
  add(mode=="FE" and t.energy and t.energy>=c.feEnergyHigh,"ENERGY OUTPUT BLOCKED")
  add(mode=="FE" and t.imEnergy and t.imEnergy>=0.98,"MATRIX NEAR FULL")
  add(mode=="SPS" and t.spInput and t.spInput>=c.spsInputWarn,"POLONIUM BUFFER")
  add(mode=="SPS" and t.snaMaxOutputFill and t.snaMaxOutputFill>0.9,"SOLAR TRANSFER")
  add(mode=="SPS" and t.spOutput and t.spOutput>=c.spsOutputWarn,"ANTIMATTER OUT")
  add(t.fuel and t.fuel<0.05,"LOW FUEL")
  return table.concat(reasons,", ")
end
local function safeCap(t,flowFraction,applyTurbineFlowCap)
  local cap=t.maxBurn or 0
  flowFraction=flowFraction or c.feTarget
  if applyTurbineFlowCap==nil then applyTurbineFlowCap=true end
  if c.autoBurnCeiling>0 then cap=math.min(cap,c.autoBurnCeiling) end
  -- Empirical steam-to-burn conversion: only direct-water-cooled fission.
  -- For sodium cooling, a separate boiler converts heat to steam.
  if applyTurbineFlowCap and t.bFormed~=true and not t.sodiumCoolant and
      t.actual and t.actual>0.09 and
      t.steamMade and t.steamMade>0 then
    local observed=t.steamMade/t.actual
    if observed>50 and observed<2000000 then
      learnedSteamPerBurn=learnedSteamPerBurn and
        (learnedSteamPerBurn*0.85+observed*0.15) or observed
    end
  end
  -- The soft cap is based on usable turbine steam FLOW, not how full the
  -- steam tank is. Target up to 95% of the turbine's generation potential.
  if applyTurbineFlowCap and t.bFormed~=true and not t.sodiumCoolant and
      learnedSteamPerBurn and
      t.maxFlow and t.maxFlow>0 then
    cap=math.min(cap,t.maxFlow*flowFraction/learnedSteamPerBurn)
    if c.returnWaterRequired and t.waterOut and t.waterOut>0 then
      cap=math.min(cap,t.waterOut*0.95/learnedSteamPerBurn)
    end
  end
  return math.floor(math.max(0,cap)*100+0.5)/100
end
-- Deliberate process stop. No automatic reactor re-start.
local function processStop(reason)
  if mode=="MANUAL" then return end
  mode="MANUAL"
  stopReason=reason
  local ok,err=pcall(peripheral.call,names.reactor,"scram")
  info=ok and ("SPS STOP: "..reason.." | manual START required") or
    ("SPS STOP SCRAM FAILED: "..tostring(err))
end

local function autoSPS(t)
  if not names.sps or t.spFormed~=true or t.spRate==nil or
      t.spInput==nil or t.spOutput==nil then
    mode="MANUAL";info="SPS AUTO paused: SPS telemetry lost";return
  end
  if t.snaCount==0 or t.snaBroken>0 then
    t.limit="HOLD: INCOMPLETE SOLAR TELEMETRY"
    info=t.limit
    return
  end
  if t.sodiumCoolant and not names.boiler then
    mode="MANUAL";info="SPS AUTO requires sodium boiler";return
  end
  if t.burn==nil or t.maxBurn==nil or t.actual==nil then return end
  if not t.fuelMeasured then
    t.limit="HOLD: NO FISSILE FUEL INVENTORY READ"
    info=t.limit
    if t.fuelMeterLostFor>=c.fuelGraceSeconds then
      mode="MANUAL";info="SPS AUTO disabled: no fuel measurement"
    end
    return
  end
  if not fastSafetyHealthy or t.ts-fastSafetyLast>8 then
    t.limit="HOLD: SAFETY TELEMETRY UNAVAILABLE"
    info=t.limit
    return
  end

  if t.fuelFillForControl and t.fuelFillForControl<0.03 and
      t.fuelRapidNet and t.fuelRapidNet< -0.001 then
    processStop("FISSILE FUEL RESERVE EXHAUSTED")
    return
  end
  if t.spOutput>=c.spsStopOutput then
    processStop("ANTIMATTER OUTPUT FULL")
    return
  end
  if t.snaProduction<=0 then
    if not spsNoSolarSince then spsNoSolarSince=t.ts end
    if c.spsNightStopSeconds>0 and
        t.ts-spsNoSolarSince>=c.spsNightStopSeconds then
      processStop("NO SOLAR POLONIUM SUPPLY")
      return
    end
    -- Upstream SCADA-style automatic idle: at night or in rain do not
    -- waste fissile fuel, and do not require a risky automatic restart.
    -- Reactors stay active at the minimum accepted Mekanism burn rate.
    local idle=clamp(c.spsNightIdleBurn,0.01,0.1)
    if t.burn>idle+0.009 then
      local ok,err=burn(idle)
      if not ok then
        mode="MANUAL";info="SPS IDLE setBurnRate failed: "..tostring(err)
        return
      end
      lastChange=t.ts
      spsTrendResetAt=t.ts
      spsControlWindow={}
    end
    t.safeCap=idle
    t.limit="IDLE: NO SOLAR POLONIUM PRODUCTION"
    lastSpsDecision=t.limit
    info=t.limit.." | automatic ramp resumes with sunlight"
    return
  else
    spsNoSolarSince=nil
  end
  if t.spOutput>=c.spsOutputWarn then spsOutputHold=true
  elseif t.spOutput<=c.spsOutputResume then spsOutputHold=false end

  -- Three independent constraints: physics/heat, solar conversion,
  -- available fissile fuel. Manual Flux Point cap is a soft estimate.
  local turbineHardCap=c.spsTurbineFlowHardCap==true
  local cap=safeCap(t,c.spsSteamFlowFraction,turbineHardCap)
  local capReason=turbineHardCap and "REACTOR / TURBINE" or
    "REACTOR / MANUAL CEILING"
  t.spsTurbineFlowHardCap=turbineHardCap
  local function limitCap(value,source)
    if value and value<cap-0.009 then cap=value;capReason=source end
  end
  if t.snaProduction>0 then
    limitCap(t.snaWasteCapacity*
      clamp(c.spsSolarUtilization,0.5,1),"SOLAR ACTIVATORS")
  end
  -- This cap is derived from the reactor's measured heat capacity,
  -- not from a flat 850K warning. It prevents finding an SPS "optimum"
  -- at temperatures that would exceed our 1100K thermal soft ceiling.
  if t.thermalModelCap then
    limitCap(t.thermalModelCap,"THERMAL EQUILIBRIUM MODEL")
  end
  if c.fluxLimitFE~=spsKnownFeLimit then
    spsThroughputLimit=nil
    spsThroughputExpires=0
    spsKnownFeLimit=c.fluxLimitFE
  end
  if c.fluxLimitFE>0 then
    local feBurn=optimizerMath.feBurnLimit(c.fluxLimitFE,
      JOULES_PER_FE,WASTE_PER_POLONIUM,SPS_JOULES_PER_POLONIUM,
      c.spsManualFeCapMargin)
    limitCap(feBurn,"FLUX FE REFERENCE")
  end
  if t.fuelCapFresh and t.fuelCap then
    limitCap(t.fuelCap*c.fuelMargin,"FUEL PRODUCTION (LONG)")
  end
  -- Deficit detected while the Elite Tank is still >30% must ALSO cap
  -- burn: waiting for the low-fuel threshold could waste large reserves.
  -- Use only a measured 30s trend and a material (>1%) deficit.
  local fuelDeficit,fuelDeficitThreshold=optimizerMath.fuelDeficit(
    t.fuelRapidNet,t.actual,c.spsFuelDeficitMinimum,c.spsFuelDeficitFraction)
  t.fuelDeficitThreshold=fuelDeficitThreshold
  t.fuelDeficitMaterial=fuelDeficit
  local rapidDeficit=fuelDeficit and t.fuelRapidProduction~=nil
  if rapidDeficit then
    limitCap(math.max(0.01,t.fuelRapidProduction*c.fuelMargin),
      "FUEL PRODUCTION (RAPID)")
    t.fuelRapidLimited=true
  end
  if spsThroughputLimit and t.ts<spsThroughputExpires then
    limitCap(spsThroughputLimit,"SPS PROCESSING PLATEAU")
    t.spsLearnedThroughputCap=spsThroughputLimit
  end
  -- The short-term falling inventory is evidence of fuel starvation,
  -- even while the long 120s estimate is still warming up.
  local tankFill=t.fuelFillForControl
  if t.fuelRateLimited and t.fuelRapidProduction then
    limitCap(math.max(0.01,t.fuelRapidProduction*c.fuelMargin),
      "LOW FUEL RESERVE")
  elseif tankFill and tankFill<c.fuelReserve and
      t.fuelNetPerTick and t.fuelNetPerTick<0 then
    limitCap(math.max(0.01,t.actual*0.85),"LOW FUEL EMERGENCY")
  end
  cap=math.max(0.01,math.floor(cap*100+0.5)/100)
  t.safeCap=cap
  t.spsCapReason=capReason
  t.spsTargetRate=cap/(WASTE_PER_POLONIUM*SPS_POLONIUM_PER_ANTIMATTER)
  t.spsTargetFE=t.spsTargetRate*SPS_POLONIUM_PER_ANTIMATTER*
    SPS_JOULES_PER_POLONIUM/JOULES_PER_FE

  -- Feed-forward: SPS produces AM from Polonium generated by nuclear waste.
  -- Burn 10,000 mB/t sustains 1 mB/t AM at standard Mekanism ratios.
  -- Critically, a low-but-stable 2% Polonium buffer is NOT starvation.
  local amRate=(t.spWindowSeconds and t.spWindowSeconds>=45 and t.spRate120)
      or t.spRateEMA or t.spRate or 0
  local base=optimizerMath.spsBurn(amRate,WASTE_PER_POLONIUM,
    SPS_POLONIUM_PER_ANTIMATTER)
  local bootstrap=math.min(cap,math.max(2,math.min(25,cap*0.06)))
  local desired=base>0 and base*(1+c.spsFeedForwardMargin) or bootstrap
  -- If SPS consumes almost all production, safely probe for more AM throughput.
  -- A stable low (e.g. 2%) Polonium buffer is not by itself starvation.
  local usingSupply=t.spsEfficiency and t.spsEfficiency>=0.92 and
      t.spInput<0.30 and t.spOutput<c.spsOutputWarn and
      (not t.spInputTrend120 or t.spInputTrend120<=c.spsTrendDeadband)
  if usingSupply and not t.fuelRateLimited then
    desired=math.max(desired,math.min(cap,t.burn+math.max(1,t.maxBurn*0.02)))
  end
  local processingSaturated=t.spsEfficiency and t.spsEfficiency<0.92 and
      (t.spInput>0.15 or
       t.spInputControlTrend and t.spInputControlTrend>c.spsTrendDeadband or
       t.spInputTrend120 and t.spInputTrend120>c.spsTrendDeadband)
  if processingSaturated and t.spWindowSeconds and t.spWindowSeconds>=60 then
    spsThroughputLimit=math.max(0.1,base*1.04)
    spsThroughputExpires=t.ts+180
    desired=math.min(desired,spsThroughputLimit)
    t.spsLearnedThroughputCap=spsThroughputLimit
  end
  local trend=t.spInputControlTrend
  if trend and t.spControlSeconds and t.spControlSeconds>=c.spsMinTrendSeconds*0.9 then
    local correction=optimizerMath.feedback(trend,t.spInputCapacity,
      t.tps or 20,WASTE_PER_POLONIUM,c.spsFeedbackGain,base)
    desired=desired+correction
  end
  -- Small depleted-buffer reserve can be rebuilt, but only after actual
  -- depletion is observed. No fixed 8% Polonium fill target.
  if t.spInput<0.01 and t.spInputControlTrend and
      t.spInputControlTrend< -c.spsTrendDeadband then
    desired=math.max(desired,base*1.05)
  end
  if spsOutputHold then desired=math.min(desired,math.max(0.01,base*0.25)) end
  if t.snaProduction<=0 then desired=0.01 end
  t.spsDemandBurn=desired
  desired=clamp(desired,0.01,cap)

  local now=t.ts
  local elapsed=now-lastChange
  local upStep=math.max(0.1,math.min(
    math.max(1,t.maxBurn*c.spsRampMaxFraction),
    math.max(2,t.burn*0.25)))
  -- Normal demand trims should converge smoothly, not lurch by 15%.
  local downStep=math.max(2,t.burn*0.06)
  local target=t.burn
  local reason="HOLD: SPS DEMAND BALANCED"
  local burnDeadband=math.max(c.spsBurnDeadbandAbs,t.burn*c.spsBurnDeadbandFraction)
  t.spsBurnDeadband=burnDeadband
  local urgent=t.burn>cap+0.009
  -- Turbine DUMPING_EXCESS does not start until the configured keep level.
  -- The climb toward 90% is normal, not runaway backpressure.
  local dump=t.dumpExcess==true
  local pressure=optimizerMath.spsPressure({
    steam=t.steam,
    slope=(dump and t.steam and t.steam<c.spsDumpPressureHoldLevel)
        and 0 or t.steamTrend,
    holdLevel=dump and c.spsDumpPressureHoldLevel or c.spsPressureHoldLevel,
    trimLevel=dump and c.spsDumpPressureTrimLevel or c.spsPressureTrimLevel,
    criticalLevel=dump and c.spsDumpPressureCriticalLevel or
      c.spsPressureCriticalLevel,
    trendWarn=c.spsPressureGrowthWarn,
    trendFast=c.spsPressureGrowthFast
  })
  if pressure.state=="TRIM" or pressure.state=="TRIM_FAST" then
    steamPressureRecovery=true
  elseif steamPressureRecovery and t.steam and
      (dump and t.steam<=c.spsDumpKeepRatio or
       t.steam<=(dump and c.spsDumpPressureRecoverLevel or
           c.spsPressureRecoverLevel) and
       (not t.steamTrend or t.steamTrend<=c.spsPressureGrowthWarn)) then
    steamPressureRecovery=false
  elseif steamPressureRecovery and pressure.state=="OK" then
    pressure.state="HOLD"
    pressure.reason="STEAM PRESSURE RECOVERING"
  end
  t.steamPressureRecovering=steamPressureRecovery
  t.steamPressureState=pressure.state
  t.steamPressureReason=pressure.reason
  local thermal=nil
  local thermalUrgent=false
  local thermalState=t.thermalState
  local thermalReason=t.thermalReason
  if thermalState==nil then
    local m=thermalModel.assess({
      temp=t.temp,trend=t.tempTrend,burn=t.actual or t.burn,
      heatCapacity=t.heatCapacity,isSodium=t.sodiumCoolant,
      energyPerFuel=c.thermalEnergyPerFuel,
      warn=c.tempWarn,trip=c.tempTrip,
    errorTolerance=c.thermalExpectedTolerance
    })
    thermalState=m.state
    thermalReason=m.reason
    t.thermalState=thermalState
    t.thermalReason=thermalReason
    t.expectedTemp=m.expected
  end
  if thermalState=="TRIM" or thermalState=="TRIM_FAST" or
      thermalState=="TRIP" then
    thermal=thermalReason.." ("..n(t.temp,0).."K, model "..
      n(t.expectedTemp,0).."K)"
    thermalUrgent=thermalState~="TRIM"
  elseif t.coolant<c.coolantWarn then
    thermal="LOW COOLANT "..p(t.coolant)
    thermalUrgent=t.coolant<c.coolantTrip+0.05
  elseif t.dumpExcess and t.coolantDelta and
      t.coolantDelta< -c.spsDumpCoolantDropWarn and
      t.coolant<c.spsDumpCoolantWarn then
    thermal="COOLANT FALLING WHILE DUMPING STEAM"
    thermalUrgent=t.coolant<c.spsDumpCoolantTrip+0.01
  elseif t.heated>=c.heatedWarn then
    thermal="REACTOR HEATED COOLANT "..p(t.heated)
  elseif t.waste>=c.wasteWarn then
    thermal="NUCLEAR WASTE BUFFER "..p(t.waste)
  elseif t.bSteam and t.bSteam>=c.steamWarn then
    thermal="BOILER STEAM "..p(t.bSteam)
  elseif t.bHot and t.bHot>=c.heatedWarn then
    thermal="BOILER HOT COOLANT "..p(t.bHot)
  elseif t.snaMaxOutputFill>=0.94 then
    thermal="SNA POLONIUM OUTPUT FULL"
  elseif pressure.state=="TRIM" or pressure.state=="TRIM_FAST" then
    thermal=pressure.reason.." "..p(t.steam)
    thermalUrgent=pressure.state=="TRIM_FAST"
  end
  t.protectionCause=thermal or
      (pressure.state=="HOLD" and pressure.reason or "NONE")
  if urgent then
    target=cap
    reason="CAP: "..capReason
  elseif thermal then
    local minPause=thermalUrgent and 12 or c.spsPressureTrimSeconds
    local trim=math.max(2,t.burn*
      (thermalUrgent and 0.10 or c.spsPressureTrimFraction))
    if elapsed>=minPause then
      target=math.max(0.01,t.burn-trim)
      reason="THROTTLE: "..thermal
    else
      reason="HOLD: "..thermal.." (NEXT TRIM "..n(minPause-elapsed,0).."s)"
    end
  elseif thermalState=="HOLD" then
    reason="HOLD: "..tostring(thermalReason)..
      " | actual "..n(t.temp,0).."K predicted "..
      n(t.expectedTemp,0).."K"
  elseif thermalState=="UNKNOWN" and c.thermalRequireHeatCapacity then
    reason="HOLD: THERMAL MODEL UNAVAILABLE / NO TEMP READ"
  elseif c.thermalRequireHeatCapacity and not t.heatCapacity then
    reason="HOLD: NO REACTOR HEAT CAPACITY READ"
  elseif pressure.state=="HOLD" then
    -- Turbine tank rising at 78%+? Pause growth; do NOT destroy a healthy
    -- antimatter production point because of temporary steam buffering.
    reason="HOLD: "..pressure.reason.." "..p(t.steam)
  elseif tankFill and tankFill<c.fuelLimitStart and t.fuelRapidNet and
      t.fuelRapidNet<0 and elapsed>=8 then
    target=math.min(t.burn,math.max(0.01,t.burn-downStep))
    reason="THROTTLE: FISSILE FUEL FALLING"
  elseif desired<t.burn-burnDeadband then
    if elapsed>=math.max(18,math.min(30,c.spsSettleSeconds)) then
      target=math.max(desired,t.burn-downStep)
      reason=spsOutputHold and "THROTTLE: ANTIMATTER BUFFER" or
        "TRIM: SPS USES LESS POLONIUM"
    else reason="HOLD: SPS DEMAND SETTLING" end
  elseif desired>t.burn+burnDeadband then
    if elapsed>=math.max(c.spsRampSeconds,c.spsRampSteadySeconds) and
        t.coolant>=c.coolantWarn and
        not (t.coolantDelta and t.coolantDelta< -0.002) and
        not (t.dumpExcess and t.coolant<c.spsDumpCoolantWarn and
          t.coolantDelta and t.coolantDelta< -c.spsDumpCoolantDropWarn) and
        not (t.bWater and t.dumpExcess and t.bWater<0.20) and
        not (t.heatedDelta and t.heatedDelta>0.002) and
        not (tankFill and tankFill<c.fuelLimitStart) and
        not fuelDeficit then
      local ready=t.fuelCapFresh or
        (tankFill and tankFill>=c.fuelLimitRelease and
          t.fuelSampleSeconds and t.fuelSampleSeconds>=c.fuelRapidSeconds and
          t.fuelRapidNet and not fuelDeficit)
      if ready then
        target=math.min(desired,t.burn+upStep)
        reason="RAMP: SPS PRODUCTION DEMAND"
      else
        reason="HOLD: FUEL CALIBRATION / RESERVE"
      end
    else reason="HOLD: SPS RAMP / COOLANT STABILIZATION" end
  end
  target=clamp(target,0.01,cap)
  if math.abs(target-t.burn)>=0.009 then
    local ok,err=burn(target)
    if not ok then
      mode="MANUAL";info="SPS AUTO setBurnRate failed: "..tostring(err)
      return
    end
    lastChange=now
    spsTrendResetAt=now
    spsControlWindow={}
    lastSpsChange=now
  end
  t.limit=reason
  lastSpsDecision=reason
  info=reason.." | AM "..n(t.spRate,4).." | target burn "..n(desired,2)
end

local function auto(t)
  if mode=="MANUAL" or latched or t.on~=true then return end
  if mode=="SPS" then autoSPS(t);return end
  if t.sodiumCoolant and not names.boiler then
    mode="MANUAL";info="AUTO disabled: sodium cooling requires boiler telemetry";return
  end
  if c.returnWaterRequired and (not t.waterOut or t.waterOut==0) then
    mode="MANUAL";info="AUTO disabled: condenser output unavailable";return
  end
  if not t.burn or not t.maxBurn then return end
  if t.power==nil or not t.maxProduction or t.maxProduction<=0 or
      t.flow==nil or not t.maxFlow or t.maxFlow<=0 then
    mode="MANUAL";info="AUTO disabled: turbine output telemetry missing";return
  end
  local productionFraction=clamp(t.power/t.maxProduction,0,5)
  smoothedPowerRatio=smoothedPowerRatio and
    (smoothedPowerRatio*0.75+productionFraction*0.25) or productionFraction
  t.productionFraction=productionFraction
  t.smoothedProduction=smoothedPowerRatio
  local cap=safeCap(t)
  local step=math.max(0.1, math.floor(t.maxBurn*
    clamp(c.autoRampFraction,0.0001,0.05)*100+0.5)/100)
  local warnings=bottleneck(t)
  local now=t.ts
  local decision="HOLD"
  local target=t.burn
  local timeSinceChange=now-lastChange
  local canThrottle=timeSinceChange>=c.feRateStabilitySeconds or
      (t.steam and t.steam>=c.steamTrip-0.01)
  -- A full power buffer means actual energy consumers cannot keep up.
  -- Throttle to avoid burning fissile fuel for power which cannot escape.
  if t.energy and t.energy>=c.feEnergyHigh then
    if canThrottle then
      target=math.max(0.1,t.burn-math.max(step,t.burn*0.10))
      decision="THROTTLE: TURBINE ENERGY BLOCKED"
    else decision="HOLD: BUFFER PRESSURE / SETTLING" end
  elseif t.steam and t.steam>=c.feSteamThrottle and
       (t.steamDelta==nil or t.steamDelta>=-0.001) then
    if canThrottle then
      target=math.max(0.1,t.burn-math.max(step,t.burn*0.10))
      decision="THROTTLE: STEAM BUFFER NEAR FULL"
    else decision="HOLD: STEAM BUFFER / SETTLING" end
  elseif t.waste and t.waste>=c.wasteWarn or
         t.heated and t.heated>=c.heatedWarn or
         t.coolant and t.coolant<c.coolantWarn or
         t.temp and t.temp>=c.tempWarn or
         t.bSteam and t.bSteam>=c.steamWarn or
         t.bHot and t.bHot>=c.heatedWarn then
    if canThrottle then
      target=math.max(0.1,t.burn-math.max(step,t.burn*0.12))
      decision="THROTTLE: COOLING OR WASTE"
    else decision="HOLD: COOLING / WASTE / SETTLING" end
  elseif t.burn>cap+0.009 then
    target=cap
    decision="CAP: TURBINE MAX FLOW"
  elseif now-lastChange < math.max(c.feRateStabilitySeconds,c.stepSeconds) then
    decision="STABILIZING TURBINE"
  elseif t.steam and t.steam>=c.feSteamHold then
    decision="HOLD: HIGH STEAM BUFFER"
  elseif smoothedPowerRatio<c.feTarget-c.feDeadband and
      t.burn<cap-0.009 then
    target=math.min(cap,t.burn+step)
    decision="RAMP UP: BOOST GENERATION"
  elseif smoothedPowerRatio>=c.feTarget-c.feDeadband then
    decision="HOLD: FE PRODUCTION ON TARGET"
  else
    decision="HOLD: RATED LIMIT"
  end
  target=math.min(cap,math.max(0.1,target))
  if math.abs(target-t.burn)>=0.009 then
    local ok,v=burn(target)
    if not ok then
      mode="MANUAL";info="AUTO setBurnRate failed: "..tostring(v)
      return
    end
    lastChange=now
  end
  info=decision.." | output "..n(productionFraction*100,1).."%"
  t.safeCap=cap
  t.limit=decision
end
local fields={"ts","on","burn","actual","temp","damage","coolant","heated","waste",
  "fuel","steamMade","coolantType","heatCapacity","expectedTemp",
  "expectedAtMaxBurn","thermalModelCap","tempTrend","tempTrendSeconds",
  "thermalState","thermalReason","thermalExpectedError",
  "thermalWarnEffective","thermalTripEffective",
  "rLength","rWidth","rHeight","assemblies","boilEfficiency",
  "steam","steamIn","steamTrend","steamTrendWindow",
  "steamDumpKeepRatio","steamDumpingActive","steamTripEffective",
  "steamPressureState","steamPressureReason","steamPressureRecovering",
  "protectionCause","spsBurnDeadband",
  "flow","maxFlow","power","energy","dump","dumpExcess",
  "waterReturnGapEstimate",
  "tLength","tWidth","tHeight",
  "blades","coils","vents","condensers","maxProduction",
  "powerFE","maxProductionFE","waterOut","productionFraction",
  "spInput","spOutput","spRate","spEnergyFill","spEnergyStored",
  "spMaxEnergy","spInputAmount","spOutputAmount",
  "spEnergyUsedFE","spFeRequiredBurn","spFeRequiredSetpoint",
  "feOpportunityBurn","fePotentialRequired",
  "feEquivalentObserved","feLimitedRate","feDeliveryInferred",
  "feState","feSuggestedLimit","feShortfall",
  "snaCount","snaActive","snaSun","snaProduction",
  "snaWasteCapacity","snaAntimatterPotential","snaMaxOutputFill",
  "snaMaxInputFill","snaTotalInput","snaTotalOutput",
  "fissionAntimatterPotential","spsEfficiency","spsTargetRate","spsTargetFE","spsDiagnosis",
  "spLength","spWidth","spHeight","spCoils",
  "bSteam","bHot","bWater","bBoilCapacity","imEnergy","imIn",
  "imOut","imInFE","imOutFE",
  "fuelSource","fuelAvailable","reactorFuelAmount","fuelTankFill",
  "fuelNetPerTick","fuelRapidNet","fuelRapidProduction","fuelRapidLimited",
  "fuelDeficitMaterial","fuelDeficitThreshold",
  "fuelProducedEstimate","fuelCap","fuelCapFresh",
  "fuelSampleSeconds","fuelRateLimited","tps","spsDemandBurn","spInputControlTrend",
  "spControlSeconds","feAdvice","safeCap","limit",
  "storageFree","storageWarning",
  "spsTurbineFlowHardCap","spsCapReason","spsLearnedThroughputCap"}
-- Bounded logging: history is telemetry, NEVER a reason to stop the RPS.
-- Keep the latest CSV and, optionally, one previous segment.
local function history(t)
  if t.ts-lastLog<c.logSeconds then return end
  lastLog=t.ts
  local free=spaceFree()
  t.storageFree=free
  local rotateAt=math.max(20000,c.historyMaxBytes)
  local archive=CSV:gsub("%.csv$",".previous.csv")
  if fs.exists(CSV) and fs.getSize(CSV)>=rotateAt then
    local rotated,reason=pcall(function()
      if c.historyKeepPrevious then
        if fs.exists(archive) then fs.delete(archive) end
        fs.move(CSV,archive)
      else
        fs.delete(CSV)
      end
    end)
    if not rotated then
      t.storageWarning="CSV rotation failed: "..tostring(reason)
      return
    end
    free=spaceFree()
    t.storageFree=free
  end
  if free and free<c.historyMinFreeBytes then
    t.storageWarning="LOW DISK: telemetry logging paused (no SCRAM)"
    return
  end
  local function csvValue(v)
    if type(v)=="boolean" then v=v and 1 or 0 end
    if v==nil then return "" end
    local str=tostring(v)
    if str:find('[,"\\n\\r]') then
      return '"'..str:gsub('"','""')..'"'
    end
    return str
  end
  local vals={}
  for _,key in ipairs(fields) do vals[#vals+1]=csvValue(t[key]) end
  vals[#vals+1]=csvValue(mode)
  vals[#vals+1]=csvValue(alarm)
  local rowText=table.concat(vals,",")
  if free and free<c.historyMinFreeBytes+#rowText+256 then
    t.storageWarning="LOW DISK: CSV skipped to preserve settings space"
    return
  end
  local exists=fs.exists(CSV)
  local opened,f,openErr=pcall(fs.open,CSV,"a")
  if not opened or not f then
    t.storageWarning="CSV cannot open: "..tostring(openErr or f)
    return
  end
  local wrote,reason=pcall(function()
    if not exists then f.writeLine(table.concat(fields,",")..",mode,alarm") end
    f.writeLine(rowText)
  end)
  local closed,closeErr=pcall(f.close)
  if not wrote or not closed then
    t.storageWarning="CSV write failed: "..tostring(reason or closeErr)
  end
end
local function row(dev,y,label,clr)
  local w,h=dev.getSize();if y<1 or y>h then return end
  dev.setCursorPos(1,y)
  dev.setBackgroundColor(colors.black)
  dev.setTextColor(clr or colors.white)
  local v=tostring(label):sub(1,w)
  dev.write(v..string.rep(" ",math.max(0,w-#v)))
end
local function btn(dev,y,x,label,id)
  local w,h=dev.getSize()
  local s="["..label.."]"
  if x+#s-1>w or y<1 or y>h then return end
  dev.setCursorPos(x,y);dev.setBackgroundColor(colors.gray)
  dev.setTextColor(colors.white);dev.write(s)
  buttons[#buttons+1]={y=y,x=x,last=x+#s-1,id=id}
end
-- Keep unchanged monitor rows intact instead of blanking the screen every
-- telemetry update. A full clear is only necessary for a new layout/page.
local monitorLayout=nil
local monitorPaintCache={}
local function scadaDraw(dev,isMonitor)
  local w,h=dev.getSize()
  if h<19 or w<38 then return false end
  buttons={}
  local function paint(y,label,fg,bg)
    if y<1 or y>h then return end
    local s=tostring(label):sub(1,w)
    local fgColor=fg or colors.white
    local bgColor=bg or colors.black
    local prior=isMonitor and monitorPaintCache[y] or nil
    if prior and prior.text==s and prior.fg==fgColor and prior.bg==bgColor then
      return
    end
    dev.setCursorPos(1,y)
    dev.setBackgroundColor(bgColor)
    dev.setTextColor(fgColor)
    dev.write(s..string.rep(" ",math.max(0,w-#s)))
    if isMonitor then
      monitorPaintCache[y]={text=s,fg=fgColor,bg=bgColor}
    end
  end
  local function bar(y,label,frac,color)
    if not N(frac) then paint(y,label.." --");return end
    frac=clamp(frac,0,1)
    local width=math.max(4,math.min(28,w-#label-11))
    local used=math.floor(width*frac+0.5)
    paint(y,label.." ["..string.rep("=",used)..string.rep("-",width-used).."] "..p(frac),color)
  end
  local function title(text) paint(4," "..text,colors.cyan) end
  paint(1," PROJECT INFINITY  /  MEKANISM SCADA  |  "..mode,colors.black,colors.cyan)
  paint(2," SPS | REACTOR | TURBINE | DIAG | HISTORY",colors.lightBlue)
  paint(3," "..(latched and "TRIPPED" or current.on and "REACTOR ONLINE" or "REACTOR OFF")..
    "  |  AM "..n(current.spRate,4).." mB/t",latched and colors.red or colors.lime)
  if uiPage==1 then
    title("SPS / ANTIMATTER")
    paint(6,"OUTPUT "..n(current.spRate,4).." mB/t  |  "..n((current.spRate or 0)*1200,2).." mB/min",colors.lime)
    paint(7,"EMA "..n(current.spRateEMA,4).." | AVG "..n(current.spRate120,4).." mB/t ("..n(current.spWindowSeconds,0).."s)")
    bar(9,"Polonium",current.spInput,colors.yellow)
    bar(10,"Antimatter",current.spOutput,colors.lime)
    paint(11,"SPS coils "..n(current.spCoils,0).." | FE buffer "..p(current.spEnergyFill),colors.lightBlue)
    paint(12,"Solar "..tostring(current.snaActive or 0).."/"..tostring(current.snaCount or 0)..
      "  potential "..fmt(current.snaProduction).." polonium/t")
    paint(13,"Fission potential "..n(current.fissionAntimatterPotential,4).." AM/t (THEORY)")
    paint(14,"FE actual AM equivalent ~"..fmt(current.spEnergyUsedFE)..
      " / required for burn "..fmt(current.spFeRequiredSetpoint),colors.lightBlue)
    paint(15,"Flux ref "..fmt(c.fluxLimitFE).." -> up to "..n(current.feLimitedRate,4).." AM/t (EST.)",colors.yellow)
    paint(16,"Control: "..lastSpsDecision,colors.orange)
    paint(18,"Polonium buffer trend "..n(current.spInputTrend120 and current.spInputTrend120*100*60,2).."%/min",colors.lightBlue)
    paint(17,"DIAG "..tostring(current.spsDiagnosis or "--"),colors.orange)
    paint(19,"FE "..tostring(current.feAdvice or "--"),colors.lightBlue)
    if h>=33 then
      paint(20,"AM PRODUCTION HISTORY ("..#rateHistory.." samples)",colors.cyan)
      local gh=math.min(5,h-31)
      if gh>0 and #rateHistory>0 then
        local graphWidth=math.min(w,#rateHistory)
        local peak=0
        for _,v in ipairs(rateHistory) do peak=math.max(peak,v.rate or 0) end
        peak=math.max(peak,0.00001)
        local heights={}
        for x=1,graphWidth do
          local v=rateHistory[#rateHistory-graphWidth+x].rate or 0
          heights[x]=math.floor(v/peak*gh+0.5)
        end
        for y=1,gh do
          local glyphs={}
          for x=1,graphWidth do
            glyphs[x]=(heights[x]>=gh-y+1) and "|" or " "
          end
          paint(20+y,table.concat(glyphs),colors.lime)
        end
      end
    end
  elseif uiPage==2 then
    title("FISSION REACTOR / CONTROL")
    paint(6,"Burn "..n(current.burn,2).." / actual "..n(current.actual,2)..
      " / max "..n(current.maxBurn,2).." mB/t")
    paint(7,"Temperature "..n(current.temp,1).." K | damage "..n(current.damage,1).."%")
    bar(9,"Coolant",current.coolant,colors.aqua)
    bar(10,"Heated",current.heated,colors.orange)
    bar(11,"Waste",current.waste,colors.yellow)
    bar(12,"Fuel",current.fuel,colors.lime)
    paint(13,"Fuel "..tostring(current.fuelSource or "MISSING").." "..p(current.fuelFillForControl)..
      " net "..n(current.fuelRapidNet,2).." mB/t (deficit < -"..n(current.fuelDeficitThreshold,2)..")")
    if mode=="MANUAL" then
      paint(14,"AUTO SPS CAP -- (MANUAL MODE; NOT REGULATING)",colors.lightBlue)
    else
      paint(14,"AUTO CAP "..n(current.safeCap,2).." mB/t | "..
        tostring(current.spsCapReason or "WAITING FOR SPS DATA"))
    end
    paint(15,"CONTROL "..tostring(current.limit or "--"),colors.yellow)
    paint(19,"Pressure "..tostring(current.steamPressureState or "--")..
      " | steam "..p(current.steam).." | trend "..
      n(current.steamTrend and current.steamTrend*100*60,3).."%/min",colors.lightBlue)
    paint(20,"Protection: "..tostring(current.protectionCause or "NONE"),colors.yellow)
    paint(16,"Fuel estimate "..n(current.fuelCap,2).." mB/t | TPS "..n(current.tps,1))
    paint(21,"Configured AUTO ceiling "..(c.autoBurnCeiling>0 and n(c.autoBurnCeiling,2).." mB/t (C key)" or "reactor max"),colors.lightBlue)
    paint(22,"THERMAL actual "..n(current.temp,1).."K | expected "..
      n(current.expectedTemp,1).."K | error "..n(current.thermalExpectedError,1).."K",colors.lightBlue)
    paint(23,"THERMAL "..tostring(current.thermalState or "--")..
      " | dT "..n(current.tempTrend,2).." K/s | model cap "..
      n(current.thermalModelCap,2).." mB/t",colors.yellow)
    paint(24,"Temperature soft "..n(current.thermalWarnEffective,0)..
      "K / SCRAM "..n(current.thermalTripEffective,0).."K",colors.orange)
    if current.dumpExcess then
      paint(25,"DUMP EXCESS retains "..p(current.steamDumpKeepRatio)..
        " steam; protective SCRAM "..p(current.steamTripEffective),colors.lightBlue)
    end
    paint(17,"SCRAM protection: "..(latched and "LATCHED" or "ARMED"),
      latched and colors.red or colors.lime)
    paint(18,"Steam dumping "..(current.dumpExcess and "EXCESS - CHECK WATER" or
      tostring(current.dump or "unknown")),current.dumpExcess and colors.yellow or colors.lightBlue)
  elseif uiPage==3 then
    title("TURBINE / ENERGY")
    paint(6,"FE output "..fmt(current.powerFE).." / "..fmt(current.maxProductionFE).." FE/t")
    paint(7,"Steam flow "..fmt(current.flow).." / "..fmt(current.maxFlow))
    bar(9,"Steam",current.steam,colors.aqua)
    bar(10,"FE buffer",current.energy,colors.lime)
    paint(12,"Matrix IN "..fmt(current.imInFE).." FE/t")
    paint(13,"Matrix OUT "..fmt(current.imOutFE).." FE/t")
    paint(11,"Tech FE opportunity ~"..fmt(current.fePotentialRequired).." (fuel/heat not assured)")
    paint(14,"SPS FE equiv "..fmt(current.feEquivalentObserved)..
      " | estimate from antimatter",colors.lightBlue)
    paint(15,"FE required at burn "..n(current.burn,2)..": "..
      fmt(current.spFeRequiredSetpoint).." FE/t",colors.yellow)
    paint(16,"Flux ref "..fmt(c.fluxLimitFE).." | suggested test "..
      fmt(current.feSuggestedLimit).." FE/t",colors.yellow)
    paint(17,"FE STATUS "..tostring(current.feState or "UNKNOWN"),colors.lime)
    paint(18,tostring(current.feAdvice or "--"),colors.lightBlue)
    paint(19,"Only reference, NOT actual Flux Point measurement.",colors.orange)
    if current.dumpExcess then
      paint(20,"Steam DUMP EXCESS: check makeup water / coolant!",colors.yellow)
      paint(21,"Possible water return gap "..fmt(current.waterReturnGapEstimate).." mB/t",colors.orange)
    end
  elseif uiPage==4 then
    title("DIAGNOSTICS / ALARMS")
    paint(6,"SPS: "..tostring(current.spsDiagnosis or "--"),colors.yellow)
    paint(7,"Safety: "..(latched and alarm or "NO LATCHED ALARM"),
      latched and colors.red or colors.lime)
    paint(8,"Fuel tank "..p(current.fuelTankFill).." net "..n(current.fuelNetPerTick,2).." mB/t")
    paint(10,"Fuel cap ~"..n(current.fuelCap,2).." mB/t | TPS "..n(current.tps,1))
    paint(17,"Steam pressure: "..tostring(current.steamPressureState or "--")..
      " / "..tostring(current.steamPressureReason or "--"),colors.lightBlue)
    paint(18,"Protection: "..tostring(current.protectionCause or "NONE"),colors.yellow)
    paint(19,"Thermal: "..tostring(current.thermalState or "--")..
      " / "..tostring(current.thermalReason or "--"),colors.lightBlue)
    paint(20,"Model "..n(current.expectedTemp,1).."K | actual "..
      n(current.temp,1).."K | trend "..n(current.tempTrend,2).."K/s")
    paint(21,"Heat capacity "..fmt(current.heatCapacity)..
      " J/K | safe burn ~"..n(current.thermalModelCap,2).." mB/t")
    paint(9,"Data: SPS "..tostring(names.sps or "MISSING")..
      " | SNA "..tostring(current.snaCount or 0))
    paint(11,"Recent alarms:",colors.cyan)
    for i=math.max(1,#alarmHistory-6),#alarmHistory do
      local entry=alarmHistory[i]
      paint(12+i-math.max(1,#alarmHistory-6),entry.message,colors.orange)
    end
    paint(math.min(h-7,21),"Safety always active; reactor never auto-starts.",colors.yellow)
  else
    title("HISTORY / CONTROL STATUS")
    paint(6,"AM average "..n(current.spRateAverage,4).." mB/t")
    paint(7,"AM latest "..n(current.spRate,4).." mB/t")
    paint(8,"AM EMA "..n(current.spRateEMA,4).." | 120s "..n(current.spRate120,4))
    paint(9,"SPS diagnosis: "..tostring(current.spsDiagnosis))
    paint(11,"Control: "..info,colors.yellow)
    paint(13,"CSV log: /cc-mekanism/history_v5_thermal.csv")
    paint(16,"CC free storage "..fmt(current.storageFree).." bytes")
    if current.storageWarning then
      paint(17,"DISK: "..tostring(current.storageWarning),colors.red)
    end
    paint(15,"Note: 'potential' is not confirmed optimality.",colors.orange)
  end
  if isMonitor then
    local nav={"SPS","REACTOR","FE","DIAG","LOG"}
    local yNav=h-6
    local width=math.floor(w/5)
    for i,label in ipairs(nav) do
      local x=(i-1)*width+1
      local txt="["..label.."]"
      if x+#txt-1<=w then
        dev.setCursorPos(x,yNav)
        dev.setBackgroundColor(i==uiPage and colors.blue or colors.gray)
        dev.setTextColor(colors.white)
        dev.write(txt)
        buttons[#buttons+1]={x=x,last=x+#txt-1,y=yNav,id="page"..i}
      end
    end
    -- Always visible on every monitor page; these update ONLY the stored
    -- Flux Point FE/t reference, not the Flux Point machine itself.
    paint(h-4,"FLUX REF "..fmt(c.fluxLimitFE).." FE/t",colors.lightBlue)
    btn(dev,h-4,w-11,"-1M","fluxminus")
    btn(dev,h-4,w-5,"+1M","fluxplus")
    local actions={{"MAN","manual"},{"FE","fe"},{"AUTO SPS","sps"},
      {"SCRAM","scram"},{"START","start"}}
    local ax=1
    for _,a in ipairs(actions) do
      local label="["..a[1].."]"
      if ax+#label-1<=w then
        dev.setCursorPos(ax,h-3)
        dev.setBackgroundColor(a[2]=="scram" and colors.red or colors.gray)
        dev.setTextColor(colors.white)
        dev.write(label)
        buttons[#buttons+1]={x=ax,last=ax+#label-1,y=h-3,id=a[2]}
      end
      ax=ax+#label+2
    end
    paint(h-2,"STATUS "..info,colors.yellow)
  end
  paint(h,"1-5 pages | +/- burn | C cap | M manual | P SPS | S SCRAM",colors.lightGray)
  return true
end
local function render(dev,isMonitor)
  if not dev then return false end
  local ok,err=pcall(function()
    local scaleChanged=false
    if isMonitor and dev.setTextScale then
      local currentScale=dev.getTextScale and dev.getTextScale() or nil
      if currentScale~=0.5 then
        dev.setTextScale(0.5)
        scaleChanged=true
      end
    end
    local w,h=dev.getSize()
    local redraw=not isMonitor or scaleChanged or not monitorLayout or
      monitorLayout.name~=names.monitor or
      monitorLayout.width~=w or monitorLayout.height~=h or
      monitorLayout.page~=uiPage
    if redraw then
      dev.setBackgroundColor(colors.black)
      dev.setTextColor(colors.white)
      dev.clear()
      if isMonitor then
        monitorPaintCache={}
        monitorLayout={name=names.monitor,width=w,height=h,page=uiPage}
      end
    end
    if scadaDraw(dev,isMonitor) then return end
    row(dev,1,"PROJECT INFINITY / MEKANISM | "..mode..
        (latched and " | ALARM LATCHED" or (current.on and " | ACTIVE" or " | OFF")),latched and colors.red or colors.cyan)
    row(dev,2,"Reactor "..(tostring(current.rLength or "?").."x"..tostring(current.rWidth or "?").."x"..tostring(current.rHeight or "?"))..
        " | Assemblies "..fmt(current.assemblies).." | Turbine "..tostring(current.tLength or "?").."x"..
        tostring(current.tWidth or "?").."x"..tostring(current.tHeight or "?"))
    row(dev,3,"Burn: "..n(current.burn,2).." actual: "..n(current.actual,2).." max: "..n(current.maxBurn,2).." mB/t")
    row(dev,4,"AUTO ceiling: "..(c.autoBurnCeiling>0 and n(c.autoBurnCeiling,2) or "DETECTED MAX")..
      "  effective cap: "..n(current.safeCap,2).." mB/t")
    row(dev,5,"Temperature: "..n(current.temp,1).." K  Damage: "..n(current.damage,0).."%")
    row(dev,6,"Coolant "..p(current.coolant).."  Hot "..p(current.heated).."  Waste "..p(current.waste))
    row(dev,7,"SPS ANTIMATTER "..n(current.spRate,3).." mB/t | "..
      "FROM FISSION "..n(current.fissionAntimatterPotential,3).." mB/t",colors.lime)
    row(dev,8,"SPS Polonium "..p(current.spInput).." | Antimatter "..p(current.spOutput)..
      " | SPS FE used ~"..fmt(current.spEnergyUsedFE).." FE/t")
    row(dev,9,"SOLAR "..tostring(current.snaActive or 0).."/"..tostring(current.snaCount or 0)..
      " active | rate "..fmt(current.snaProduction).." polonium/t | peak "..
      fmt(current.snaPeak))
    row(dev,10,"SOLAR input "..p(current.snaMaxInputFill).." | output "..
      p(current.snaMaxOutputFill).." | waste capacity "..fmt(current.snaWasteCapacity).."/t")
    row(dev,11,"SPS potential "..n(current.spsTargetRate,3).." AM/t | "..
      "FE required ~"..fmt(current.spsTargetFE).."/t | balance "..
      (current.spsEfficiency and n(current.spsEfficiency*100,1).."%" or "--"))
    row(dev,12,"Turbine "..fmt(current.powerFE).."/"..fmt(current.maxProductionFE)..
      " FE/t | steam "..p(current.steam).." | FE buffer "..p(current.energy))
    row(dev,13,"Steam flow "..fmt(current.flow).."/"..fmt(current.maxFlow)..
      " | boiler "..(names.boiler and "connected" or "none")..
      " | sodium "..(current.sodiumCoolant and "YES" or "NO"))
    row(dev,14,"SPS diagnosis: "..(current.spsDiagnosis or "not connected"))
    row(dev,15,"Control: "..info,colors.yellow)
    row(dev,16,"Alarm: "..(alarm~="" and alarm or "none"),latched and colors.red or colors.lime)
    if not isMonitor then
      row(dev,17,"Monitor: "..(names.monitor or
        (duplicates.monitor and "MULTIPLE - set monitor in settings" or
          "NOT DETECTED - run cc-mekanism/monitor-test")))
    end
    if isMonitor and h>=20 then
      buttons={}
      btn(dev,h-2,1,"-", "minus");btn(dev,h-2,6,"+","plus")
      btn(dev,h-2,11,"CAP-","capminus");btn(dev,h-2,19,"CAP+","capplus")
      btn(dev,h-1,1,"MAN","manual");btn(dev,h-1,7,"FE","fe")
      btn(dev,h-1,12,"SPS","sps");btn(dev,h-1,18,"SCRAM","scram")
      btn(dev,h-1,26,"START","start")
    end
    row(dev,h,"Keys: +/- B burn C cap T FE target% M manual F FE P SPS S SCRAM R start Q quit",colors.lightGray)
  end)
  if not ok then
    if isMonitor then monitorLayout=nil;monitorPaintCache={} end
    info="Display error: "..tostring(err)
    return false
  end
  return true
end
-- Separate ComputerCraft computer console.
-- The big monitor belongs to monitorLoop, while this small terminal is
-- an operator panel, not just an eight-line printout that hides key input.
local edit,buffer=nil,""
local consoleCache={}
local consoleSize=nil
local function drawConsole()
  if not screen or not screen.getSize then return end
  local w,h=screen.getSize()
  if not w or not h then return end
  local resized=not consoleSize or consoleSize.w~=w or consoleSize.h~=h
  if resized then
    consoleSize={w=w,h=h}
    consoleCache={}
    screen.setBackgroundColor(colors.black)
    screen.setTextColor(colors.white)
    screen.clear()
  end
  local function line(y,message,fg,bg)
    if y<1 or y>h then return end
    local label=tostring(message or ""):sub(1,w)
    local f=fg or colors.white
    local b=bg or colors.black
    local old=consoleCache[y]
    if old and old.text==label and old.fg==f and old.bg==b then return end
    screen.setBackgroundColor(b)
    screen.setTextColor(f)
    screen.setCursorPos(1,y)
    screen.write(label..string.rep(" ",math.max(0,w-#label)))
    consoleCache[y]={text=label,fg=f,bg=b}
  end
  line(1," PROJECT INFINITY  |  CC CONTROL  |  "..mode,
    colors.black,colors.cyan)
  line(2," Reactor: "..(latched and "SCRAM LATCHED" or
    (current.on==true and "ONLINE" or "OFFLINE"))..
    "  |  SPS "..n(current.spRate,4).." mB/t",
    latched and colors.red or colors.lime)
  line(3," Burn  "..n(current.burn,2).." / "..n(current.maxBurn,2)..
    " mB/t",colors.white)
  line(4," AUTO ceiling: "..(c.autoBurnCeiling>0 and
    n(c.autoBurnCeiling,2).." mB/t" or "reactor max (no manual cap)"),
    colors.yellow)
  line(5," Flux reference: "..fmt(c.fluxLimitFE).." FE/t",colors.lightBlue)
  line(6," Temp "..n(current.temp,1).."K | Coolant "..p(current.coolant)..
    " | Waste "..p(current.waste),colors.white)
  line(7," Steam "..p(current.steam).." | Fuel tank "..p(current.fuelTankFill),
    colors.white)
  line(8," Control: "..tostring(current.limit or lastSpsDecision),
    colors.orange)
  line(9," Thermal "..tostring(current.thermalState or "--")..
    " | predicted "..n(current.expectedTemp,0).."K | safe ~"..
    n(current.thermalModelCap,0),colors.lightBlue)

  local actionNames={
    cap="AUTO BURN CEILING (mB/t)",
    burn="MANUAL BURN RATE (mB/t)",
    flux="FLUX POINT REFERENCE (FE/t)",
    target="FE GENERATION TARGET (%)"
  }
  if edit then
    line(10," EDIT: "..(actionNames[edit] or edit),colors.black,colors.yellow)
    local currentValue=
      edit=="cap" and (c.autoBurnCeiling==0 and "AUTO MAX" or n(c.autoBurnCeiling,2)) or
      edit=="flux" and fmt(c.fluxLimitFE) or
      edit=="burn" and n(current.burn,2) or
      edit=="target" and n(c.feTarget*100,1).."%" or "--"
    line(11," Current: "..currentValue,colors.lightBlue)
    line(12," > "..(buffer~="" and buffer or "_"),colors.lime)
    line(13," ENTER Save | BACKSPACE Delete",colors.white)
    line(14," ESC Cancel | C: 0 = reactor max",colors.lightGray)
  else
    line(10," C - Edit AUTO burn ceiling",colors.yellow)
    line(11," B - Manual burn | L - Flux FE limit",colors.lightBlue)
    line(12," P - AUTO SPS | M - Manual | F - AUTO FE",colors.white)
    line(13," +/- Burn step | R Start | S SCRAM",colors.white)
    line(14," T - FE target | Q - Quit",colors.lightGray)
  end
  line(15," STATUS: "..tostring(info or ""),colors.yellow)
  if h>=17 then
    line(h-1,edit and " Type a number; input shown above." or
      " Large monitor: charts, alarms, Flux +/-1M",colors.lightGray)
  end
  if h>=16 then line(h,edit and
      " [EDITING] Enter=save, Esc=cancel" or
      " [READY] Press C to edit AUTO ceiling",colors.black,colors.cyan)
  end
end
local function display()
  if names.monitor and peripheral.isPresent(names.monitor) then
    render(peripheral.wrap(names.monitor),true)
    drawConsole()
  else
    -- The small console keeps a working editor even when the large
    -- monitor is disconnected.
    drawConsole()
  end
end
local function canStart()
  local ok,why=safety(current)
  if not ok then return false,why end
  if current.on then return false,"reactor is already active" end
  if current.temp>=c.tempWarn or current.coolant<c.coolantWarn or current.waste>=c.wasteWarn then
    return false,"startup needs extra headroom"
  end
  if current.burn==nil or current.burn<=0 then return false,"set burn rate first" end
  if recentValid<4 then return false,"wait for four good readings" end
  return true
end
local FLUX_STEP_FE=1000000
local FLUX_MAX_FE=1000000000
local function setFluxReference(raw)
  local value=N(raw)
  if value==nil or value<0 or value>FLUX_MAX_FE then
    info="Flux FE/t reference must be 0..1G"
    return false
  end
  local updated=math.floor(value+0.5)
  local previousLimit=c.fluxLimitFE
  if updated==previousLimit then
    info="Flux reference unchanged: "..fmt(updated).." FE/t"
    return false
  end
  local now=os.epoch("utc")/1000
  -- Multiple +/-1M touches in quick succession are a single FE trial:
  -- keep the original before-value and start timing after the LAST click.
  if feTrial and now-feTrial.started<20 then
    feTrial.newLimit=updated
    feTrial.started=now
    if feTrial.newLimit==feTrial.oldLimit then feTrial=nil end
  elseif current.spRate120 and current.spWindowSeconds and
      current.spWindowSeconds>=60 then
    feTrial={started=now,oldLimit=previousLimit,
      newLimit=updated,beforeRate=current.spRate120}
  else
    feTrial=nil
  end
  feTrialResult=nil
  c.fluxLimitFE=updated
  local saved,err=save()
  if not saved then
    c.fluxLimitFE=previousLimit
    feTrial=nil
    info="NOT SAVED: "..tostring(err).." | free disk space"
    return false
  end
  info="FE ref "..fmt(updated).." FE/t saved; SET FLUX POINT MANUALLY"
  return true
end
local function command(cmd)
  local pageNumber=tonumber(tostring(cmd):match("^page([1-5])$"))
  if pageNumber then uiPage=pageNumber;return end
  if cmd=="fluxplus" or cmd=="fluxminus" then
    local nextValue=c.fluxLimitFE+
      (cmd=="fluxplus" and FLUX_STEP_FE or -FLUX_STEP_FE)
    -- A zero reference disables the SPS FE ceiling, so the touch
    -- controls do not permit it accidentally (the L key still allows 0).
    if cmd=="fluxminus" and nextValue<FLUX_STEP_FE then
      info="Minimum via touch: 1M FE/t (0 disables FE cap)"
      return
    end
    setFluxReference(math.min(FLUX_MAX_FE,nextValue))
    return
  end
  if cmd=="scram" then trip("manual SCRAM");return end
  if cmd=="manual" then mode="MANUAL";info="MANUAL (safety still enabled)";return end
  if cmd=="fe" or cmd=="sps" then
    if latched then info="ALARM LATCHED: restart requires manual reset";return end
    if cmd=="sps" and (not names.sps or current.spInput==nil) then
      info="No SPS peripheral";return
    end
    if cmd=="sps" and c.spsNoSolarHold and
        (not names.sna or #names.sna==0) then
      info="Connect Wired Modems to Solar Neutron Activators";return
    end
    mode=cmd=="fe" and "FE" or "SPS"
    lastChange=current.ts or os.epoch("utc")/1000
    spsTrendResetAt=lastChange
    spsControlWindow={}
    info="AUTO "..mode.." enabled; reactor never auto-starts"
    return
  end
  if cmd=="minus" or cmd=="plus" then
    if latched then info="ALARM LATCHED";return end
    local ok,v=burn((current.burn or 0)+(cmd=="plus" and c.step or -c.step))
    if ok then mode="MANUAL";info="Manual burn set to "..n(v,2)
    else info="Burn error: "..tostring(v) end
    return
  end
  if cmd=="capminus" or cmd=="capplus" then
    local max=current.maxBurn or 0
    if max<=0 then info="Waiting for reactor size";return end
    local step=math.max(0.1,math.floor(max*0.05*100+0.5)/100)
    local cap=c.autoBurnCeiling>0 and c.autoBurnCeiling or max
    if cmd=="capplus" then cap=cap+step else cap=cap-step end
    local oldCap=c.autoBurnCeiling
    if cap>=max then c.autoBurnCeiling=0
    else c.autoBurnCeiling=math.max(0.1,math.floor(cap*100+0.5)/100) end
    local saved,err=save()
    if not saved then
      c.autoBurnCeiling=oldCap
      info="AUTO ceiling NOT SAVED: "..tostring(err)
    else
      info="Auto ceiling: "..(c.autoBurnCeiling==0 and "DETECTED MAX" or n(c.autoBurnCeiling,2))
    end
    return
  end
  if cmd=="start" then
    local ok,reason=canStart()
    if not ok then info="START denied: "..reason;return end
    local now=os.epoch("utc")/1000
    if now>startConfirmUntil then
      startConfirmUntil=now+7;info="Press START/R again within 7 seconds";return
    end
    startConfirmUntil=0
    local good,err=pcall(peripheral.call,names.reactor,"activate")
    if good then latched=false;alarm="";redstoneAlarm(false);info="Manual activation sent"
    else info="Activation failed: "..tostring(err) end
    return
  end
end
local function setTyped()
  local v=tonumber(buffer)
  if not v or v<0 then info="Invalid number; correct input or press ESC";return false end
  if edit=="cap" then
    -- Enter 0 to restore automatic cap from detected structure.
    local prior=c.autoBurnCeiling
    c.autoBurnCeiling=math.floor(v*100+0.5)/100
    local saved,err=save()
    if not saved then
      c.autoBurnCeiling=prior
      info="AUTO ceiling NOT SAVED: "..tostring(err)
      return false
    end
    info="AUTO ceiling "..(v==0 and "DETECTED MAX" or n(v,2))
  elseif edit=="flux" then
    return setFluxReference(v)
  elseif edit=="target" then
    if v<20 or v>100 then
      info="Target must be between 20 and 100 percent";return false
    else
      local prior=c.feTarget
      c.feTarget=math.floor(v*10+0.5)/1000
      local saved,err=save()
      if not saved then
        c.feTarget=prior
        info="FE target NOT SAVED: "..tostring(err)
        return false
      end
      smoothedPowerRatio=nil
      lastChange=current.ts or 0
      info="FE generation target "..n(v,1).."%"
    end
  elseif edit=="burn" then
    if latched then info="ALARM LATCHED";return end
    local ok,r=burn(v)
    if ok then mode="MANUAL";info="Manual burn "..n(r,2)
    else info="Burn error: "..tostring(r) end
  end
  return true
end
local function inputLoop()
  while active do
    local ev,a,b,d=os.pullEvent()
    if ev=="monitor_touch" and a==names.monitor then
      -- Touch controls must work even while an edit is open on the computer.
      edit=nil
      buffer=""
      for _,v in ipairs(buttons) do
        if d==v.y and b>=v.x and b<=v.last then command(v.id);break end
      end
    elseif edit then
      if ev=="char" and a:match("[0-9%.]") and #buffer<15 then buffer=buffer..a
      elseif ev=="key" and a==keys.backspace then buffer=buffer:sub(1,-2)
      elseif ev=="key" and a==keys.escape then edit=nil;buffer="";info="Edit cancelled"
      elseif ev=="key" and (a==keys.enter or a==keys.numPadEnter) then
        if setTyped() then edit=nil;buffer="" end
      end
    elseif ev=="char" then
      if a:match("^[1-5]$") then uiPage=tonumber(a)
      elseif a=="q" then active=false;return
      elseif a=="b" then edit="burn";buffer="";info="Enter new manual burn mB/t"
      elseif a=="c" then edit="cap";buffer=""
        info="Enter NEW burn ceiling mB/t (currently "..n(c.autoBurnCeiling,2)..
          ", 0=reactor max). Type number then Enter"
      elseif a=="l" then edit="flux";buffer=""
        info="Enter NEW Flux reference FE/t (current "..fmt(c.fluxLimitFE)..")"
      elseif a=="t" then edit="target";buffer=""
        info="Enter new turbine FE target % (20..100)"
      else
        local m={["-"]="minus",["+"]="plus",["="]="plus",
          m="manual",f="fe",p="sps",s="scram",r="start"}
        if m[a] then command(m[a]) end
      end
      if edit then info="Editing "..edit..": "..buffer.." (Enter saves, Esc cancels)" end
    elseif ev=="peripheral" or ev=="peripheral_detach" then
      discover()
      monitorLayout=nil
      monitorPaintCache={}
    end
    -- The input coroutine draws ONLY the computer console for instant
    -- typing feedback. The main monitor still has a single drawing owner.
    drawConsole()
  end
end
-- Independent fast reactor protection loop, inspired by cc-mek-scada RPS.
-- Optimizer and display may be slow, but this loop runs in its own coroutine.
local function fastSafetyLoop()
  local badReads=0
  local lastActive=false
  local previousCoolant=nil
  local previousTime=nil
  while active do
    local r,u,b=names.reactor,names.turbine,names.boiler
    local q={}
    local tasks={}
    local function ask(field,dev,method)
      tasks[#tasks+1]=function() q[field]=pcRaw(dev,method) end
    end
    ask("on",r,"getStatus")
    ask("formed",r,"isFormed")
    ask("temp",r,"getTemperature")
    ask("damage",r,"getDamagePercent")
    ask("coolant",r,"getCoolantFilledPercentage")
    ask("heated",r,"getHeatedCoolantFilledPercentage")
    ask("waste",r,"getWasteFilledPercentage")
    ask("disabled",r,"isForceDisabled")
    if u then ask("dump",u,"getDumpingMode") end
    if c.requireTurbine then ask("steam",u,"getSteamFilledPercentage") end
    if b then
      ask("bSteam",b,"getSteamFilledPercentage")
      ask("bHot",b,"getHeatedCoolantFilledPercentage")
    end
    parallel.waitForAll(table.unpack(tasks))
    local now=os.epoch("utc")/1000
    local activeNow=q.on==true or (q.on==nil and (lastActive or current.on==true))
    if q.on~=nil then lastActive=q.on end
    local reason=nil
    if q.formed==false then reason="RPS: reactor not formed"
    elseif q.disabled==true then reason="RPS: reactor disabled"
    elseif q.temp and q.temp>=math.min(c.tempTrip,1150) then reason="RPS: high temperature"
    elseif q.damage and q.damage>c.damageTrip then reason="RPS: reactor damage"
    elseif q.coolant and q.coolant<c.coolantTrip then reason="RPS: low coolant"
    elseif q.dump and tostring(q.dump):lower():find("excess",1,true) and
        q.coolant and q.coolant<c.spsDumpCoolantTrip then
      reason="RPS: coolant lost while venting steam"
    elseif q.heated and q.heated>=c.heatedTrip then reason="RPS: heated coolant full"
    elseif q.waste and q.waste>=c.wasteTrip then reason="RPS: nuclear waste full"
    elseif q.steam and q.steam>=(
      (q.dump and tostring(q.dump):lower():find("excess",1,true)) and
      c.spsDumpSteamTrip or c.steamTrip) then
      reason="RPS: turbine steam near full (dump-aware)"
    elseif q.bSteam and q.bSteam>=c.steamTrip then reason="RPS: boiler steam full"
    elseif q.bHot and q.bHot>=c.heatedTrip then reason="RPS: boiler heated coolant full"
    end
    if q.coolant and previousCoolant and previousTime and now>previousTime then
      local drop=(q.coolant-previousCoolant)/(now-previousTime)
      if drop<=-c.coolantDropTrip then reason="RPS: coolant dropping quickly" end
    end
    if q.coolant then previousCoolant=q.coolant;previousTime=now end
    if reason and activeNow and not latched then trip(reason) end

    local valid=q.on~=nil and q.formed~=nil and q.temp~=nil and
      q.damage~=nil and q.coolant~=nil and q.heated~=nil and
      q.waste~=nil and (not c.requireTurbine or q.steam~=nil) and
      (not b or q.bSteam~=nil and q.bHot~=nil)
    if valid then
      badReads=0
      fastSafetyHealthy=true
      fastSafetyLast=now
    else
      badReads=badReads+1
      fastSafetyHealthy=false
      if badReads>=c.safetyBadReads and activeNow and not latched then
        trip("RPS: consecutive sensor/peripheral failures")
      end
    end
    sleep(math.max(0.1,c.fastSafetySeconds))
  end
end

-- One tick sampling for an approximate server TPS, filtered against jitter.
local function tpsLoop()
  local old=os.epoch("utc")/1000
  while active do
    sleep(0.05)
    local now=os.epoch("utc")/1000
    local dt=now-old
    old=now
    if dt>0.025 and dt<3 then
      local observed=clamp(1/dt,1,20)
      tpsEstimate=tpsEstimate*0.88+observed*0.12
    end
  end
end

local function monitorLoop()
  local lastScan=0
  while active do
    local now=os.epoch("utc")/1000
    if not names.reactor or not peripheral.isPresent(names.reactor) or
        (c.requireTurbine and not names.turbine) or
        (now-lastScan>=10) then
      discover()
      lastScan=now
    end
    current=read()
    local good,reason=safety(current)
    if good then recentValid=recentValid+1 else recentValid=0 end
    local transient=not good and type(reason)=="string" and
      (reason:find("read failed",1,true) or
       reason:find("telemetry failed",1,true) or
       reason:find("disconnected",1,true))
    if transient then telemetryBadCount=telemetryBadCount+1
    else telemetryBadCount=0 end
    if not good and current.on~=false and not latched and
        (not transient or telemetryBadCount>=c.safetyBadReads) then
      trip(reason)
    end
    if latched and current.on==true then
      pcall(peripheral.call,names.reactor,"scram")
    end
    if good and not latched then auto(current) end
    if current.safeCap==nil then
      current.safeCap=safeCap(current,c.spsSteamFlowFraction,
        mode~="SPS" or c.spsTurbineFlowHardCap)
      if mode=="SPS" then
        current.spsCapReason="WAIT: PROCESS TELEMETRY"
      end
    end
    -- Preserve the chosen control action instead of overwriting it
    -- with a generic list of warnings on every display refresh.
    if not current.limit then current.limit=bottleneck(current) end
    history(current)
    display()
    sleep(math.max(0.2,c.sampleSeconds))
  end
end
-- Headless scenario hook; completely inert in normal CC:Tweaked execution.
if rawget(_G,"CC_MEKANISM_TEST")==true then
  return {
    exerciseSPS=function(t)
      current=t
      mode="SPS"
      latched=false
      lastChange=t.ts-100
      fastSafetyHealthy=true
      fastSafetyLast=t.ts
      spsTrendResetAt=t.ts-100
      autoSPS(t)
      return {mode=mode,info=info,limit=t.limit,cap=t.safeCap}
    end,
    safety=safety,
    read=read,
    logOnce=history,
    command=command,
    getFluxReference=function() return c.fluxLimitFE end,
    getInfo=function() return info end,
    drawMonitor=function(dev,t)
      current=t or current
      local ok=render(dev,true)
      return buttons,ok
    end,
    drawConsole=drawConsole,
    consoleEdit=function(kind,typed)
      edit=kind
      buffer=tostring(typed or "")
      drawConsole()
    end,
    consoleType=function(char)
      buffer=buffer..tostring(char)
      drawConsole()
    end,
    consoleSave=function()
      if not edit then return false end
      local ok=setTyped()
      if ok then edit=nil;buffer="" end
      drawConsole()
      return ok
    end,
    consoleState=function()
      return {edit=edit,buffer=buffer,info=info,ceiling=c.autoBurnCeiling}
    end,
  }
end
local ok,err=xpcall(function()
  parallel.waitForAny(monitorLoop,fastSafetyLoop,tpsLoop,inputLoop)
end,
  function(e) return tostring(e) end)
if names.reactor and peripheral.isPresent(names.reactor) then
  pcall(peripheral.call,names.reactor,"scram")
end
redstoneAlarm(not ok or latched)
screen.setBackgroundColor(colors.black);screen.setTextColor(colors.white)
screen.clear();screen.setCursorPos(1,1)
print(ok and "Stopped; SCRAM attempted." or ("ERROR: "..tostring(err).." (SCRAM attempted)"))
