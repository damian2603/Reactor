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
print("controller headless scenarios: OK")
