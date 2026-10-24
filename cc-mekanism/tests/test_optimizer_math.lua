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
print("optimizer math tests: OK")
