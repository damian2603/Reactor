-- Project Infinity / Mekanism Fission-Turbine-SPS Controller 3.0 (SPS-first antimatter optimizer)
-- CC:Tweaked 1.20.1. Standalone, no dependencies.
-- Adapted from analysis of Mekanism's CC API; inspired by cc-mek-scada's
-- fail-safe alarm philosophy. Not a copy of upstream code.
-- IMPORTANT: independent Fission Logic Adapters are still required.
local ROOT = "/cc-mekanism"
local CONF, CSV = ROOT.."/settings", ROOT.."/history.csv"
if not fs.exists(ROOT) then fs.makeDir(ROOT) end
local defaults = {
  reactor="", turbine="", sps="", boiler="", matrix="", monitor="",
  sampleSeconds=1, logSeconds=10,
  maxAutoBurn=1.0, step=0.1, stepSeconds=15,
  autoBurnCeiling=0, -- 0=use detected reactor maximum; manual override only
  autoRampFraction=0.005, -- 0.5% of detected max burn per ramp interval
  tempTrip=1000, tempWarn=850, damageTrip=0,
  coolantTrip=0.60, coolantWarn=0.85, coolantDropTrip=0.08,
  wasteTrip=0.85, wasteWarn=0.68, heatedTrip=0.85, heatedWarn=0.68,
  steamTrip=0.95, steamWarn=0.89, turbineEnergyWarn=0.92,
  feTarget=0.95, feDeadband=0.025, feEnergyHigh=0.93,
  feSteamHold=0.89, feSteamThrottle=0.93,
  feRateStabilitySeconds=12, -- allow turbine flow to settle after each change
  spsInputWarn=0.85, spsOutputWarn=0.90,
  spsSolarUtilization=0.92, -- solar peak throughput headroom
  spsSteamFlowFraction=0.96, -- thermal flow cap, not a power target
  spsRateChangeSeconds=12,
  spsRampFraction=0.01, -- fraction of actual max burn rate per step
  spsNoSolarHold=true, -- require Solar Neutron Activator telemetry
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
    end
  end
else
  local f=fs.open(CONF,"w")
  if f then f.write(textutils.serialize(c));f.close() end
end
local function save()
  local f=fs.open(CONF,"w")
  if f then f.write(textutils.serialize(c));f.close() end
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
local function pc(name,method,...)
  if not name or not peripheral.isPresent(name) then return nil end
  local ok,v=pcall(peripheral.call,name,method,...)
  if ok then return v end
  return nil
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
}
local order={"reactor","turbine","sps","boiler","matrix","monitor"}
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
local mode="MANUAL" -- NEVER persist automatic operation or auto-start
local uiPage=1
local rateHistory={}
local alarmHistory={}
local lastAlarmText=""
local spsEMA=nil
local spsWindow={}
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
  t.bFormed=pc(b,"isFormed")
  t.bSteam=N(pc(b,"getSteamFilledPercentage"))
  t.bHot=N(pc(b,"getHeatedCoolantFilledPercentage"))
  t.bWater=N(pc(b,"getWaterFilledPercentage"))
  t.bBoilCapacity=N(pc(b,"getBoilCapacity"))
  t.spFormed=pc(sp,"isFormed")
  t.spInput=N(pc(sp,"getInputFilledPercentage"))
  t.spOutput=N(pc(sp,"getOutputFilledPercentage"))
  t.spRate=N(pc(sp,"getProcessRate"))
  t.spInputAmount=N(pc(sp,"getInput"))
  t.spOutputAmount=N(pc(sp,"getOutput"))
  t.spEnergyUsedFE=t.spRate and
    t.spRate*SPS_POLONIUM_PER_ANTIMATTER*
    SPS_JOULES_PER_POLONIUM/JOULES_PER_FE or nil
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
  t.imEnergy=N(pc(im,"getEnergyFilledPercentage"))
  t.imIn=N(pc(im,"getLastInput"));t.imOut=N(pc(im,"getLastOutput"))
  t.imInFE=t.imIn and t.imIn/JOULES_PER_FE
  t.imOutFE=t.imOut and t.imOut/JOULES_PER_FE
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
  elseif t.spInput and t.spInput>=0.40 and t.spRate and
       t.fissionAntimatterPotential and
       t.spRate<t.fissionAntimatterPotential*0.75 then
    t.spsDiagnosis="SPS COIL FE / PROCESSING LIMIT"
  elseif t.spInput and t.spInput<0.07 and t.spsEfficiency and
       t.spsEfficiency<0.75 then
    t.spsDiagnosis="SPS POLONIUM STARVED"
  elseif t.steam and t.steam>=c.feSteamHold then
    t.spsDiagnosis="TURBINE STEAM FLOW LIMIT"
  else
    t.spsDiagnosis="SPS RUNNING / BALANCED"
  end
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
  end
  if #rateHistory>=2 then
    local first=rateHistory[1]
    local total=0
    for _,v in ipairs(rateHistory) do total=total+v.rate end
    t.spRateAverage=total/#rateHistory
    t.spRateTrend=t.spRate-first.rate
  end
  previous=t
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
  if t.temp>=c.tempTrip then return false,"critical temperature" end
  if t.damage>c.damageTrip then return false,"reactor damage" end
  if t.coolant<c.coolantTrip then return false,"coolant too low" end
  if t.waste>=c.wasteTrip then return false,"nuclear waste full" end
  if t.heated>=c.heatedTrip then return false,"heated coolant full" end
  if t.steam and t.steam>=c.steamTrip then return false,"turbine steam full" end
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
local function safeCap(t,flowFraction)
  local cap=t.maxBurn or 0
  flowFraction=flowFraction or c.feTarget
  if c.autoBurnCeiling>0 then cap=math.min(cap,c.autoBurnCeiling) end
  -- Empirical steam-to-burn conversion: only direct-water-cooled fission.
  -- For sodium cooling, a separate boiler converts heat to steam.
  if t.bFormed~=true and not t.sodiumCoolant and
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
  if t.bFormed~=true and not t.sodiumCoolant and
      learnedSteamPerBurn and
      t.maxFlow and t.maxFlow>0 then
    cap=math.min(cap,t.maxFlow*flowFraction/learnedSteamPerBurn)
    if c.returnWaterRequired and t.waterOut and t.waterOut>0 then
      cap=math.min(cap,t.waterOut*0.95/learnedSteamPerBurn)
    end
  end
  return math.floor(math.max(0,cap)*100+0.5)/100
