-- Project Infinity ANTImatter Controller v1: pure model, no CC peripherals.
-- Measurements are actual Mekanism rates and amounts. Model never starts reactor.
local M={}
local abs,min,max=math.abs,math.min,math.max
local function valid(x) return type(x)=="number" and x==x and x~=math.huge and x~=-math.huge end
local function bound(x,a,b) return max(a,min(x,b)) end
local DEFAULT={
  userCap=550, fluxFE=22000000, ticksPerSecond=20,
  softTemperature=1080, scramTemperature=1135, thermalMargin=0.985,
  -- 93-95% coolant is a normal transient on this reactor, per 104 logged
  -- readings; hold below 92% if persistent, trim below 88%, fast trim 80%.
  coolantWarn=0.88, coolantHold=0.92, coolantReset=0.97,
  coolantHoldSeconds=8, coolantTrimSeconds=10,
  coolantRecoverySeconds=8, coolantFastTrim=0.80,
  coolantTrip=0.65, heatedWarn=0.55, heatedTrip=0.88,
  wasteWarn=0.65, wasteTrip=0.91,
  sampleMinSeconds=18, sampleLongSeconds=95, fuelMargin=0.4,
  -- Small actuator steps avoid the old 575 -> 537 -> 561 hunting cycle.
  changeIntervalSeconds=2, rampStep=1, downwardStep=2,
  thermalDownwardStep=5, emergencyDownwardStep=12,
  minimumBurn=0.01, spsFull=0.90, spsLow=0.035,
  spsPlateauWindow=70, spsPlateauDelta=0.008,
  solarUtilization=0.95, feHeadroom=1.04
}
local function defaults(o)
  local c={};for k,v in pairs(DEFAULT) do c[k]=v end
  if o then for k,v in pairs(o) do if c[k]~=nil and valid(v) then c[k]=v end end end
  -- Older v1 saved ALL defaults whenever FE / CAP was edited on the
  -- monitor. Without this migration its persisted +12/-38 and 95%
  -- coolant warning would OVERRIDE the new smooth code on upgrade.
  -- Match the *entire* legacy group so intentionally customized tuning
  -- is left untouched; retain userCap, fluxFE, peripheral names, etc.
  if o and o.rampStep==12 and o.downwardStep==38 and
      o.changeIntervalSeconds==6 and o.coolantWarn==0.95 then
    c.rampStep=1
    c.downwardStep=2
    c.changeIntervalSeconds=2
    c.coolantWarn=0.88
    c.legacyControllerMigrated=true
  end
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
    -- A *fast* 7-10% cooling-tank change near 100% can be normal
    -- Mekanism flow timing; the 104 real samples repeatedly show ~93%
    -- without heated-coolant buildup or rising reactor heat. Do not
    -- confuse transport jitter with a dangerous wholesale loss.
    -- Rapid-loss SCRAM requires coolant already below 80%, or the
    -- independent absolute trip at 65% is reached.
    if valid(prior.coolant) and t.coolant<0.80 and
        (prior.coolant-t.coolant)/dt>0.035 then
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
    tickGapSamples=0,tickGapCompensation=false,
    coolantLowSince=nil,coolantRecoverUntil=0,
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
      t.fuelFill=fill
      t.fuelMissing=t.fuelCapacity and max(0,t.fuelCapacity-t.fuelAmount) or nil
      t.fuelNearFull=fill~=nil and fill>=0.995
      -- Real 104-row history: tank=1024000-actualBurn exactly EVERY row.
      -- This is a persistent 1-tick transport gap, NOT an upstream shortage.
      -- Lock on only after several corroborating snapshots, so a different
      -- tank layout does not get an unjustified correction from one sample.
      t.fuelGap=t.fuelCapacity and t.fuelCapacity-t.fuelAmount or nil
      local tickGap=t.fuelNearFull and valid(t.actual) and
        valid(t.fuelGap) and abs(t.fuelGap-t.actual)<=max(5,t.actual*0.01)
      if tickGap then
        self.tickGapSamples=min(20,self.tickGapSamples+1)
      elseif not self.tickGapCompensation then
        self.tickGapSamples=max(0,self.tickGapSamples-2)
      end
      if not self.tickGapCompensation and self.tickGapSamples>=5 then
        self.tickGapCompensation=true
        -- Never mix pre-compensation raw samples with corrected samples:
        -- doing so would create artificial positive/negative fuel trends.
        self.fuel={}
      end
      t.fuelTickGapCompensated=self.tickGapCompensation
      local effective=t.fuelAmount
      if self.tickGapCompensation and valid(t.actual) then
        -- Accumulated shortage is the part of tank depletion BEYOND one
        -- burn tick. This value remains full at healthy 500-575 mB/t.
        effective=min(t.fuelCapacity,t.fuelAmount+t.actual)
      end
      t.fuelEffective=effective
      fill= t.fuelCapacity and t.fuelCapacity>0 and effective/t.fuelCapacity or nil
      t.fuelNearFull=fill~=nil and fill>=0.995
      -- Saturation hides additional fuel supply, thus is lower-bound only.
      addWindow(self.fuel,{ts=now,amount=effective,consumed=self.consumed,fill=fill},150)
      local first=findWindow(self.fuel,c.sampleMinSeconds,now)
      if first then
        local dt=now-first.ts
        local ticks=dt*c.ticksPerSecond
        local delta=effective-first.amount
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
          effective-longStart.amount)/longTicks
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
    local jitter=max(1,valid(t.actual) and t.actual*0.004 or 1)
    if not valid(t.fuelAmount) or not valid(t.fuelCapacity) then
      t.fuelStatus="TANK READ UNAVAILABLE"
    elseif t.fuelNearFull and not valid(t.fuelNet) then
      t.fuelStatus="NEAR FULL: WAITING FOR FUEL TREND"
    elseif t.fuelNearFull and valid(t.fuelNet) and
        math.abs(t.fuelNet)<=jitter then
      -- This demonstrates current demand is being met, NOT the maximum
      -- production of the upstream Isotopic Centrifuge line.
      t.fuelStatus=self.tickGapCompensation and
        "1-TICK GAP: BURN SUPPORTED, MAX UNKNOWN" or
        "NEAR FULL: BURN SUPPORTED, MAX UNKNOWN"
      t.fuelSupplyFloor=valid(t.actual) and t.actual or nil
    elseif t.fuelNearFull then
      t.fuelStatus="NEAR FULL: TRANSIENT / CHECK TREND"
    elseif valid(t.fuelNet) and t.fuelNet< -jitter then
      t.fuelStatus="FUEL DRAINING: SEEKING SUSTAINABLE CAP"
    elseif valid(self.fuelEstimate) then
      t.fuelStatus="PRODUCTION ESTIMATED"
    else
      t.fuelStatus="FUEL BUFFER TREND CALIBRATING"
    end
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
    -- Keep the last validated supply estimate as a persistent ceiling.
    -- It must NOT expire merely because the tank refilled to 100%:
    -- at saturation production is censored, so a 190s expiration would
    -- repeatedly reopen the cap and cause 430 -> 550 -> 430 oscillations.
    if valid(self.fuelEstimate) then
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
        local reserve=(valid(t.fuelEffective) and valid(t.fuelCapacity)) and
          max(0,t.fuelEffective-0.15*t.fuelCapacity) or 0
        local horizon=reserve/(-t.fuelNet*c.ticksPerSecond)
        if horizon<75 then
          limit("FUEL_RESERVE",max(c.minimumBurn,burn-c.downwardStep))
        end
      else
        limit("FUEL_DRAIN",max(c.minimumBurn,t.fuelProduction-0.5))
      end
    end
    local reason="SEEK FUEL/SPS LIMIT"
    local urgent=false
    -- A full turbine is not the same thing as a blocked reactor.
    -- React to actual reactor cooling/waste state instead.
    if not(valid(t.coolant) and valid(t.heated) and valid(t.waste) and valid(t.temperature)) then
      cap=min(cap,burn);reason="WAITING FOR REACTOR HEALTH SENSORS"
    elseif not t.thermalCap then
      cap=min(cap,burn);reason="HEAT CAPACITY UNKNOWN - HOLD"
    elseif t.heated>c.heatedWarn or t.waste>c.wasteWarn then
      cap=min(cap,burn-c.emergencyDownwardStep)
      reason="REACTOR OUTPUT BACKPRESSURE"
      urgent=true
    elseif t.coolant<c.coolantFastTrim then
      cap=min(cap,burn-c.emergencyDownwardStep)
      reason="COOLANT LOW - RAPID TRIM"
      urgent=true
    elseif t.coolant<c.coolantWarn then
      self.coolantLowSince=self.coolantLowSince or now
      self.coolantRecoverUntil=now+c.coolantRecoverySeconds
      if now-self.coolantLowSince>=c.coolantTrimSeconds then
        cap=min(cap,burn-c.thermalDownwardStep)
        reason="COOLANT SUSTAINED LOW - GENTLE TRIM"
      else
        cap=min(cap,burn)
        reason="COOLANT DIPPING - OBSERVE BEFORE TRIM"
      end
    elseif t.coolant<c.coolantHold then
      self.coolantLowSince=self.coolantLowSince or now
      self.coolantRecoverUntil=now+c.coolantRecoverySeconds
      cap=min(cap,burn)
      reason="COOLANT SMALL DIP - HOLD, NOT TRIM"
    elseif now<self.coolantRecoverUntil then
      cap=min(cap,burn)
      reason="COOLANT RECOVERING - NO HUNTING"
    else
      self.coolantLowSince=nil
      t.coolantStabilized=true
    end
    if t.coolant>=c.coolantReset and now>=self.coolantRecoverUntil then
      self.coolantLowSince=nil
    end
    if t.temperature>c.softTemperature or
      (t.expectedTemp and t.temperature>t.expectedTemp+60 and
       valid(t.tempSlope) and t.tempSlope>0.15) then
      cap=min(cap,burn-c.thermalDownwardStep)
      reason="REACTOR TEMPERATURE ABOVE MODEL"
      urgent=true
    elseif valid(t.tempSlope) and t.temperature>1050 and t.tempSlope>1.0 then
      cap=min(cap,burn)
      reason="TEMPERATURE RISING - HOLD"
    end
    -- Cooled reactor alone may recover from a 7-10% coolant fluctuation
    -- without any reduction. Independent RPS still trips at 65%.

    if valid(t.fuelAmount) and valid(t.fuelCapacity) and t.fuelCapacity>0 then
      local fill=t.fuelAmount/t.fuelCapacity
      if fill<0.05 and valid(t.fuelNet) and t.fuelNet<0 then
        cap=min(cap,max(c.minimumBurn,burn-c.emergencyDownwardStep))
        reason="FUEL TANK NEAR EMPTY"
        urgent=true
      end
    elseif not valid(t.reactorFuelAmount) then
      cap=min(cap,burn);reason="NO FISSILE FUEL INVENTORY - HOLD"
    end
    -- Stop wasting fissile fuel when solar conversion is truly absent.
    if t.solarCount==nil or t.solarUnknown and t.solarUnknown>0 then
      cap=min(cap,burn);reason="SOLAR TELEMETRY INCOMPLETE - HOLD"
    elseif t.solarCount==0 or t.solarWorking==0 then
      cap=min(cap,c.minimumBurn);reason="NO SOLAR POLONIUM CONVERSION"
      urgent=true
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
      -- Normal limits change by 1-2 mB/t per command, not 38-66 in one
      -- go. Fast intervention is reserved for clearly dangerous readings.
      local step=urgent and c.emergencyDownwardStep or c.downwardStep
      if reason=="NO SOLAR POLONIUM CONVERSION" or
          (valid(t.antimatterFill) and t.antimatterFill>=c.spsFull) then
        -- Stop actively wasting fuel when Polonium has no conversion
        -- or the Antimatter product is completely backpressured.
        target=cap
      elseif interval>=c.changeIntervalSeconds or urgent then
        target=max(cap,burn-step)
      end
      reason=reason=="SEEK FUEL/SPS LIMIT" and "TRIM TO REAL LIMIT" or reason
    elseif cap>burn+0.2 and interval>=c.changeIntervalSeconds then
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
