local m=dofile("cc-mekanism/thermal_model.lua")
local function near(value,expected,tolerance,label)
  assert(type(value)=="number" and math.abs(value-expected)<=tolerance,
    (label or "numeric").." expected "..tostring(expected)..
    " got "..tostring(value))
end
local CAP=1736000 -- 18x18x18 shell: (5832-4096) * 1000
near(m.expected(448,CAP,false),889.279032258,0.02,
  "screenshot 448mB/t => 889K")
near(m.expected(540,CAP,false),995.269815668,0.02,
  "manual 540 mB/t => ~995K")
near(m.expected(650,CAP,false),1121.997,0.25,"650 mB/t")
near(m.expected(540,CAP,true),684.209908,0.02,"sodium cooling")
near(m.thermalCap(CAP,false,1100,0.98),618.276504,0.5,
  "max recommended burn for ~1100K water")
near(m.thermalCap(CAP,true,1100,0.98),1236.553,1,
  "sodium capacity approx twice water at same heat capacity")
assert(m.expected(448,nil,false)==nil,"invalid heat capacity")
assert(m.thermalCap(nil,false,1100,0.98)==nil,
  "do not claim modelled safety without getHeatCapacity")
local function state(o) return m.assess(o).state end
local base={heatCapacity=CAP,trip=1150,warn=1100,isSodium=false}
local function with(o)
  local t={}
  for k,v in pairs(base) do t[k]=v end
  for k,v in pairs(o) do t[k]=v end
  return t
end
assert(state(with({burn=448,temp=889.6,trend=0}))=="OK",
  "889.6K at 448mB/t is normal")
assert(state(with({burn=540,temp=995,trend=0}))=="OK",
  "540mB/t must not be throttled at steady expected 995K")
assert(state(with({burn=400,temp=850,trend=0}))=="OK",
  "legacy 850K must not trigger a cut")
assert(state(with({burn=650,temp=1110,trend=0}))=="TRIM",
  "above thermal warning trim gradually")
assert(state(with({burn=650,temp=1140,trend=0}))=="TRIM_FAST",
  "near absolute SCRAM urgent trim")
assert(state(with({burn=650,temp=1150,trend=0}))=="TRIP",
  "software trip before Mekanism 1200K damage")
assert(state(with({burn=400,temp=1000,trend=0.3}))=="TRIM",
  "measured hotter than predicted and rising indicates broken cooling")
assert(state(with({burn=400,temp=995,trend=-0.3}))=="OK",
  "temperature falling after reducing burn is not a new overheat")
assert(state(with({burn=520,temp=1040,trend=2.4}))=="TRIM_FAST" or
  state(with({burn=520,temp=1040,trend=2.4}))=="HOLD",
  "rapidly rising reactor temp must pause or cut")
assert(state(with({burn=540,temp=995,trend=5}))=="HOLD" or
  state(with({burn=540,temp=995,trend=5}))=="TRIM_FAST",
  "dangerous future temp warrants pause despite normal instant temp")
local unknown=m.assess({temp=900,burn=540})
assert(unknown.state=="OK" and unknown.expected==nil,
  "no heat capacity -> no predictive model, independent temperature safety remains")
print("thermal model tests: OK")