end
local function autoSPS(t)
  -- First objective: maximize mB antimatter/t without filling waste,
  -- Polonium or Antimatter buffers. Turbine FE is a by-product.
  if not names.sps or t.spFormed~=true or t.spRate==nil or
      t.spInput==nil or t.spOutput==nil then
    mode="MANUAL"
    info="SPS AUTO unavailable: missing SPS telemetry"
    return
  end
  if t.snaCount==0 or t.snaBroken>0 then
    if c.spsNoSolarHold then
      mode="MANUAL"
      info="SPS AUTO needs ALL Solar Neutron Activators connected"
      return
    end
  end
  if t.sodiumCoolant and not names.boiler then
    mode="MANUAL";info="SPS AUTO requires sodium boiler telemetry";return
  end
  if c.returnWaterRequired and (not t.waterOut or t.waterOut==0) then
    mode="MANUAL";info="SPS AUTO requires return-water telemetry";return
  end
  if t.burn==nil or t.maxBurn==nil then return end
  local baseCap=safeCap(t,c.spsSteamFlowFraction)
  local cap=baseCap
  if t.snaCount>0 and t.snaBroken==0 then
    cap=math.min(cap,t.snaWasteCapacity*
      clamp(c.spsSolarUtilization,0.5,1))
  end
  cap=math.max(0,math.floor(cap*100+0.5)/100)
  t.safeCap=cap
  t.spsTargetRate=cap/(WASTE_PER_POLONIUM*SPS_POLONIUM_PER_ANTIMATTER)
  t.spsTargetFE=t.spsTargetRate*SPS_POLONIUM_PER_ANTIMATTER*
    SPS_JOULES_PER_POLONIUM/JOULES_PER_FE
  local step=math.max(0.1,math.floor(t.maxBurn*
    clamp(c.spsRampFraction,0.0001,0.05)*100+0.5)/100)
  local target=t.burn
  local reason="HOLD: SPS THROUGHPUT"
  local solarCeiling=t.snaWasteCapacity*clamp(c.spsSolarUtilization,0.5,1)
  local poloniumSurplus=t.spInputDelta and t.spInputDelta>0.0005
  local poloniumDepletion=t.spInputDelta and t.spInputDelta< -0.0005
  local now=t.ts
  local stabilized=(now-lastChange)>=c.spsRateChangeSeconds
  local solarAvailable=t.snaCount>0 and t.snaBroken==0 and
    t.snaProduction>0
  local outputBlocked=t.spOutput>=c.spsOutputWarn
  -- Do not waste fissile fuel when solar activation is impossible:
  -- e.g. night or rain reducing net available throughput to zero.
  if not solarAvailable and t.snaCount>0 and t.snaBroken==0 then
    target=0
    reason="PAUSE: NO SOLAR POLONIUM PRODUCTION"
  elseif outputBlocked then
    target=0
    reason="PAUSE: ANTIMATTER OUTPUT FULL"
  elseif t.snaMaxOutputFill>=0.94 then
    target=math.max(0,t.burn-math.max(step*3,t.burn*0.25))
    reason="THROTTLE: SOLAR OUTPUT BACKPRESSURE"
  elseif t.spInput>=c.spsInputWarn then
    target=math.max(0,t.burn-math.max(step*3,t.burn*0.20))
    reason="THROTTLE: SPS POLONIUM FULL"
  elseif t.waste>=c.wasteWarn or
      t.wasteDelta and t.wasteDelta>0.002 and t.waste>=0.30 then
    target=math.max(0,t.burn-math.max(step*2,t.burn*0.15))
    reason="THROTTLE: NUCLEAR WASTE BACKLOG"
  elseif t.heated>=c.heatedWarn or
      t.coolant<c.coolantWarn or t.temp>=c.tempWarn or
      t.bSteam and t.bSteam>=c.steamWarn or
      t.bHot and t.bHot>=c.heatedWarn then
    target=math.max(0,t.burn-math.max(step*2,t.burn*0.10))
    reason="THROTTLE: REACTOR COOLING"
  elseif t.steam and t.steam>=c.feSteamThrottle and
      (t.steamDelta==nil or t.steamDelta>=-0.001) then
    target=math.max(0,t.burn-math.max(step,t.burn*0.10))
    reason="THROTTLE: TURBINE STEAM BACKPRESSURE"
  elseif t.burn>cap+0.009 then
    target=cap
    reason="CAP: AVAILABLE SOLAR / TURBINE CAPACITY"
  elseif not stabilized then
    reason="STABILIZING SPS / SOLAR PROCESSING"
  elseif t.spInput>=0.50 and t.spsEfficiency and
      t.spsEfficiency<0.70 then
    -- Polonium is present but SPS is not processing it at the
    -- theoretical rate. Additional fission cannot fix that.
    reason="HOLD: SPS POWER / PROCESSING BOTTLENECK"
    if t.spInputDelta and t.spInputDelta>0.003 then
      target=math.max(0,t.burn-step)
    end
  elseif poloniumSurplus and t.spInput>=0.65 and t.spRate120 and t.spRate120>0 then
    target=math.max(0,t.burn-step)
    reason="TRIM: POLONIUM BUFFER GROWING"
  elseif t.snaMaxOutputFill>=0.75 then
    reason="HOLD: SNA OUTPUT TRANSFER SLOW"
  elseif t.steam and t.steam>=c.feSteamHold then
    reason="HOLD: STEAM SAFETY HEADROOM"
  elseif poloniumDepletion and t.spInput<0.03 and t.burn<cap-0.009 then
    target=math.min(cap,t.burn+step)
    reason="RAMP: SPS POLONIUM BUFFER FALLING"
  elseif t.burn<cap-0.009 then
    target=math.min(cap,t.burn+step)
    reason="RAMP: MAXIMIZING ANTIMATTER / TICK"
  else
    reason="HOLD: SUPPLY CAP (FE LIMIT NOT VERIFIED)"
  end
  -- Prevent twitchy feedback on every tick; pauses and cap drops
  -- bypass the timer, but normal increases cannot.
  if target>t.burn and not stabilized then target=t.burn end
  target=math.max(0,math.min(target,cap))
  if math.abs(target-t.burn)>=0.009 then
    local ok,err=burn(target)
    if not ok then
      mode="MANUAL";info="SPS AUTO setBurnRate failed: "..tostring(err)
      return
    end
    lastChange=now
  end
  t.limit=reason
  lastSpsDecision=reason
  if math.abs(target-t.burn)>=0.009 then lastSpsChange=now end
  info=reason.." | AM "..n(t.spRate,3).."/"..n(t.spsTargetRate,3).." mB/t"
