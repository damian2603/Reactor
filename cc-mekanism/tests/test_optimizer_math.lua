local m=dofile("cc-mekanism/optimizer_math.lua")
local function eq(a,b,label)
  assert(type(a)=="number" and math.abs(a-b)<1e-7,(label or "test").." expected "..b..", got "..tostring(a))
end
-- 0.039 AM/t requires 390 mB/t fissile burn at 10:1 and 1000:1.
eq(m.spsBurn(0.039,10,1000),390,"SPS feedforward")
eq(m.spsBurn(0,10,1000),0,"zero throughput")
-- The configured 16 MFE/t is a reference cap, NOT measured actual SPS FE.
eq(m.feBurnLimit(16000000,2.5,10,1000000,1.1),440,"manual FE bound")
-- Burn consumed 2000 mB in 100 ticks; tank gained 500 mB.
eq(m.fuelProduction(2000,500,100),25,"sustainable fuel supply")
-- Burn consumed 2000 mB; tank depleted 1500 mB.
eq(m.fuelProduction(2000,-1500,100),5,"fuel depletion limit")
eq(m.fuelProduction(0,-1000,100),0,"fuel source stopped")
assert(m.fuelProduction(100,20,0)==nil,"zero tick window invalid")
-- Buffer growing -> throttle, buffer falling -> raise burn.
assert(m.feedback(0.001,2000,20,10,0.5,390)<0)
assert(m.feedback(-0.001,2000,20,10,0.5,390)>0)
assert(m.feedback(0,2000,20,10,0.5,390)==0)
-- Bound correction to 10% so an unstable derivative cannot spike demand.
eq(m.feedback(-10,2000,20,10,0.5,390),39,"feedback bounded")
-- Screenshot follow-up: 525 mB/t requires 21 MFE/t at Mekanism defaults.
eq(m.feForBurn(525,2.5,10,1000000),21000000,"FE for 525 burn")
eq(m.feForAntimatter(0.0525,1000,1000000,2.5),21000000,
   "FE for 0.0525 antimatter")
do
  local f=m.assessFE({
    limitFE=20000000,neededFE=21000000,usedFE=19800000,
    poloniumFill=0.12,poloniumTrend=0.0002,
    outputFill=0.1,energyFill=0
  })
  assert(f.state=="FE_LIMIT_LIKELY","FE bottleneck from growing Polonium")
  eq(f.shortfallFE,1000000,"shortfall 1M")
  eq(f.trialFE,23000000,"target with 5 percent headroom")
  assert(f.confirmedDeliveryFE==false,"reference is NOT energy throughput meter")
end
do
  local f=m.assessFE({
    limitFE=20000000,neededFE=10000000,usedFE=9000000,
    poloniumFill=0.004,poloniumTrend=0,energyFill=0
  })
  assert(f.state=="REFERENCE_HEADROOM","capacity above demand is not wasted FE")
end
do
  local f=m.assessFE({
    limitFE=20000000,neededFE=16000000,usedFE=12000000,
    poloniumFill=0.40,poloniumTrend=0.0003,energyFill=0
  })
  assert(f.state=="SPS_INPUT_BACKLOG","warn about delivery despite adequate set limit")
end
-- At 500 burn and 20 MFE/t we are balanced now, but 1920 possible
-- by reactor/Solar hardware. A higher FE limit may unlock more AM,
-- conditional on production of enough Fissile Fuel.
do
  local f=m.assessFE({
    limitFE=20000000,neededFE=20000000,usedFE=20000000,
    poloniumFill=0.02,poloniumTrend=0,
    opportunityFE=76800000,fuelVerified=false
  })
  assert(f.state=="FE_GROWTH_POSSIBLE",
    "should notice FE can be future throughput bottleneck")
  eq(f.trialFE,21000000,"next small +1M FE trial")
end
do
  local f=m.assessFE({
    limitFE=20000000,neededFE=20000000,usedFE=20000000,
    poloniumFill=0.02,poloniumTrend=0,
    opportunityFE=26000000,fuelVerified=true
  })
  assert(f.state=="FE_GROWTH_LIMIT","verified fuel supports higher target")
end
-- Not near the 20M FE boundary yet: raise burn first, not Flux Point.
do
  local f=m.assessFE({
    limitFE=20000000,neededFE=4900000,usedFE=4800000,
    poloniumFill=0.007,poloniumTrend=0,
    opportunityFE=76800000,fuelVerified=false
  })
  assert(f.state=="REFERENCE_HEADROOM",
    "at burn 123 and 20M FE, unused FE capacity is not waste")
end
print("optimizer math tests: OK")
