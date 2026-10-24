-- Headless runtime smoke tests for the actual controller.lua, no Minecraft required.
CC_MEKANISM_TEST=true
local epochMs=1000000
os.epoch=function() return epochMs end
local originalDofile=dofile
dofile=function(path)
  if path=="/cc-mekanism/optimizer_math.lua" then
    return originalDofile("cc-mekanism/optimizer_math.lua")
  elseif path=="/cc-mekanism/thermal_model.lua" then
    return originalDofile("cc-mekanism/thermal_model.lua")
  elseif path=="/cc-mekanism/controller.packed.lua" then
    return originalDofile("cc-mekanism/controller.packed.lua")
  end
  return originalDofile(path)
end
local stored=1000000
local burnRate=400
local active=true
local calls={}
local data={
  reactor={
    setBurnRate=function(rate) burnRate=rate;calls[#calls+1]={"burn",rate};return true end,
    scram=function() active=false;calls[#calls+1]={"scram"};return true end,
    activate=function() active=true;return true end,
    getTemperature=600,getStatus=function() return active end,isFormed=true,
    getBurnRate=function() return burnRate end,
    getActualBurnRate=function() return burnRate end,
    getMaxBurnRate=1000,getDamagePercent=0,
    getCoolantFilledPercentage=1,getHeatedCoolantFilledPercentage=0.02,
    getWasteFilledPercentage=0.1,getFuelFilledPercentage=0.75,
    getFuel={amount=3000},isForceDisabled=false,
    getLength=5,getWidth=5,getHeight=5,getFuelAssemblies=12,
    getFuelCapacity=8000,getWasteCapacity=100000,
    getCoolantCapacity=100000,getHeatingRate=50000,
    getBoilEfficiency=1,getHeatCapacity=1736000
  },
  turbine={
    getMaxFlowRate=100000,getProductionRate=100000,isFormed=true,
    getSteamFilledPercentage=0.1,getEnergyFilledPercentage=0.2,
    getFlowRate=50000,getLastSteamInputRate=50000,
    getMaxProduction=1000000,getLength=5,getWidth=5,getHeight=10
  },
  sps={
    getProcessRate=0.039,getInputFilledPercentage=0.02,
    getOutputFilledPercentage=0.1,isFormed=true,
    getInput=40,getOutput=1,getInputCapacity=2000,getOutputCapacity=1000,
    getLength=5,getWidth=5,getHeight=5,getCoils=8
  },
  sna={
    getProductionRate=100,getPeakProductionRate=100,
    canSeeSun=true,getInputFilledPercentage=0.1,
    getOutputFilledPercentage=0.05,getInput=10,getOutput=10
  },
  tank={getStored=function() return {amount=stored} end,getCapacity=2000000}
}
peripheral={}
function peripheral.getNames() return {"reactor","turbine","sps","sna","tank"} end
function peripheral.isPresent(name) return data[name]~=nil end
function peripheral.getMethods(name)
  local a={}
  for k in pairs(data[name] or {}) do a[#a+1]=k end
  return a
end
function peripheral.getType() return "generic" end
function peripheral.call(name,method,...)
  local d=data[name]
  assert(d and d[method]~=nil,"missing mock API "..tostring(name).."."..tostring(method))
  local v=d[method]
  if type(v)=="function" then return v(...) end
  return v
end
local mockFiles={}
local mockCapacity=1048576
fs={}
function fs.exists(p) return p=="/cc-mekanism" or mockFiles[p]~=nil end
function fs.makeDir() end
function fs.open(p,mode)
  if mode=="r" and not fs.exists(p) then return nil end
  if mode=="w" then mockFiles[p]="" end
  if mode=="a" and not mockFiles[p] then mockFiles[p]="" end
  return {
    readAll=function() return mockFiles[p] end,
    write=function(s) mockFiles[p]=mockFiles[p]..tostring(s) end,
    writeLine=function(s) mockFiles[p]=mockFiles[p]..tostring(s).."\\n" end,
    close=function() end,
  }
end
function fs.getSize(p) return #(mockFiles[p] or "") end
function fs.getFreeSpace()
  local used=0
  for _,s in pairs(mockFiles) do used=used+#s end
  return math.max(0,mockCapacity-used)
end
function fs.delete(p) mockFiles[p]=nil end
function fs.move(from,to)
  assert(mockFiles[from]~=nil,"mock cannot move missing file "..from)
  assert(mockFiles[to]==nil,"mock cannot overwrite file "..to)
  mockFiles[to]=mockFiles[from]
  mockFiles[from]=nil
end
textutils={serialize=function() return "{}" end,unserialize=function() return {} end}
term={current=function() return {} end}
redstone={setOutput=function() end}
parallel={
  waitForAll=function(...)
    for _,fn in ipairs({...}) do fn() end
  end
}
local function near(a,b,eps,label)
  assert(type(a)=="number" and math.abs(a-b)<=(eps or 0.01),
    (label or "rate").." got "..tostring(a)..", expected "..tostring(b))
end
local function newController(packed)
  active=true
  calls={}
  epochMs=1000000
  burnRate=400
  mockFiles={}
  mockCapacity=1048576
  if packed then
    mockFiles["/cc-mekanism/controller.packed.lua"]="installed"
    return originalDofile("cc-mekanism/controller-launcher.lua")
  end
  return originalDofile("cc-mekanism/controller.lua")
end
local function sample()
  return {
    ts=1000,on=true,burn=400,actual=400,maxBurn=1000,
    temp=600,coolant=1,heated=0.1,waste=0.1,steam=0.1,
    heatCapacity=1736000,thermalModelCap=618.277,thermalState="OK",
    sodiumCoolant=false,spFormed=true,spRate=0.039,spRateEMA=0.039,
    spRate120=0.039,spWindowSeconds=120,spInput=0.02,spOutput=0.1,
    spInputTrend120=0,spsEfficiency=0.975,
    snaCount=1,snaBroken=0,snaProduction=60,snaWasteCapacity=600,
    snaMaxOutputFill=0,
    fuelMeasured=true,fuelCapFresh=true,fuelCap=450,
    fuelFillForControl=0.8,fuelRateLimited=false,
    fuelNetPerTick=0,fuelRapidNet=0,fuelSampleSeconds=180,tps=20
  }
end
do
  local ctl=newController()
  local t=sample()
  local out=ctl.exerciseSPS(t)
  assert(out.mode=="SPS")
  near(out.cap,405,0.01,"fuel cap 450*90%")
  near(burnRate,405,0.01,"controlled SPS growth")
end
do
  local ctl=newController()
  local t=sample()
  t.fuelCap=350
  ctl.exerciseSPS(t)
  near(burnRate,315,0.01,"fuel limited burn")
  assert(t.spsCapReason=="FUEL PRODUCTION (LONG)","show fuel as the active cap")
end
do
  local ctl=newController()
  local t=sample()
  t.snaProduction=0
  local out=ctl.exerciseSPS(t)
  assert(out.mode=="SPS","night idle should keep AUTO SPS")
  near(burnRate,0.01,0.001,"night idle")
end
do
  local ctl=newController()
  local t=sample()
  t.spOutput=0.99
  local out=ctl.exerciseSPS(t)
  assert(out.mode=="MANUAL","full antimatter buffer should stop")
  assert(calls[#calls][1]=="scram","full output must SCRAM")
end
do
  local ctl=newController()
  local t=sample()
  t.fuelMeasured=false
  t.fuelMeterLostFor=120
  local out=ctl.exerciseSPS(t)
  assert(out.mode=="MANUAL","fuel meter loss should disable automation")
  near(burnRate,400,0.01,"no unverified ramp")
end
-- An Elite Tank may hold >1 million mB. Never wait until 30% to
-- reduce fuel consumption if a measured deficit is already evident.
do
  local ctl=newController()
  local t=sample()
  t.fuelCap=nil
  t.fuelCapFresh=false
  t.fuelFillForControl=0.88
  t.fuelRapidNet=-40
  t.fuelRapidProduction=360
  local out=ctl.exerciseSPS(t)
  near(out.cap,324,0.01,"early rapid fuel limit (360*90%)")
  near(burnRate,324,0.01,"early deficit forces burn cap")
  assert(t.fuelRapidLimited==true,"rapid deficit flag")
end
-- Real screenshots: at ~123 mB/t, ~0.012 AM/t and 6 SNA, the
-- turbine flow cap must NOT throttle SPS AUTO to 123 mB/t.
-- 20 MFE/t is recorded manually; the old flow-capped controller stalled
-- at ~123.02 mB/t even with coolant, waste and fuel buffers healthy.
do
  local ctl=newController()
  for _=1,4 do ctl.command("fluxplus") end
  near(ctl.getFluxReference(),20000000,0.01,"screenshot Flux reference")
  local t=sample()
  t.maxBurn=1920
  t.burn=123.02
  t.actual=123.02
  t.spRate=0.012
  t.spRateEMA=0.012
  t.spRate120=0.012
  t.spsEfficiency=0.012/(123.02/10000)
  t.spInput=0.007
  t.spOutput=0
  t.spInputTrend120=0.000005
  t.snaCount=6
  t.snaProduction=280.3
  t.snaWasteCapacity=2803
  t.fuelFillForControl=1
  t.fuelCap=nil
  t.fuelCapFresh=false
  t.fuelRapidNet=0
  t.fuelRapidProduction=123.02
  t.steamMade=10598400
  t.maxFlow=11040000
  t.bFormed=false
  t.steam=0.01
  local result=ctl.exerciseSPS(t)
  assert(result.mode=="SPS")
  near(result.cap,550,0.01,"Flux-derived SPS cap, NOT turbine cap")
  assert(t.spsCapReason=="FLUX FE REFERENCE","show FE as the active cap")
  assert(burnRate>123.02 and burnRate<200,
    "healthy reactor should probe above 123 despite turbine flow limit")
  assert(t.spsTurbineFlowHardCap==false)
end

-- Regression from user's screenshot: 64% steam, 100% coolant and
-- 809 K are normal operating conditions, NOT an excuse for 15% cut.
do
  local ctl=newController()
  for i=1,6 do ctl.command("fluxplus") end
  local t=sample()
  t.maxBurn=1920
  t.burn=414
  t.actual=414
  t.temp=808.9
  t.steam=0.64
  t.steamDelta=0.003
  t.steamTrend=0.003
  t.coolant=1
  t.heated=0
  t.waste=0
  t.dumpExcess=true
  t.spRate=0.042
  t.spRateEMA=0.042
  t.spRate120=0.042
  t.spsEfficiency=0.042/(414/10000)
  t.spInput=0.021
  t.spInputTrend120=0.0013/60
  t.snaProduction=280.3
  t.snaWasteCapacity=2803
  t.fuelCapFresh=false
  t.fuelCap=nil
  t.fuelRapidNet=0
  t.fuelRapidProduction=414
  t.fuelFillForControl=1
  local result=ctl.exerciseSPS(t)
  assert(result.mode=="SPS")
  assert(t.steamPressureState=="OK","64% steam must be normal")
  assert(result.limit=="RAMP: SPS PRODUCTION DEMAND" or
      result.limit=="HOLD: SPS DEMAND BALANCED",
    "healthy steam should not cause protection cooldown: "..tostring(result.limit))
  assert(burnRate>=414,"no 15% steam dump-related oscillation at 64% steam")
end
-- Hold growth at 80% only when there is a sustained rising trend.
do
  local ctl=newController()
  local t=sample()
  t.fuelCapFresh=false
  t.fuelCap=nil
  t.steam=0.80
  t.steamTrend=0.002
  local result=ctl.exerciseSPS(t)
  assert(result.mode=="SPS")
  assert(t.steamPressureState=="HOLD")
  near(burnRate,400,0.01,"hold 80% steam without cutting 15%")
  assert(result.limit:find("STEAM BUFFER GROWING",1,true))
end
-- Genuine high steam pressure must still trigger measured, gentle trimming.
do
  local ctl=newController()
  local t=sample()
  t.fuelCapFresh=false
  t.fuelCap=nil
  t.steam=0.89
  t.steamTrend=0
  local result=ctl.exerciseSPS(t)
  assert(result.mode=="SPS")
  assert(t.steamPressureState=="TRIM")
  near(burnRate,382,0.01,"at 89% trim 4.5%, not 15%")
  assert(result.limit:find("TURBINE STEAM HIGH",1,true))
end
do
  local ctl=newController()
  local t=sample()
  t.fuelCapFresh=false
  t.fuelCap=nil
  t.steam=0.94
  t.steamTrend=0.001
  local result=ctl.exerciseSPS(t)
  assert(t.steamPressureState=="TRIM_FAST")
  near(burnRate,360,0.01,"near emergency 94% throttle 10%")
end

-- With a full tank, -0.06 mB/t is measurement jitter and MUST
-- NOT freeze the optimizer at 330-400 mB/t.
do
  local ctl=newController()
  local t=sample()
  t.fuelCap=nil
  t.fuelCapFresh=false
  t.fuelFillForControl=1.0
  t.fuelRapidNet=-0.06
  t.fuelRapidProduction=400
  t.spRate=0.040
  t.spRateEMA=0.040
  t.spRate120=0.040
  t.spsEfficiency=1.0
  local result=ctl.exerciseSPS(t)
  assert(t.fuelDeficitMaterial==false,
    "tiny 0.06 mB/t deficit at 400 is below 1% tolerance")
  assert(t.fuelDeficitThreshold==4,"4 mB/t material deficit threshold")
  assert(burnRate>400,
    "ramp must not be blocked by tiny full-tank drift: "..tostring(result.limit))
end

-- True tank drain (8 mB/t) must constrain burn even while tank is full.
do
  local ctl=newController()
  local t=sample()
  t.fuelCap=nil
  t.fuelCapFresh=false
  t.fuelFillForControl=1.0
  t.fuelRapidNet=-8
  t.fuelRapidProduction=392
  local result=ctl.exerciseSPS(t)
  assert(t.fuelDeficitMaterial==true)
  near(result.cap,352.8,0.01,"measured fuel supply capped with margin")
  near(burnRate,352.8,0.01,"real fuel starvation still acts promptly")
end

-- Once thermal trimming begins, don't oscillate up again immediately when
-- steam dips from 89% to 86%; release only after recovery to <=83%.
do
  local ctl=newController()
  local high=sample()
  high.steam=0.89
  ctl.exerciseSPS(high)
  assert(high.steamPressureRecovering==true)
  near(burnRate,382,0.01,"initial pressure trim")
  local recovering=sample()
  recovering.steam=0.86
  recovering.burn=burnRate
  recovering.actual=burnRate
  ctl.exerciseSPS(recovering)
  assert(recovering.steamPressureState=="HOLD")
  assert(recovering.steamPressureReason=="STEAM PRESSURE RECOVERING")
  near(burnRate,382,0.01,"no immediate rebound at 86% steam")
  local recovered=sample()
  recovered.steam=0.82
  recovered.burn=burnRate
  recovered.actual=burnRate
  ctl.exerciseSPS(recovered)
  assert(recovered.steamPressureRecovering==false)
  assert(burnRate>382,"ramp may resume after pressure recovery")
end

-- Integrated fuel estimate must continue across burn rate changes:
-- 90s at 300 mB/t, then 90s at 450 mB/t, 400 mB/t production.
do
  local ctl=newController()
  burnRate=300
  stored=1000000
  epochMs=1000000
  local latest=ctl.read()
  for i=1,60 do
    local rate=i<=30 and 300 or 450
    burnRate=rate
    stored=stored+(400-rate)*3*20
    epochMs=epochMs+3000
    latest=ctl.read()
  end
  near(latest.fuelProducedEstimate,400,5,"integrated fuel production")
  assert(latest.fuelSampleSeconds>=120,"fuel window not reset by setpoint")
  assert(latest.fuelCapFresh==true,"fuel cap should calibrate")
end
-- Regression from a real 2026-10-24 Project Infinity probe:
-- getStatus=false and canSeeSun=false are valid measurements, not API failures.
do
  local ctl=newController()
  active=false
  data.sna.canSeeSun=false
  data.sna.getProductionRate=0
  stored=1024000
  data.tank.getCapacity=1024000
  local t=ctl.read()
  assert(t.on==false,"reactor OFF must remain boolean false")
  assert(t.disabled==false,"isForceDisabled=false must remain false")
  assert(t.snaBroken==0,"night canSeeSun=false is valid telemetry")
  assert(t.snaSun==0,"no SNA sunlight at night")
  near(t.fuelTankFill,1,0.00001,"Elite Chemical Tank is full")
  near(t.fuelStored,1024000,0.00001,"Mekanism chemical-stack amount")
  local good,err=ctl.safety(t)
  assert(good==true,"safe inactive reactor should not trigger read-failed: "..tostring(err))
  data.sna.canSeeSun=true
  data.sna.getProductionRate=100
end
-- A failed boolean API read (nil) is not the same as a valid false response.
do
  local original=data.sna.canSeeSun
  data.sna.canSeeSun=function() return nil end
  local ctl=newController()
  local t=ctl.read()
  assert(t.snaBroken==1,"missing canSeeSun reading must mark SNA telemetry broken")
  data.sna.canSeeSun=original
end
-- Project Infinity real-world thermal regression: 18x18x18, water,
-- 448mB/t at 889.6K and 540mB/t near 995K are normal equilibria.
do
  local ctl=newController()
  data.reactor.getHeatCapacity=1736000
  data.reactor.getTemperature=889.6
  burnRate=448
  local t=ctl.read()
  near(t.expectedTemp,889.28,0.05,"predicted user screenshot 448")
  assert(t.heatCapacity==1736000)
  assert(t.thermalState=="OK",
    "889.6K must not be considered an overheat at 448mB/t")
  assert(ctl.safety(t)==true,"889K normal, no SCRAM")
  burnRate=540
  data.reactor.getTemperature=995
  epochMs=epochMs+25000
  t=ctl.read()
  near(t.expectedTemp,995.27,0.05,"predicted user manual 540")
  assert(t.thermalState=="OK",
    "995K at 540 burn must not cause the obsolete 850K warning")
  assert(ctl.safety(t)==true,"995K below protective 1150K RPS")
  near(t.thermalModelCap,618.3,1,
    "thermal ceiling from actual heat capacity at 1100K")
  data.reactor.getTemperature=1150
  epochMs=epochMs+25000
  t=ctl.read()
  local good,why=ctl.safety(t)
  assert(good==false and why:find("SCRAM",1,true),
    "1150K must cause proactive SCRAM before 1200K damage")
  data.reactor.getTemperature=600
end
do
  local ctl=newController()
  for i=1,10 do ctl.command("fluxplus") end
  local t=sample()
  t.maxBurn=1920
  t.burn=540
  t.actual=540
  t.temp=995
  t.thermalState=nil
  t.expectedTemp=nil
  t.heatCapacity=1736000
  t.thermalModelCap=618.3
  t.spRate=0.054
  t.spRate120=0.054
  t.spRateEMA=0.054
  t.spsEfficiency=1
  t.snaCount=6
  t.snaProduction=280
  t.snaWasteCapacity=2800
  t.fuelCapFresh=false
  t.fuelCap=nil
  t.fuelRapidNet=0
  t.fuelRapidProduction=540
  t.fuelFillForControl=1
  local result=ctl.exerciseSPS(t)
  assert(t.thermalState=="OK","thermal model sees healthy 540 at 995K")
  assert(burnRate>=540,"normal reactor 995K should not throttle")
end
do
  local ctl=newController()
  for i=1,14 do ctl.command("fluxplus") end
  local t=sample()
  t.maxBurn=1920
  t.burn=600
  t.actual=600
  t.temp=1110
  t.thermalState=nil
  t.heatCapacity=1736000
  t.thermalModelCap=618.3
  t.snaProduction=280
  t.snaWasteCapacity=2800
  t.fuelCapFresh=false
  t.fuelCap=nil
  t.fuelFillForControl=1
  local result=ctl.exerciseSPS(t)
  assert(t.thermalState=="TRIM",
    "steady 1110K is above the conservative thermal ceiling")
  assert(burnRate<600,"above soft ceiling should trim incrementally")
  assert(result.limit:find("THERMAL",1,true) or
     result.limit:find("REACTOR ABOVE THERMAL",1,true),
    "explicit thermal cause should appear")
end

-- CC:Tweaked monitor UI: +/- 1 MFE/t, touch hitboxes and no repeated
-- whole-screen clears after the first render.
do
  colors={black=1,white=2,cyan=3,lightBlue=4,gray=5,blue=6,
    red=7,lime=8,yellow=9,orange=10,aqua=11,lightGray=12}
  local ctl=newController()
  local dev={width=80,height=39,scale=1,clears=0,writes=0}
  dev.getSize=function() return dev.width,dev.height end
  dev.setTextScale=function(s) dev.scale=s end
  dev.getTextScale=function() return dev.scale end
  dev.setCursorPos=function() end
  dev.setTextColor=function() end
  dev.setBackgroundColor=function() end
  dev.write=function() dev.writes=dev.writes+1 end
  dev.clear=function() dev.clears=dev.clears+1 end
  local buttons,ok=ctl.drawMonitor(dev,sample())
  assert(ok,"initial SCADA monitor render failed")
  assert(dev.clears==1,"monitor should clear once when initialised")
  local minus,plus=nil,nil
  for _,b in ipairs(buttons) do
    if b.id=="fluxminus" then minus=b end
    if b.id=="fluxplus" then plus=b end
  end
  assert(minus and plus,"two Flux +/-1M touch buttons must be visible")
  assert(minus.y==dev.height-4 and plus.y==dev.height-4)
  assert(minus.last<plus.x and plus.last<=dev.width)
  local initialWrites=dev.writes
  ctl.drawMonitor(dev,sample())
  assert(dev.clears==1,"monitor must NOT clear every telemetry refresh")
  assert(dev.writes-initialWrites<initialWrites,
    "unchanged monitor text should be skipped")
  assert(ctl.getFluxReference()==16000000)
  ctl.command("fluxplus")
  assert(ctl.getFluxReference()==17000000,"+1M FE/t must persist")
  ctl.command("fluxplus")
  assert(ctl.getFluxReference()==18000000,"repeat tap adds another 1M")
  ctl.command("fluxminus")
  assert(ctl.getFluxReference()==17000000,"-1M FE/t must subtract")
  assert(ctl.getInfo():find("SET FLUX POINT MANUALLY",1,true),
    "touch updates reference only; Flux Point adjustment is manual")
  local clearBefore=dev.clears
  ctl.drawMonitor(dev,sample())
  assert(dev.clears==clearBefore,"changing FE reference must not flash screen")
  ctl.command("page3")
  ctl.drawMonitor(dev,sample())
  assert(dev.clears==clearBefore+1,"page change requires one clean redraw")
end
-- Real installation follow-up: 525 mB/t, Flux Point at 20 MFE/t.
-- Supplied polonium requires 21 MFE/t for maximum conversion.
do
  local ctl=newController()
  for i=1,4 do ctl.command("fluxplus") end
  data.sps.getProcessRate=0.05
  data.sps.getInputFilledPercentage=0.12
  data.sps.getEnergyFilledPercentage=0
  data.sps.getEnergy=0
  data.sps.getMaxEnergy=1000000000
  data.turbine.getDumpingMode="DUMPING_EXCESS"
  data.reactor.getCoolantFilledPercentage=1
  burnRate=525
  stored=1024000
  local t=ctl.read()
  near(t.spFeRequiredSetpoint,21000000,0.1,"525 burn needs 21 MFE/t")
  near(t.spEnergyUsedFE,20000000,0.1,"0.050 AM uses 20 MFE/t")
  assert(t.feState=="FE_LIMIT_LIKELY" or
      t.feState=="FE_BELOW_BURN_REQUIREMENT",
    "tell operator recorded 20M FE is less than burn energy requirement")
  assert(t.feSuggestedLimit==23000000,"trial FE with room")
  assert(t.dumpExcess==true,"monitor turbine Dumping Excess mode")
  assert(ctl.safety(t)==true,"healthy coolant in excess dumping mode")
  data.reactor.getHeatingRate=10500000
  data.turbine.getFlowRate=10000000
  local ventRisk=ctl.read()
  near(ventRisk.waterReturnGapEstimate,500000,0.1,
    "possible water return shortfall is diagnostic, not actual vent meter")
  data.reactor.getCoolantFilledPercentage=0.979
  local losing=ctl.read()
  local safe,why=ctl.safety(losing)
  assert(safe==false and why:find("water reserve",1,true),
    "dumping steam with critically low coolant must trip")
  data.reactor.getCoolantFilledPercentage=0.99
  local recovered=ctl.read()
  local okay=ctl.safety(recovered)
  assert(okay==true,"coolant recovered above 98% no dumping SCRAM")
  data.reactor.getCoolantFilledPercentage=1
  data.reactor.getHeatingRate=50000
  data.turbine.getFlowRate=50000
  data.turbine.getDumpingMode="IDLE"
  data.sps.getProcessRate=0.039
  data.sps.getInputFilledPercentage=0.02
end
do
  local ctl=newController()
  for i=1,4 do ctl.command("fluxplus") end
  local t=sample()
  t.burn=525
  t.actual=525
  t.maxBurn=1920
  t.snaWasteCapacity=2803
  t.snaProduction=280.3
  t.dumpExcess=true
  t.coolant=0.99
  t.coolantDelta=-0.0008
  t.spRate=0.05
  t.spRate120=0.05
  t.spRateEMA=0.05
  t.spsEfficiency=0.05/(525/10000)
  t.fuelCapFresh=false
  t.fuelCap=nil
  t.fuelRapidNet=0
  t.fuelRapidProduction=525
  local x=ctl.exerciseSPS(t)
  assert(x.mode=="SPS","steam dumping water loss throttles without auto-start")
  assert(burnRate<525,"with falling coolant while venting, burn rate decreases")
  assert(x.limit:find("COOLANT FALLING WHILE DUMPING STEAM",1,true),
    "report exact water-loss protection cause, not generic thermal hold")
end
-- Regression: operator presses C in the computer, previously the editor
-- was invisible because display() printed an eight-line status dump.
-- This now verifies an explicit edit pane and live keyboard characters.
do
  local oldCurrent=term.current
  colors=colors or {black=1,white=2,cyan=3,lightBlue=4,
    gray=5,blue=6,red=7,lime=8,yellow=9,orange=10,lightGray=11}
  local rows,cy={},1
  local terminal={clears=0,writes=0}
  terminal.getSize=function() return 51,19 end
  terminal.setCursorPos=function(_,y) cy=y end
  terminal.setBackgroundColor=function() end
  terminal.setTextColor=function() end
  terminal.clear=function()
    terminal.clears=terminal.clears+1
    rows={}
  end
  terminal.write=function(v)
    terminal.writes=terminal.writes+1
    rows[cy]=v
  end
  term.current=function() return terminal end
  local ctl=newController()
  ctl.drawConsole()
  assert(terminal.clears==1,"computer initial terminal clear")
  assert(rows[10]:find("C - Edit AUTO burn ceiling",1,true),
    "main computer panel must show shortcut C")
  ctl.consoleEdit("cap","")
  assert(rows[10]:find("AUTO BURN CEILING",1,true),
    "pressing C must show an explicit editor")
  assert(rows[11]:find("Current: AUTO MAX",1,true),
    "original limit visible in edit mode")
  assert(rows[12]:find("> _",1,true),
    "empty editable input has a visible placeholder")
  ctl.consoleType("5")
  assert(rows[12]:find("> 5",1,true),"live typing appears immediately")
  ctl.consoleType("5")
  ctl.consoleType("0")
  assert(rows[12]:find("> 550",1,true),"complete typed number visible")
  assert(terminal.clears==1,"typing must not clear computer screen")
  assert(ctl.consoleSave(),"enter saves the typed ceiling")
  assert(ctl.consoleState().ceiling==550)
  assert(ctl.consoleState().edit==nil,"successful save closes editor")
  assert(rows[4]:find("550.00",1,true),"saved ceiling shown in status")
  ctl.consoleEdit("cap","invalid")
  assert(not ctl.consoleSave(),"bad text should not exit the edit pane")
  assert(ctl.consoleState().edit=="cap","invalid edit can be corrected")
  ctl.consoleEdit("flux","22000000")
  assert(ctl.consoleSave(),"flux reference can also be edited")
  assert(ctl.getFluxReference()==22000000)
  term.current=oldCurrent
end

-- Disk budget: logging never terminates or SCRAMs the controller.
do
  local ctl=newController()
  local p="/cc-mekanism/history_v5_thermal.csv"
  local old=p:gsub("%.csv$",".previous.csv")
  local t=sample()
  t.ts=1000
  ctl.logOnce(t)
  assert(mockFiles[p] and #mockFiles[p]>0,"initial CSV created")
  mockFiles[p]=string.rep("A",140010)
  ctl.logOnce({ts=1020,spRate=0.04,temp=995})
  assert(mockFiles[old] and #mockFiles[old]==140010,
    "history rotation preserves previous segment")
  assert(mockFiles[p] and #mockFiles[p]<140000,
    "current CSV fresh after reaching 140KB limit")
  mockCapacity=4000
  local latest={ts=1050,spRate=0.04,temp=995}
  local ok,err=pcall(ctl.logOnce,latest)
  assert(ok,"running out of disk must never throw in history(): "..tostring(err))
  assert(latest.storageWarning and latest.storageWarning:find("LOW DISK",1,true),
    "disk full should warn and skip telemetry, not exit")
end

-- Operator settings must NOT claim successful save if disk cannot hold
-- the temporary copy. Existing values remain in memory and on disk.
do
  local ctl=newController()
  mockCapacity=500
  local oldValue=ctl.getFluxReference()
  local savedBefore=mockFiles["/cc-mekanism/settings"]
  ctl.command("fluxplus")
  assert(ctl.getFluxReference()==oldValue,"unsaved FE limit must revert")
  assert(ctl.getInfo():find("NOT SAVED",1,true),"visible disk warning")
  assert(mockFiles["/cc-mekanism/settings"]==savedBefore,
    "settings file must remain intact on save failure")
end

-- Real 2026-10-24 turbine: Mekanism DUMPING_EXCESS retains 90%,
-- so 82-90% steam climb is not an emergency or protection cooldown.
do
  local ctl=newController(true) -- ACTUAL deployed packed payload + RAM patch
  local t=sample()
  t.dumpExcess=true
  t.steam=0.834
  t.steamTrend=0.00433 -- screenshot: 26 percentage points per minute
  t.fuelCapFresh=false;t.fuelCap=nil
  t.fuelFillForControl=1;t.fuelRapidNet=0;t.fuelRapidProduction=400
  local out=ctl.exerciseSPS(t)
  assert(t.steamPressureState=="OK",
    "83.4% + 26%/min below 90% dump keep target is NORMAL")
  assert(not out.limit:find("STEAM",1,true),
    "AUTO should not pause simply while filling to dump keep level: "..out.limit)
  assert(burnRate>=400,"do not unnecessarily throttle antimatter production")
end
do
  local ctl=newController(true)
  local t=sample()
  t.dumpExcess=true;t.steam=0.905;t.steamTrend=0.006
  t.fuelCapFresh=false;t.fuelCap=nil
  local result=ctl.exerciseSPS(t)
  assert(t.steamPressureState=="OK",
    "90.5% temporary overshoot remains below 93% pressure guard")
  assert(burnRate>=400)
end
do
  local ctl=newController(true)
  local t=sample()
  t.dumpExcess=true;t.steam=0.935;t.steamTrend=0.002
  t.fuelCapFresh=false;t.fuelCap=nil
  local result=ctl.exerciseSPS(t)
  assert(t.steamPressureState=="HOLD",
    "growing buffer above 93% is an early pressure warning")
  near(burnRate,400,0.01,"hold at 93.5%, no immediate cut")
  assert(result.limit:find("STEAM BUFFER GROWING",1,true))
end
do
  local ctl=newController(true)
  local t=sample()
  t.dumpExcess=true;t.steam=0.96;t.steamTrend=0
  t.fuelCapFresh=false;t.fuelCap=nil
  local result=ctl.exerciseSPS(t)
  assert(t.steamPressureState=="TRIM")
  near(burnRate,382,0.01,"above 95.5% dumping steam trim 4.5%")
end
do
  local ctl=newController(true)
  local t=sample()
  t.dumpExcess=true;t.steam=0.978;t.steamTrend=0
  t.fuelCapFresh=false;t.fuelCap=nil
  ctl.exerciseSPS(t)
  assert(t.steamPressureState=="TRIM_FAST")
  near(burnRate,360,0.01,"97.8% actively reduce burn")
end
do
  local ctl=newController(true)
  data.turbine.getDumpingMode="DUMPING_EXCESS"
  data.turbine.getSteamFilledPercentage=0.96
  local t=ctl.read()
  assert(t.dumpExcess==true and t.steamTripEffective==0.985)
  assert(ctl.safety(t)==true,
    "with Dumping Excess, 96% alone is NOT immediate reactor SCRAM")
  data.turbine.getSteamFilledPercentage=0.985
  local t2=ctl.read()
  local okay,why=ctl.safety(t2)
  assert(okay==false and why:find("turbine steam",1,true),
    "98.5% with Dumping Excess remains a reactor SCRAM condition")
  data.turbine.getDumpingMode="IDLE"
  data.turbine.getSteamFilledPercentage=0.95
  local t3=ctl.read()
  assert(t3.steamTripEffective==0.95,
    "IDLE turbine retains conservative 95% SCRAM")
  data.turbine.getSteamFilledPercentage=0.1
end
print("controller headless scenarios: OK")
