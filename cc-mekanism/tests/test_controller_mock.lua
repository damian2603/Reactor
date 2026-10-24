-- Headless runtime smoke tests for the actual controller.lua, no Minecraft required.
CC_MEKANISM_TEST=true
local epochMs=1000000
os.epoch=function() return epochMs end
local originalDofile=dofile
dofile=function(path)
  if path=="/cc-mekanism/optimizer_math.lua" then
    return originalDofile("cc-mekanism/optimizer_math.lua")
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
    getBoilEfficiency=1
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
fs={}
function fs.exists(p) return p=="/cc-mekanism" end
function fs.makeDir() end
function fs.open()
  return {write=function() end,writeLine=function() end,close=function() end}
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
local function newController()
  active=true
  calls={}
  epochMs=1000000
  burnRate=400
  return originalDofile("cc-mekanism/controller.lua")
end
local function sample()
  return {
    ts=1000,on=true,burn=400,actual=400,maxBurn=1000,
    temp=600,coolant=1,heated=0.1,waste=0.1,steam=0.1,
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
print("controller headless scenarios: OK")