end
local function auto(t)
  if mode=="MANUAL" or latched or t.on~=true then return end
  if mode=="SPS" then autoSPS(t);return end
  if mode=="SPS" and (not names.sps or t.spFormed~=true or
      t.spInput==nil or t.spOutput==nil or t.spRate==nil) then
    mode="MANUAL";info="AUTO SPS disabled: no SPS data";return
  end
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
  elseif mode=="SPS" and (t.spInput and t.spInput>=c.spsInputWarn or
      t.spOutput and t.spOutput>=c.spsOutputWarn) then
    if canThrottle then
      target=math.max(0.1,t.burn-math.max(step,t.burn*0.10))
      decision="THROTTLE: SPS BUFFER"
    else decision="HOLD: SPS BUFFER / SETTLING" end
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
  "fuel","steamMade","coolantType","rLength","rWidth","rHeight","assemblies","boilEfficiency",
  "steam","steamIn","flow","maxFlow","power","energy","tLength","tWidth","tHeight",
  "blades","coils","vents","condensers","maxProduction",
  "powerFE","maxProductionFE","waterOut","productionFraction",
  "spInput","spOutput","spRate","spInputAmount","spOutputAmount",
  "spEnergyUsedFE","snaCount","snaActive","snaSun","snaProduction",
  "snaWasteCapacity","snaAntimatterPotential","snaMaxOutputFill",
  "snaMaxInputFill","snaTotalInput","snaTotalOutput",
  "fissionAntimatterPotential","spsEfficiency","spsTargetRate","spsTargetFE","spsDiagnosis",
  "spLength","spWidth","spHeight","spCoils",
  "bSteam","bHot","bWater","bBoilCapacity","imEnergy","imIn",
  "imOut","imInFE","imOutFE"}
