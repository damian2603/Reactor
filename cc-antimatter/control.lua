-- Project Infinity ANTImatter Controller v1: pure model, no CC peripherals.
-- Measurements are actual Mekanism rates and amounts. Model never starts reactor.
local M={}
local abs,min,max=math.abs,math.min,math.max
local function valid(x) return type(x)=="number" and x==x and x~=math.huge and x~=-math.huge end
local function bound(x,a,b) return max(a,min(x,b)) end
local DEFAULT={
  userCap=550, fluxFE=22000000, ticksPerSecond=20,
  softTemperature=1080, scramTemperature=1135, thermalMargin=0.985,
  coolantWarn=0.95, coolantTrip=0.65, heatedWarn=0.55, heatedTrip=0.88,
  wasteWarn=0.65, wasteTrip=0.91,
  sampleMinSeconds=18, sampleLongSeconds=95, fuelMargin=0.4,
  changeIntervalSeconds=6, rampStep=12, downwardStep=38,
  minimumBurn=0.01, spsFull=0.90, spsLow=0.035,
  spsPlateauWindow=70, spsPlateauDelta=0.008,
  solarUtilization=0.95, feHeadroom=1.04
}
local function defaults(o)
  local c={};for k,v in pairs(DEFAULT) do c[k]=v end
  if o then for k,v in pairs(o) do if c[k]~=nil and valid(v) then c[k]=v end end end
  c.softTemperature=bound(c.softTemperature,950,1100)
  c.scramTemperature=bound(c.scramTemperature,1050,1150)
  c.userCap=max(1,c.userCap);c.fluxFE=max(1000000,c.fluxFE)
  c.ticksPerSecond=bound(c.ticksPerSecond,5,20)
  return c
end
M.defaults=defaults
M.MIN_REQUIRED={"on","formed","temperature","damage","coolant","heated","waste"}

-- Direct safety independent from optimizing. Turbine steam fill is NEVER a trip.
function M.safety(t,prior,c)
  c=c or DEFAULT
  if type(t)~="table" then return false,"NO REACTOR TELEMETRY" end
  for _,k in ipairs(M.MIN_REQUIRED) do
    if t[k]==nil then return false,"SENSOR MISSING: "..k end
  end
  if not t.formed then return false,"FISSION REACTOR NOT FORMED" end
  if t.damage>0 then return false,"REACTOR DAMAGE OBSERVED" end
  if t.temperature>=min(c.scramTemperature,1150) then return false,"REACTOR TOO HOT" end
  if t.coolant<=c.coolantTrip then return false,"COOLANT CRITICAL" end
  if t.heated>=c.heatedTrip then return false,"HEATED COOLANT OUTLET BLOCKED" end
  if t.waste>=c.wasteTrip then return false,"NUCLEAR WASTE OUTLET BLOCKED" end
  if t.disabled==true then return false,"REACTOR DISABLED" end
  if prior and valid(prior.ts) and valid(t.ts) and t.ts-prior.ts>0.25 and t.ts-prior.ts<15 then
    local dt=t.ts-prior.ts
    if valid(prior.coolant) and (prior.coolant-t.coolant)/dt>0.022 and t.coolant<0.98 then
      return false,"COOLANT RAPID LOSS" end
    if valid(prior.temperature) and t.temperature>1090 and
      (t.temperature-prior.temperature)/dt>3 and
      t.temperature+(t.temperature-prior.temperature)/dt*8>min(c.scramTemperature,1150) then
      return false,"TEMPERATURE RUNAWAY" end
  end
  return true,"SAFE"
end
function M.thermalCap(t,c)
  c=c or DEFAULT
  if not(valid(t.heatCapacity) and t.heatCapacity>0) then return nil end
  local sodium=t.sodiumCoolant==true
  return max(0,(c.softTemperature-373.15)*t.heatCapacity/
    ((sodium and 1 or 2)*1000000)*c.thermalMargin)
end
function M.expectedTemp(t)
  if not(valid(t.heatCapacity) and t.heatCapacity>0 and valid(t.actual)) then return nil end
  return 373.15+(t.sodiumCoolant and 1 or 2)*1000000*t.actual/t.heatCapacity
