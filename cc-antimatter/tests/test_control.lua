local core=dofile('cc-antimatter/control.lua')
local function close(a,b,tol,msg)
  assert(type(a)=='number' and math.abs(a-b)<=(tol or 1),
    (msg or 'wrong value')..' expected '..tostring(b)..' got '..tostring(a))
end
local function base()
  return {ts=10,on=true,formed=true,burn=400,actual=400,maxBurn=1920,
    temperature=834,damage=0,coolant=1,heated=0,waste=0,
    heatCapacity=1736000,sodiumCoolant=false,
    amRate=.040,poloniumFill=.025,antimatterFill=.01,
    solarCount=6,solarWorking=6,solarUnknown=0,solarRate=280,
    fuelAmount=200000,fuelCapacity=200000,reactorFuelAmount=9000,
    turbineSteam=1.0}
end
local settings=core.defaults({userCap=550,fluxFE=22000000})
local t=base()
assert(core.safety(t,nil,settings),'full turbine must NOT trip reactor')
close(core.expectedTemp(t),834,2,'water reactor heat capacity model')
close(core.thermalCap(t,settings),604,3,'soft 1080 K thermal cap')
local failFields={
  {'damage',0.1,'REACTOR DAMAGE'}, {'coolant',0.65,'COOLANT CRITICAL'},
  {'heated',0.88,'HEATED COOLANT'}, {'waste',0.91,'NUCLEAR WASTE'},
  {'temperature',1135,'REACTOR TOO HOT'}
}
for _,case in ipairs(failFields) do
  local v=base();v[case[1]]=case[2]
  local healthy,why=core.safety(v,nil,settings)
  assert(not healthy and why:find(case[3],1,true),why)
end
local v=base();v.coolant=0.95;v.ts=12
local older=base();older.ts=10;older.coolant=1
local healthy,why=core.safety(v,older,settings)
assert(not healthy and why=='COOLANT RAPID LOSS')
local missing=base();missing.coolant=nil
assert(not core.safety(missing,nil,settings))
local opt=core.new(settings)
opt:observe(t)
local first=opt:decide(t)
assert(first.target>400 and first.target<=412,'ramp should be gradual')
local s=base();s.solarWorking=0
local night=core.new(settings);night:observe(s)
close(night:decide(s).target,.01,.001,'no solar conversion prevents fuel waste')
local clogged=base();clogged.poloniumFill=.8
local blocked=core.new(settings);blocked:observe(clogged)
assert(blocked:decide(clogged).cap<=405,'polonium full means save fuel')
local manualMissing=base();manualMissing.fuelAmount=nil;manualMissing.reactorFuelAmount=nil
local absent=core.new(settings);absent:observe(manualMissing)
close(absent:decide(manualMissing).target,400,0.01,'fuel inventory missing holds')

-- Simulate hours of tank output at 500mB/t, starting absolutely full.
-- This exercises censored full-tank detection, slow fuel integration across
-- many setpoint changes, and anti-starvation feedback without a reset.
local function simulate(produced,steps)
  local ctrl=core.new(settings)
  local burn=400,stored=200000,cap=200000
  local highs=0
  local outputs={}
  for i=1,steps do
    local secs=5
    local now=i*secs+1000
    local act=burn
    stored=math.max(0,math.min(cap,stored+(produced-act)*20*secs))
    local rate=math.min(.055,act/10000)
    local sim={ts=now,on=true,formed=true,burn=burn,actual=act,
      maxBurn=1920,temperature=373.15+act*2000000/1736000,
      heatCapacity=1736000,damage=0,coolant=1,heated=0,waste=0,
      fuelAmount=stored,fuelCapacity=cap,reactorFuelAmount=10000,
      solarCount=6,solarWorking=6,solarUnknown=0,solarRate=280,
      amRate=rate,poloniumFill=.025,antimatterFill=.01,turbineSteam=.99}
    assert(core.safety(sim,nil,settings),'full turbine is not fission danger')
    ctrl:observe(sim)
    local decision=ctrl:decide(sim)
    assert(decision.target>=0.01 and decision.target<=550.01)
    if decision.target>500 then highs=highs+1 end
    burn=decision.target
    outputs[i]={burn=burn,fuelEstimate=sim.fuelEstimate,
      fuelCensored=sim.fuelCensored,fuelNet=sim.fuelNet,stored=stored,
      reason=decision.reason}
  end
  return outputs,highs
end
local out,highs=simulate(500,125)
assert(highs>0,'must probe past unknown fuel production to discover limit')
close(out[#out].burn,500,9,'should converge close to actual fuel supply')
assert(out[#out].fuelEstimate and out[#out].fuelEstimate>490 and out[#out].fuelEstimate<510,
  'must estimate production using tank derivative and actual consumption')
local outHigh=simulate(600,70)
assert(outHigh[#outHigh].burn>535,'surplus fuel allows max SPS/FE burn')
local outLow=simulate(430,135)
close(outLow[#outLow].burn,430,12,'lower fuel supply must constrain reactor')
print('antimatter v1 controller model regressions: OK')
