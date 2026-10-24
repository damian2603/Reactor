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
local v=base();v.coolant=0.72;v.ts=12
local older=base();older.ts=10;older.coolant=1
local healthy,why=core.safety(v,older,settings)
assert(not healthy and why=='COOLANT RAPID LOSS',
  "rapid loss to 72% coolant must trigger RPS")
-- In the user's live world, coolant repeatedly dropped to ~92.8%.
-- The independent RPS must NOT trip on this normal water circulation.
local jitter=base();jitter.coolant=0.928;jitter.ts=10.5
older.ts=10;older.coolant=1
assert(core.safety(jitter,older,settings)==true,
  "one-tick circulation to 92.8% must not trigger SCRAM")
jitter.coolant=0.90;jitter.ts=10.7
assert(core.safety(jitter,older,settings)==true,
  "one-tick 10% coolant dip must not be mistaken for a meltdown")
local missing=base();missing.coolant=nil
assert(not core.safety(missing,nil,settings))
local opt=core.new(settings)
opt:observe(t)
local first=opt:decide(t)
assert(first.target==401,'normal AUTO should ramp exactly +1 mB/t')
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
  local burn,stored,cap=400,200000,200000
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
  'fuel estimate='..tostring(out[#out].fuelEstimate)..
  ' burn='..tostring(out[#out].burn)..
  ' fuelStored='..tostring(out[#out].stored)..
  ' expected production ~500')
local outHigh=simulate(600,170)
assert(outHigh[#outHigh].burn>535,'surplus fuel allows max SPS/FE burn')
local outLow=simulate(430,210)
close(outLow[#outLow].burn,430,12,'low supply; estimated '..
  tostring(outLow[#outLow].fuelEstimate)..' stored '..
  tostring(outLow[#outLow].stored)..' net '..
  tostring(outLow[#outLow].fuelNet)..' reason '..
  tostring(outLow[#outLow].reason))
-- Real Elite Chemical Tank screenshot: 1,023,465 / 1,024,000 mB.
-- Remaining gap 535 mB is near one tick of ~535 burn. These
-- stationary per-burn oscillations cannot reveal maximum centrifuge
-- output and MUST NOT accidentally become a hard 535 mB/t fuel cap.
do
  local near=core.new(settings)
  local capacity=1024000
  local first=base()
  first.maxBurn=1920
  first.burn=535;first.actual=535
  first.fuelCapacity=capacity
  first.amRate=0.0535
  for i=1,30 do
    local t={}
    for k,v in pairs(first) do t[k]=v end
    t.ts=100+i*5
    local ripple=({-36,0,27,48,-15})[(i-1)%5+1]
    t.fuelAmount=capacity-535+ripple
    near:observe(t)
    local d=near:decide(t)
    assert(t.fuelNearFull and t.fuelMissing>=487 and t.fuelMissing<=571,
      "near-full 535 mB cyclic gap must be recognized")
    assert(t.fuelEstimate==nil,
      "constant saturated tank NEVER proves exact maximum fissile output")
    if i>=7 then
      assert(t.fuelStatus=="NEAR FULL: BURN SUPPORTED, MAX UNKNOWN",
        "oscillations should NOT be called sustained deficit: "..tostring(t.fuelStatus))
      assert(t.fuelSupplyFloor and t.fuelSupplyFloor>532,
        "stable buffer proves at least approximately current consumption")
      assert(d.target>=535,"do not throttle because tank has a 535 mB cyclic gap")
    end
  end
end
-- 104 actual historical CSV rows from the Project Infinity Elite tank:
-- every sample (including +-66 mB/t control swings) satisfies
-- amount=1,024,000-actualBurn exactly. Observing this SHOULD cancel
-- the apparent fuel drift and eliminate false fuel supply estimates.
do
  local controlReplay=core.new(core.defaults({userCap=575,fluxFE=25000000}))
  local burns={546,546,550,550,550,550,550,550,550,550,550,550,550,550,534,570,556,530,566,540,564,511,535,571,557,531,567,541,575,511,547,571,557,543,567,541,575,511,547,533,557,543,567,541,575,511,547,533,557,543,567,553,537,523,547,533,557,543,567,553,537,523,547,533,557,543,567,553,499,523,547,533,569,543,529,553,499,523,547,533,569,555,529,553,537,535,559,545,569,555,529,565,499,535,559,545,531,555,541,565,511,535,559,545}
  local coolant={1000,1000,1000,1000,1000,1000,1000,1000,1000,1000,1000,1000,1000,1000,1000,943,995,1000,976,1000,952,1000,1000,946,995,1000,978,1000,928,1000,1000,946,988,1000,960,1000,928,1000,1000,969,988,1000,960,1000,929,1000,1000,999,983,1000,942,999,949,1000,1000,998,982,1000,943,1000,949,1000,1000,998,983,1000,942,1000,1000,1000,1000,1000,961,1000,976,1000,1000,1000,1000,1000,962,997,1000,1000,1000,970,984,1000,946,997,1000,986,1000,1000,982,1000,972,995,1000,971,1000,1000,972,1000}
  assert(#burns==104 and #coolant==104)
  local low=0
  for i=1,#burns do
    local v=base()
    v.ts=1000+i*15
    v.burn=burns[i];v.actual=burns[i];v.fuelCapacity=1024000
    v.fuelAmount=1024000-v.burn
    v.coolant=coolant[i]/1000
    v.temperature=373.15+2e6*v.actual/v.heatCapacity
    v.amRate=v.actual/10000
    assert(core.safety(v,nil,controlReplay.cfg),"real measured coolant must be safe")
    controlReplay:observe(v)
    local d=controlReplay:decide(v)
    if i>=9 then
      assert(v.fuelTickGapCompensated==true,
        "detect one-tick transport gap from real historical CSV")
      assert(v.fuelNet==0,
        "tank=capacity-burn means zero REAL net fuel drift; got "..
        tostring(v.fuelNet).." at sample "..i)
      assert(v.fuelEstimate==nil,
        "fully saturated one-tick tank snapshots must not invent production ceiling")
      assert(d.reason~="REACTOR COOLANT/OUTPUT BACKPRESSURE" and
        d.reason~="COOLANT SUSTAINED LOW - GENTLE TRIM",
        "temporary 92.8-100% coolant is not failed cooling")
    end
    if d.target<v.burn-0.01 then
      low=low+1
      assert(v.burn-d.target<=2.01,
        "normal trim cannot jump 38-66mB/t anymore")
    end
  end
  assert(low<40,"should not repeatedly throttle ordinary coolant oscillations")
end
do
  local cfg=core.defaults({userCap=575,fluxFE=25000000})
  local ctl=core.new(cfg)
  local t=base()
  t.burn=555;t.actual=555;t.temperature=1012.5
  for i=1,15 do
    t.ts=2000+i*2;t.coolant=(i%3==0) and .928 or 1.0
    ctl:observe(t)
    local d=ctl:decide(t)
    assert(d.target>=t.burn,
      "repeated 92.8% coolant dips should not trim healthy reactor")
    t.burn=d.target;t.actual=d.target
    t.temperature=373.15+2e6*t.actual/t.heatCapacity
  end
  -- Sustained coolant shortage should HOLD first, then trim gradually.
  local sawHold=false
  local sawTrim=false
  for i=1,12 do
    t.ts=t.ts+2;t.coolant=.875
    ctl:observe(t)
    local d=ctl:decide(t)
    if d.reason=="COOLANT DIPPING - OBSERVE BEFORE TRIM" then sawHold=true end
    if d.reason=="COOLANT SUSTAINED LOW - GENTLE TRIM" then
      sawTrim=true;assert(t.burn-d.target<=2.01,"coolant trim too abrupt")
    end
    t.burn=d.target;t.actual=d.target
    t.temperature=373.15+2e6*t.actual/t.heatCapacity
  end
  assert(sawHold and sawTrim,"low coolant needs persistence then gentle trim")
end
-- Once burn outruns the real fuel supply, the corrected tank MUST
-- begin drifting below nominal 100%, and the optimizer must eventually
-- recognize lower Fissile Fuel production despite the 1-tick pipeline gap.
do
  local cfg=core.defaults({userCap=575,fluxFE=25000000})
  local ctl=core.new(cfg)
  local tankCap=1024000
  local deficit=0
  local burn=560
  local calibrated=false
  local corrected=false
  for i=1,105 do
    local v=base()
    v.ts=3000+i*2
    v.burn=burn;v.actual=burn;v.maxBurn=1920
    v.coolant=1;v.heated=0;v.waste=0
    v.temperature=373.15+2e6*burn/v.heatCapacity
    v.fuelCapacity=tankCap
    v.fuelAmount=tankCap-burn-deficit
    v.amRate=burn/10000
    ctl:observe(v)
    if v.fuelTickGapCompensated then corrected=true end
    local decision=ctl:decide(v)
    if i>12 and v.fuelEstimate and math.abs(v.fuelEstimate-520)<4 then
      calibrated=true
    end
    if i>12 then
      burn=decision.target
      deficit=math.max(0,deficit+(burn-520)*20*2)
    end
  end
  assert(corrected,"one tick transport compensation locks before shortage")
  assert(calibrated,"actual 520 mB/t fuel production becomes measurable after deficit")
  assert(ctl.fuelEstimate and math.abs(ctl.fuelEstimate-520)<6,
    "corrected fuel production must remain stable near 520mB/t")
end
-- Existing users who saved FE or burn cap on the touchscreen still
-- have all of the OLD defaults serialized in cc-antimatter/settings.
-- Verify one-time migration to quiet tuning without losing the user CAP.
do
  local upgraded=core.defaults({
    userCap=575,fluxFE=24000000,coolantWarn=0.95,
    rampStep=12,downwardStep=38,changeIntervalSeconds=6
  })
  assert(upgraded.legacyControllerMigrated==true,
    "legacy settings with old oscillating defaults should migrate")
  assert(upgraded.userCap==575 and upgraded.fluxFE==24000000,
    "keep manually edited operator limits")
  assert(upgraded.rampStep==1 and upgraded.downwardStep==2 and
    upgraded.changeIntervalSeconds==2 and upgraded.coolantWarn==0.88,
    "replace +12/-38 and 95% aggressive cooldown defaults")
  local custom=core.defaults({
    userCap=575,rampStep=0.5,downwardStep=1,
    changeIntervalSeconds=3,coolantWarn=0.91
  })
  assert(custom.rampStep==0.5 and custom.downwardStep==1 and
    custom.coolantWarn==0.91 and not custom.legacyControllerMigrated,
    "do not silently change custom tuning")
end
-- Operator verified sustainable closed water circuit at burn 552.06.
-- Even if Fissile Fuel production/SPS allow more, avoid needlessly
-- consuming makeup water. This is independent of turbine steam SCRAM.
do
  local cfg=core.defaults({userCap=575,fluxFE=22000000})
  assert(cfg.waterLoopEnabled==1 and cfg.waterLoopCap==552.06)
  local c=core.new(cfg)
  local stable=base()
  stable.ts=5000; stable.burn=552.06; stable.actual=552.06
  stable.temperature=373.15+stable.actual*2000000/stable.heatCapacity
  stable.turbineSteam=0.99999728 -- hypothetical 258,943,296 / 258,944,000
  stable.amRate=0.055
  assert(core.safety(stable,nil,cfg),
    'turbine nearly full is not by itself a reactor damage condition')
  c:observe(stable)
  local atBalance=c:decide(stable)
  close(atBalance.cap,552.06,0.001,'calibrated water-return upper bound')
  close(atBalance.target,552.06,0.001,'stable water loop should hold burn')
  close(atBalance.caps.RECIRCULATED_WATER,552.06,0.001,
    'show actual tested water cap separately')
  local above=base()
  above.ts=5002;above.burn=566;above.actual=566
  above.temperature=373.15+566*2000000/above.heatCapacity
  c:observe(above)
  local down=c:decide(above)
  assert(down.target<566 and down.target>552,
    'reduce gracefully to observed max, not emergency SCRAM')
  assert(down.cap<=552.061)
end
do
  local cfg=core.defaults({userCap=575,waterLoopEnabled=0,fluxFE=22000000})
  local c=core.new(cfg)
  local t=base();t.burn=555;t.actual=555
  t.temperature=373.15+t.actual*2000000/t.heatCapacity
  c:observe(t)
  local d=c:decide(t)
  assert(d.cap>552.06,
    'operator may explicitly disable site-specific water-return cap')
  assert(d.caps.RECIRCULATED_WATER==nil)
end
print('antimatter v1 controller model regressions: OK')