end

local function addWindow(window,entry,seconds)
  window[#window+1]=entry
  while #window>2 and entry.ts-window[1].ts>seconds do table.remove(window,1) end
end
local function findWindow(window,seconds,now)
  if #window<2 then return nil end
  local earliest=nil
  for i=#window-1,1,-1 do
    if now-window[i].ts>=seconds then earliest=window[i];break end
  end
  return earliest
end
function M.new(config)
  local c=defaults(config)
  local self={cfg=c,fuel={},rates={},lastFuel=nil,consumed=0,
    fuelEstimate=nil,fuelSampleAge=0,baseline=nil,lastChange=-1e10,
    lastProbe=nil,plateau=false,plateauUntil=0,prev=nil,
    result={reason="INITIALIZING",target=0,cap=0}}
  function self:observe(t)
    local now=t.ts
    if not valid(now) then error("observe needs timestamp") end
    -- Integrate ACTUAL fuel use, never configured burn rate. This is
    -- necessary when the reactor runs out of fuel or controller ramps.
    if valid(t.actual) and self.lastFuel and valid(self.lastFuel.actual) then
      local dt=now-self.lastFuel.ts
      if dt>0 and dt<30 then
        self.consumed=self.consumed+(self.lastFuel.actual+t.actual)/2*dt*c.ticksPerSecond
      end
    end
    if valid(t.actual) then self.lastFuel={ts=now,actual=t.actual} end
    if valid(t.fuelAmount) and t.fuelAmount>=0 and valid(t.actual) then
      local fill=t.fuelCapacity and t.fuelCapacity>0 and t.fuelAmount/t.fuelCapacity or nil
      addWindow(self.fuel,{ts=now,amount=t.fuelAmount,consumed=self.consumed,fill=fill},150)
      local first=findWindow(self.fuel,c.sampleMinSeconds,now)
      if first then
        local dt=now-first.ts
        local ticks=dt*c.ticksPerSecond
        local delta=t.fuelAmount-first.amount
        t.fuelNet=delta/ticks
        t.fuelProduction=(self.consumed-first.consumed+delta)/ticks
        t.fuelWindowSeconds=dt
        -- An exactly full tank clips the incoming production rate. A tank
        -- that starts full and then DRAINS is still a useful measurement;
        -- fully saturated => production is at least actual, not exactly it.
        t.fuelCensored=fill and first.fill and
          (fill>=0.9985 or first.fill>=0.9985)
        -- Once BOTH readings are below the saturation band, even the
        -- 20s interval is a valid production measurement. This prevents
        -- the tank from refilling before a 95s window can complete.
        if not t.fuelCensored and t.fuelNet< -max(0.4,t.actual*0.001) and
            valid(t.fuelProduction) and t.fuelProduction>=0 then
          self.fuelEstimate=self.fuelEstimate and
            (self.fuelEstimate*0.80+t.fuelProduction*0.20) or
            t.fuelProduction
          self.fuelSampleAge=now
        end
      end
      -- Short window catches a serious fuel deficit quickly; long window
      -- measures sustainable production independent of setpoint ramps.
      -- Crucially: do NOT reuse the short-window 'first' for 95s calibration.
      local longStart=findWindow(self.fuel,c.sampleLongSeconds,now)
      if longStart then
        local longDt=now-longStart.ts
        local longTicks=longDt*c.ticksPerSecond
        local longFill=fill and longStart.fill and
          (fill>=0.9985 or longStart.fill>=0.9985)
        local produced=(self.consumed-longStart.consumed+
          t.fuelAmount-longStart.amount)/longTicks
        t.fuelLongWindow=longDt
        t.fuelLongCensored=longFill
        if not longFill and valid(produced) and produced>=0 then
          self.fuelEstimate=self.fuelEstimate and
            (self.fuelEstimate*0.75+produced*0.25) or produced
          self.fuelSampleAge=now
        end
      end
    end
    t.fuelEstimate=self.fuelEstimate
    -- Keep a rolling SPS rate history; do not use theoretical waste
    -- conversion as a stand-in for real Antimatter output.
    if valid(t.amRate) then
      addWindow(self.rates,{ts=now,rate=t.amRate,input=t.poloniumFill},180)
    end
    t.expectedTemp=M.expectedTemp(t)
    t.thermalCap=M.thermalCap(t,c)
    if t.temperature and t.expectedTemp then t.tempError=t.temperature-t.expectedTemp end
    if self.prev and t.ts>self.prev.ts then
      local dt=t.ts-self.prev.ts
      if dt>0 and dt<15 and valid(t.temperature) and valid(self.prev.temperature) then
        t.tempSlope=(t.temperature-self.prev.temperature)/dt
      end
    end
    self.prev=t
  end
  function self:decide(t)
    local now=t.ts
    local burn=valid(t.burn) and t.burn or 0
    local cap=min(c.userCap,valid(t.maxBurn) and t.maxBurn or c.userCap)
    local caps={USER=cap}
    local function limit(k,x) if valid(x) then caps[k]=x;cap=min(cap,x) end end
    limit("FE_REFERENCE",c.fluxFE/40000*c.feHeadroom)
    limit("THERMAL",t.thermalCap)
    if valid(t.solarRate) and valid(t.solarCount) and t.solarCount>0 then
      -- Solar output is polonium per tick; 10 waste => 1 polonium.
      limit("SNA",max(0.01,t.solarRate*10*c.solarUtilization))
    end
    -- 2.4% SPS Polonium can be entirely normal. No hard 8% minimum.
    if valid(t.amRate) and valid(t.poloniumFill) then
      if t.poloniumFill>=0.65 then
        limit("SPS_BUFFER",max(c.minimumBurn,t.amRate*10000+3))
      end
    end
    if valid(t.antimatterFill) and t.antimatterFill>=c.spsFull then
      limit("ANTIMATTER_OUTPUT",c.minimumBurn)
    end
    -- Censored full fuel tank never becomes an artificially low limit.
    local fuelFresh=self.fuelSampleAge>0 and now-self.fuelSampleAge<=190
    if fuelFresh and valid(self.fuelEstimate) then
      local allowance=max(0.5,c.fuelMargin)
      limit("FUEL_PRODUCTION",max(c.minimumBurn,self.fuelEstimate-allowance))
    end
    if valid(t.fuelNet) and valid(t.fuelProduction) and
       t.fuelNet< -max(1.0,burn*0.004) and
       valid(t.fuelWindowSeconds) and t.fuelWindowSeconds>=18 then
      if t.fuelCensored then
        -- At almost-full tank there is enough reserve to intentionally
        -- drain a little for calibration. DO NOT slash burn by 38 mB/t
        -- on every minor decline, otherwise we never learn true supply.
        local reserve=(valid(t.fuelAmount) and valid(t.fuelCapacity)) and
          max(0,t.fuelAmount-0.15*t.fuelCapacity) or 0
        local horizon=reserve/(-t.fuelNet*c.ticksPerSecond)
        if horizon<75 then
          limit("FUEL_RESERVE",max(c.minimumBurn,burn-c.downwardStep))
        end
      else
        limit("FUEL_DRAIN",max(c.minimumBurn,t.fuelProduction-0.5))
      end
    end
    local reason="SEEK FUEL/SPS LIMIT"
    -- A full turbine is not the same thing as a blocked reactor.
    -- React to actual reactor cooling/waste state instead.
    if not(valid(t.coolant) and valid(t.heated) and valid(t.waste) and valid(t.temperature)) then
      cap=min(cap,burn);reason="WAITING FOR REACTOR HEALTH SENSORS"
    elseif not t.thermalCap then
      cap=min(cap,burn);reason="HEAT CAPACITY UNKNOWN - HOLD"
    elseif t.coolant<c.coolantWarn or t.heated>c.heatedWarn or t.waste>c.wasteWarn then
      cap=min(cap,burn-c.downwardStep)
      reason="REACTOR COOLANT/OUTPUT BACKPRESSURE"
    elseif t.temperature>c.softTemperature or
      (t.expectedTemp and t.temperature>t.expectedTemp+60 and
       valid(t.tempSlope) and t.tempSlope>0.15) then
      cap=min(cap,burn-c.downwardStep)
      reason="REACTOR TEMPERATURE ABOVE MODEL"
    elseif valid(t.tempSlope) and t.temperature>1050 and t.tempSlope>1.0 then
      cap=min(cap,burn);reason="TEMPERATURE RISING - HOLD"
    end
    if valid(t.fuelAmount) and valid(t.fuelCapacity) and t.fuelCapacity>0 then
      local fill=t.fuelAmount/t.fuelCapacity
      if fill<0.05 and valid(t.fuelNet) and t.fuelNet<0 then
        cap=min(cap,max(c.minimumBurn,burn-c.downwardStep*2));reason="FUEL TANK NEAR EMPTY"
      end
    elseif not valid(t.reactorFuelAmount) then
      cap=min(cap,burn);reason="NO FISSILE FUEL INVENTORY - HOLD"
    end
    -- Stop wasting fissile fuel when solar conversion is truly absent.
    if t.solarCount==nil or t.solarUnknown and t.solarUnknown>0 then
      cap=min(cap,burn);reason="SOLAR TELEMETRY INCOMPLETE - HOLD"
    elseif t.solarCount==0 or t.solarWorking==0 then
      cap=min(cap,c.minimumBurn);reason="NO SOLAR POLONIUM CONVERSION"
    end
    -- SPS energy/transfer plateau: if AM did not improve after a controlled
    -- upward trial, yet Polonium is accumulating, reduce to useful demand.
    if self.lastProbe and now-self.lastProbe.ts>=c.spsPlateauWindow then
      local probe=self.lastProbe
      local gain=valid(t.amRate) and t.amRate-probe.amRate or 0
      local saturated=valid(t.poloniumFill) and valid(probe.input) and
        t.poloniumFill>probe.input+0.008 and t.poloniumFill>0.07
      if gain<c.spsPlateauDelta*max(0.001,probe.amRate) and saturated then
        self.plateau=true;self.plateauUntil=now+180
      else self.plateau=false end
      self.lastProbe=nil
    end
    if self.plateau and now<self.plateauUntil and valid(t.amRate) then
      limit("SPS_FE_PLATEAU",max(c.minimumBurn,t.amRate*10000+8))
      reason="SPS PLATEAU - SAVE FUEL"
    elseif self.plateau and now>=self.plateauUntil then self.plateau=false end
    cap=max(c.minimumBurn,cap)
    local interval=now-self.lastChange
    local target=burn
    if cap<burn-0.2 then
      target=max(cap,burn-c.downwardStep)
      reason=reason=="SEEK FUEL/SPS LIMIT" and "TRIM TO REAL LIMIT" or reason
      if cap<burn-70 then target=cap end -- cooling or severe fuel shortage
    elseif cap>burn+1 and interval>=c.changeIntervalSeconds then
      target=min(cap,burn+c.rampStep)
      if not self.lastProbe and valid(t.amRate) and t.poloniumFill and t.poloniumFill>0 then
        self.lastProbe={ts=now,amRate=t.amRate,input=t.poloniumFill,burn=burn}
      end
      reason="RAMP: TEST SPS + FISSILE FUEL"
    else
      reason=reason=="SEEK FUEL/SPS LIMIT" and "HOLD: NEAR OPTIMUM" or reason
    end
    target=bound(target,c.minimumBurn,valid(t.maxBurn) and t.maxBurn or cap)
    if abs(target-burn)>=0.2 then self.lastChange=now end
    local bottleneck="USER"
    for k,v in pairs(caps) do if abs(v-cap)<0.51 then bottleneck=k;break end end
    local result={target=target,cap=cap,caps=caps,reason=reason,
      bottleneck=bottleneck,fuelEstimate=t.fuelEstimate,fuelNet=t.fuelNet,
      thermalCap=t.thermalCap,amRate=t.amRate}
    self.result=result
    return result
  end
  return self
end
return M
