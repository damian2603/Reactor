-- Headless ComputerCraft peripheral smoke test for the completely new runtime.
local originalDofile=dofile
ANTIMATTER_UNIT_TEST=true
os.epoch=function() return 1000000 end
fs={exists=function() return false end}
parallel={waitForAll=function(...) for _,fn in ipairs({...}) do fn() end end}
local scrams,commands=0,{}
local data={
  fission_0={getActualBurnRate=500,getBurnRate=500,setBurnRate=function(v)commands[#commands+1]=v end,
    scram=function()scrams=scrams+1 end,getTemperature=950,isFormed=true,getStatus=true,
    getMaxBurnRate=1920,getDamagePercent=0,getCoolantFilledPercentage=1,
    getHeatedCoolantFilledPercentage=0,getWasteFilledPercentage=0,getHeatCapacity=1736000,
    getFuel={name='mekanism:fissile_fuel',amount=8000},getFuelCapacity=9000,
    getCoolant={name='minecraft:water',amount=10000},getHeatingRate=500000,
    isForceDisabled=false},
  sps_0={getProcessRate=.05,getInputFilledPercentage=.025,getOutputFilledPercentage=.01,
    isFormed=true,getInput=40,getOutput=1},
  tank_fuel={getStored={name='mekanism:fissile_fuel',amount=200000},getCapacity=200000},
  tank_other={getStored={name='mekanism:hydrogen',amount=180000},getCapacity=200000},
  turbine_0={getDumpingMode='DUMPING_EXCESS',getSteamFilledPercentage=1.0,
    getFlowRate=0,getMaxFlowRate=100000,getEnergyFilledPercentage=1.0},
  sna_1={canSeeSun=true,getProductionRate=140},
  sna_2={canSeeSun=true,getProductionRate=140}
}
peripheral={}
function peripheral.getNames() return {'fission_0','sps_0','tank_fuel','tank_other',
  'turbine_0','sna_1','sna_2'} end
function peripheral.getMethods(name)
  local methods={}
  for method in pairs(data[name]) do methods[#methods+1]=method end
  return methods
end
function peripheral.call(name,method,...)
  assert(data[name] and data[name][method]~=nil,'unknown '..tostring(name)..'.'..method)
  local value=data[name][method]
  return type(value)=='function' and value(...) or value
end
dofile=function(path)
  if path=='/cc-antimatter/control.lua' then
    return originalDofile('cc-antimatter/control.lua')
  end
  return originalDofile(path)
end
local app=originalDofile('cc-antimatter/main.lua')
assert(app.state.mode=='MANUAL','never auto mode on boot')
assert(scrams==0 and #commands==0,'must not start or SCRAM at import')
app.discover()
assert(app.peripherals.reactor=='fission_0')
assert(app.peripherals.sps=='sps_0')
assert(app.peripherals.fuelTank=='tank_fuel','select Fissile Fuel among 2 tanks')
assert(app.peripherals.turbine=='turbine_0')
assert(#app.peripherals.solar==2)
local t=app.sample()
assert(t.fuelAmount==200000 and t.fuelCapacity==200000)
assert(t.fuelIsWrongGas==false)
assert(t.amRate==.05 and t.poloniumFill==.025)
assert(t.solarCount==2 and t.solarWorking==2 and t.solarRate==280)
assert(t.turbineSteam==1.0 and app.safety(t,nil,app.config),
  '100% turbine is not a reason to SCRAM healthy fission reactor')
assert(app.safety(app.fastSafety(),nil,app.config))
assert(app.setBurn(540))
assert(commands[#commands]==540,'setBurn actually targets correct fission reactor')
assert(scrams==0,'no spurious SCRAM from turbine')
app.emergency('simulated loss of cooling')
assert(scrams==1 and app.state.latched and app.state.mode=='MANUAL')
ANTIMATTER_UNIT_TEST=nil
print('antimatter runtime peripheral discovery and safe startup: OK')