local function history(t)
  if t.ts-lastLog<c.logSeconds then return end
  lastLog=t.ts
  local exists=fs.exists(CSV)
  local f=fs.open(CSV,"a")
  if not f then return end
  if not exists then f.writeLine(table.concat(fields,",")..",mode,alarm") end
  local vals={}
  for _,key in ipairs(fields) do
    local v=t[key]
    if type(v)=="boolean" then v=v and 1 or 0 end
    vals[#vals+1]=v==nil and "" or tostring(v)
  end
  vals[#vals+1]=mode
  vals[#vals+1]='"'..alarm:gsub('"',"'")..'"'
  f.writeLine(table.concat(vals,","));f.close()
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
local function scadaDraw(dev,isMonitor)
  local w,h=dev.getSize()
  if h<19 or w<38 then return false end
  buttons={}
  local function paint(y,label,fg,bg)
    if y<1 or y>h then return end
    dev.setCursorPos(1,y)
    dev.setBackgroundColor(bg or colors.black)
    dev.setTextColor(fg or colors.white)
    local s=tostring(label):sub(1,w)
    dev.write(s..string.rep(" ",math.max(0,w-#s)))
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
    paint(7,"EMA "..n(current.spRateEMA,4).." | 120s AVG "..n(current.spRate120,4).." mB/t")
    bar(9,"Polonium",current.spInput,colors.yellow)
    bar(10,"Antimatter",current.spOutput,colors.lime)
    paint(12,"Solar "..tostring(current.snaActive or 0).."/"..tostring(current.snaCount or 0)..
      "  potential "..fmt(current.snaProduction).." polonium/t")
    paint(13,"Fission potential "..n(current.fissionAntimatterPotential,4).." AM/t")
    paint(14,"SPS FE demand ~"..fmt(current.spEnergyUsedFE).." FE/t (EST.)")
    paint(15,"Flux Point: MANUAL | SPS FE supply unmeasured",colors.yellow)
    paint(16,"Control: "..lastSpsDecision,colors.orange)
    paint(17,"DIAG "..tostring(current.spsDiagnosis or "--"),colors.orange)
    if h>=30 then
      paint(19,"AM PRODUCTION HISTORY ("..#rateHistory.." samples)",colors.cyan)
      local gh=math.min(5,h-27)
      if gh>0 and #rateHistory>0 then
        local graphWidth=math.min(w,#rateHistory)
        local peak=0
        for _,v in ipairs(rateHistory) do peak=math.max(peak,v.rate or 0) end
        peak=math.max(peak,0.00001)
        for x=1,graphWidth do
          local v=rateHistory[#rateHistory-graphWidth+x].rate or 0
          local level=math.floor(v/peak*gh+0.5)
          for yy=0,level-1 do
            dev.setCursorPos(x,20+gh-1-yy)
            dev.setTextColor(colors.lime)
            dev.write("|")
          end
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
    paint(14,"AUTO CAP "..n(current.safeCap,2).." mB/t")
    paint(15,"CONTROL "..tostring(current.limit or "--"),colors.yellow)
    paint(17,"SCRAM protection: "..(latched and "LATCHED" or "ARMED"),
      latched and colors.red or colors.lime)
  elseif uiPage==3 then
    title("TURBINE / ENERGY")
    paint(6,"FE output "..fmt(current.powerFE).." / "..fmt(current.maxProductionFE).." FE/t")
    paint(7,"Steam flow "..fmt(current.flow).." / "..fmt(current.maxFlow))
    bar(9,"Steam",current.steam,colors.aqua)
    bar(10,"FE buffer",current.energy,colors.lime)
    paint(12,"Matrix IN "..fmt(current.imInFE).." FE/t")
    paint(13,"Matrix OUT "..fmt(current.imOutFE).." FE/t")
    paint(15,"FE delivery to SPS: NOT MEASURED",colors.yellow)
    paint(16,"Flux Point limit: set manually",colors.yellow)
  elseif uiPage==4 then
    title("DIAGNOSTICS / ALARMS")
    paint(6,"SPS: "..tostring(current.spsDiagnosis or "--"),colors.yellow)
    paint(7,"Safety: "..(latched and alarm or "NO LATCHED ALARM"),
      latched and colors.red or colors.lime)
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
    paint(13,"CSV log: /cc-mekanism/history.csv")
    paint(15,"Note: 'potential' is not confirmed optimality.",colors.orange)
  end
  if isMonitor then
    local nav={"SPS","REACTOR","FE","DIAG","LOG"}
    local yNav=h-5
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
    if dev.setTextScale then dev.setTextScale(0.5) end
    local w,h=dev.getSize()
    dev.setBackgroundColor(colors.black);dev.setTextColor(colors.white);dev.clear()
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
    info="Display error: "..tostring(err)
    return false
  end
  return true
end
local function display()
  if names.monitor and peripheral.isPresent(names.monitor) then
    local success=render(peripheral.wrap(names.monitor),true)
    if not success then render(screen,false);return end
    screen.setBackgroundColor(colors.black);screen.setTextColor(colors.white)
    screen.clear();screen.setCursorPos(1,1)
    print("Project Infinity | "..mode.." | "..(latched and "ALARM" or "OK"))
    print("Burn "..n(current.burn,2).." / actual "..n(current.actual,2))
    print("Temp "..n(current.temp,1).." K | coolant "..p(current.coolant)..
      " waste "..p(current.waste).." turbine steam "..p(current.steam))
    print("SPS "..n(current.spRate,3).." AM/t | solar "..
      tostring(current.snaActive or 0).."/"..tostring(current.snaCount or 0))
    print("Polonium "..p(current.spInput).." antimatter "..p(current.spOutput))
    print("Diagnosis "..tostring(current.spsDiagnosis))
    print("Alarm "..(alarm~="" and alarm or "none"))
    print("Keys: +/- b c m f p s r q")
  else render(screen,false) end
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
local function command(cmd)
  local pageNumber=tonumber(tostring(cmd):match("^page([1-5])$"))
  if pageNumber then uiPage=pageNumber;return end
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
    if cap>=max then c.autoBurnCeiling=0
    else c.autoBurnCeiling=math.max(0.1,math.floor(cap*100+0.5)/100) end
    save()
    info="Auto ceiling: "..(c.autoBurnCeiling==0 and "DETECTED MAX" or n(c.autoBurnCeiling,2))
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
local edit,buffer=nil,""
local function setTyped()
  local v=tonumber(buffer)
  if not v or v<0 then info="Invalid number";return end
  if edit=="cap" then
    -- Enter 0 to restore automatic cap from detected structure.
    c.autoBurnCeiling=math.floor(v*100+0.5)/100
    save();info="AUTO ceiling "..(v==0 and "DETECTED MAX" or n(v,2))
  elseif edit=="target" then
    if v<20 or v>100 then
      info="Target must be between 20 and 100 percent"
    else
      c.feTarget=math.floor(v*10+0.5)/1000
      smoothedPowerRatio=nil
      lastChange=current.ts or 0
      save()
      info="FE generation target "..n(v,1).."%"
    end
  elseif edit=="burn" then
    if latched then info="ALARM LATCHED";return end
    local ok,r=burn(v)
    if ok then mode="MANUAL";info="Manual burn "..n(r,2)
    else info="Burn error: "..tostring(r) end
  end
end
local function inputLoop()
  while active do
    local ev,a,b,d=os.pullEvent()
    if edit then
      if ev=="char" and a:match("[0-9%.]") and #buffer<15 then buffer=buffer..a
      elseif ev=="key" and a==keys.backspace then buffer=buffer:sub(1,-2)
      elseif ev=="key" and a==keys.escape then edit=nil;buffer="";info="Edit cancelled"
      elseif ev=="key" and (a==keys.enter or a==keys.numPadEnter) then
        setTyped();edit=nil;buffer=""
      end
    elseif ev=="char" then
      if a:match("^[1-5]$") then uiPage=tonumber(a)
      elseif a=="q" then active=false;return
      elseif a=="b" then edit="burn";buffer=tostring(current.burn or 0);info="Enter burn: "..buffer
      elseif a=="c" then edit="cap";buffer=tostring(c.autoBurnCeiling);info="Enter ceiling (0=automatic): "..buffer
      elseif a=="t" then edit="target";buffer=tostring(math.floor(c.feTarget*1000+0.5)/10)
        info="Target turbine output % (20..100): "..buffer
      else
        local m={["-"]="minus",["+"]="plus",["="]="plus",
          m="manual",f="fe",p="sps",s="scram",r="start"}
        if m[a] then command(m[a]) end
      end
      if edit then info="Editing "..edit..": "..buffer.." (Enter saves, Esc cancels)" end
    elseif ev=="monitor_touch" and a==names.monitor then
      for _,v in ipairs(buttons) do
        if d==v.y and b>=v.x and b<=v.last then command(v.id);break end
      end
    elseif ev=="peripheral" or ev=="peripheral_detach" then discover()
    end
    display()
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
    if not good and current.on~=false then trip(reason) end
    if latched and current.on==true then trip(alarm) end
    if good and not latched then auto(current) end
    if current.safeCap==nil then current.safeCap=safeCap(current) end
    -- Preserve the chosen control action instead of overwriting it
    -- with a generic list of warnings on every display refresh.
    if not current.limit then current.limit=bottleneck(current) end
    history(current)
    display()
    sleep(math.max(0.2,c.sampleSeconds))
  end
end
local ok,err=xpcall(function() parallel.waitForAny(monitorLoop,inputLoop) end,
  function(e) return tostring(e) end)
if names.reactor and peripheral.isPresent(names.reactor) then
  pcall(peripheral.call,names.reactor,"scram")
end
redstoneAlarm(not ok or latched)
screen.setBackgroundColor(colors.black);screen.setTextColor(colors.white)
screen.clear();screen.setCursorPos(1,1)
print(ok and "Stopped; SCRAM attempted." or ("ERROR: "..tostring(err).." (SCRAM attempted)"))
