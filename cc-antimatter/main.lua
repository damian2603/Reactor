-- Project Infinity / ANTImatter Control v1. Fresh controller, no legacy code.
-- Fission safety > sustainable Fissile Fuel > measured Antimatter. Turbine FE is secondary.
local ROOT="/cc-antimatter"
local control=dofile(ROOT.."/control.lua")
local CFG=ROOT.."/settings"
local state={mode="MANUAL",on=false,alarm="",info="START IN MANUAL. REACTOR NEVER AUTO-STARTS.",page=1}
local cfg=control.defaults()
local function valid(x) return type(x)=="number" and x==x and x~=math.huge and x~=-math.huge end
local function number(x)
  if valid(x) then return x end
  if type(x)=="string" then return tonumber(x) end
  if type(x)=="table" then
    return number(x.amount) or number(x.stored) or number(x.value)
  end
  return nil
end
local function clamp(x,a,b) return math.max(a,math.min(b,x)) end
local function fmt(x,d)
  if not valid(x) then return "--" end
  return string.format("%."..(d or 1).."f",x)
end
local function pc(name,method,...)
  if not name then return nil end
  local ok,v=pcall(peripheral.call,name,method,...)
  if ok then return v end
  return nil
end
local function epoch() return os.epoch("utc")/1000 end
local function readConfig()
  if not fs.exists(CFG) then return end
  local f=fs.open(CFG,"r")
  if not f then return end
  local text=f.readAll();f.close()
  local ok,v=pcall(textutils.unserialize,text)
  if not ok or type(v)~="table" then return end
  cfg=control.defaults(v)
  if type(v.reactor)=="string" then cfg.reactor=v.reactor end
  if type(v.sps)=="string" then cfg.sps=v.sps end
  if type(v.fuelTank)=="string" then cfg.fuelTank=v.fuelTank end
  if type(v.monitor)=="string" then cfg.monitor=v.monitor end
end
local function saveConfig()
  local raw=textutils.serialize(cfg)
  local free=fs.getFreeSpace(ROOT)
  if type(free)=="number" and free<#raw+1500 then
    state.info="NO DISK SPACE TO SAVE SETTINGS";return false end
  local temp=CFG..".new"
  if fs.exists(temp) then pcall(fs.delete,temp) end
  local ok,why=pcall(function()
    local f=assert(fs.open(temp,"w"),"settings open failed")
    f.write(raw);f.close()
    assert(fs.getSize(temp)==#raw,"settings copy incomplete")
    if fs.exists(CFG) then fs.delete(CFG) end
    fs.move(temp,CFG)
  end)
  if not ok then
    state.info="SETTINGS WRITE FAILED: "..tostring(why)
    return false
  end
  return true
end
readConfig()
local model=control.new(cfg)
local P={reactor=nil,sps=nil,fuelTank=nil,turbine=nil,monitor=nil,solar={}}
local function methods(name)
  local ok,all=pcall(peripheral.getMethods,name)
  local got={};if ok and type(all)=="table" then for _,m in ipairs(all) do got[m]=true end end
  return got
end
local function choose(candidates,setting)
  if setting and setting~="" then
    for _,v in ipairs(candidates) do if v==setting then return v end end
    return nil
  end
  if #candidates==1 then return candidates[1] end
  return nil
end
local lastDiscovery=0
local function discover()
  local reactors,sps,tanks,turbines,monitors,solars={},{},{},{},{},{}
  for _,name in ipairs(peripheral.getNames()) do
    local m=methods(name)
    if m.getActualBurnRate and m.setBurnRate and m.scram and m.getTemperature then
      reactors[#reactors+1]=name
    elseif m.getProcessRate and m.getInputFilledPercentage and m.getOutputFilledPercentage then
      sps[#sps+1]=name
    elseif m.getDumpingMode and m.getSteamFilledPercentage then
      turbines[#turbines+1]=name
    elseif m.canSeeSun and m.getProductionRate then
      solars[#solars+1]=name
    elseif (m.getStored or m.getStoredGas or m.getStoredChemical) and
       (m.getCapacity or m.getTankCapacity) then
      tanks[#tanks+1]=name
    elseif m.getSize and m.setTextScale and m.setCursorPos then
      monitors[#monitors+1]=name
    end
  end
  table.sort(solars)
  local old=P.monitor
  P.reactor=choose(reactors,cfg.reactor)
  P.sps=choose(sps,cfg.sps)
  P.fuelTank=choose(tanks,cfg.fuelTank)
  P.turbine=choose(turbines,nil)
  P.monitor=choose(monitors,cfg.monitor)
  P.solar=solars
  state.discovery={reactors=#reactors,sps=#sps,tanks=#tanks,solars=#solars}
  if old~=P.monitor then state.uiCache={} end
  if not P.reactor then state.info="REACTOR MISSING / MULTIPLE - SET NAME IN SETTINGS" end
  if not P.fuelTank then state.info="CONNECT ONE FISSILE FUEL TANK OR SELECT IN SETTINGS" end
  lastDiscovery=epoch()
end
local function readParallel(jobs)
  local tasks={}
  for _,job in ipairs(jobs) do
    tasks[#tasks+1]=function()
      local v=pc(job[2],job[3])
      job[1][job[4]]=v
    end
  end
  if #tasks>0 then parallel.waitForAll(table.unpack(tasks)) end
end
local function tsSample()
  local t={ts=epoch(),reactor=P.reactor,sps=P.sps}
  local jobs={}
  local function ask(where,key,name,method)
    if name then jobs[#jobs+1]={where,name,method,key} end
  end
  local r,u,s,f=P.reactor,P.turbine,P.sps,P.fuelTank
  for key,method in pairs({
    formed="isFormed",on="getStatus",burn="getBurnRate",actual="getActualBurnRate",
    maxBurn="getMaxBurnRate",temperature="getTemperature",damage="getDamagePercent",
    coolant="getCoolantFilledPercentage",heated="getHeatedCoolantFilledPercentage",
    waste="getWasteFilledPercentage",heatCapacity="getHeatCapacity",
    reactorFuel="getFuel",reactorFuelCapacity="getFuelCapacity",
    coolantType="getCoolant",heating="getHeatingRate",disabled="isForceDisabled"
  }) do ask(t,key,r,method) end
  for key,method in pairs({amRate="getProcessRate",poloniumFill="getInputFilledPercentage",
      antimatterFill="getOutputFilledPercentage",spsFormed="isFormed",
      poloniumStored="getInput",antimatterStored="getOutput"}) do ask(t,key,s,method) end
  for key,method in pairs({turbineSteam="getSteamFilledPercentage",
    turbineFlow="getFlowRate",turbineMaxFlow="getMaxFlowRate",
    turbineDump="getDumpingMode",turbineEnergy="getEnergyFilledPercentage"}) do ask(t,key,u,method) end
  if f then
    local fm=methods(f)
    if fm.getStored then ask(t,"tankStored",f,"getStored")
    elseif fm.getStoredGas then ask(t,"tankStored",f,"getStoredGas")
    else ask(t,"tankStored",f,"getStoredChemical") end
    if fm.getCapacity then ask(t,"fuelCapacity",f,"getCapacity")
    else ask(t,"fuelCapacity",f,"getTankCapacity") end
  end
  readParallel(jobs)
  for _,key in ipairs({"burn","actual","maxBurn","temperature","damage","coolant","heated","waste",
     "heatCapacity","heating","amRate","poloniumFill","antimatterFill","poloniumStored",
     "antimatterStored","turbineSteam","turbineFlow","turbineMaxFlow","turbineEnergy","fuelCapacity"}) do
    t[key]=number(t[key])
  end
  t.fuelAmount=number(t.tankStored)
  t.reactorFuelAmount=number(t.reactorFuel)
  -- Do not make a falsely verified Fissile Fuel supply from an unknown tank.
  local tankGas=type(t.tankStored)=="table" and
    tostring(t.tankStored.name or t.tankStored.id or ""):lower() or ""
  t.fuelIsWrongGas=tankGas~="" and tankGas:find("fissile",1,true)==nil
  if t.fuelIsWrongGas then t.fuelAmount=nil end
  t.sodiumCoolant=type(t.coolantType)=="table" and
    tostring(t.coolantType.name or t.coolantType.id or ""):lower():find("sodium",1,true)~=nil or false
  t.solarCount=#P.solar
  t.solarWorking=0;t.solarRate=0;t.solarUnknown=0
  local sr={}
  for i=1,#P.solar do sr[i]={} end
  -- Limit SNA calls: two methods per machine are enough for throughput.
  local tasks={}
  for i,name in ipairs(P.solar) do
    tasks[#tasks+1]=function()
      sr[i].rate=number(pc(name,"getProductionRate"))
      sr[i].sun=pc(name,"canSeeSun")
    end
  end
  if #tasks>0 then parallel.waitForAll(table.unpack(tasks)) end
  for _,v in ipairs(sr) do
    if valid(v.rate) then t.solarRate=t.solarRate+math.max(0,v.rate)
    else t.solarUnknown=t.solarUnknown+1 end
    if v.sun and valid(v.rate) and v.rate>0 then t.solarWorking=t.solarWorking+1 end
  end
  return t
end

-- Separate safety loop, even when telemetry or the monitor is busy.
local safetyPrev=nil
local healthySafety=0
local safetyMissing=0
local fastSafetyLast=0
local function emergency(reason)
  if state.latched then return end
  state.latched=true;state.mode="MANUAL";state.alarm=tostring(reason)
  state.info="EMERGENCY SCRAM: "..state.alarm
  if P.reactor then pcall(peripheral.call,P.reactor,"scram") end
end
local function fastSafety()
  local t={ts=epoch()}
  if not P.reactor then return t end
  local jobs={}
  for key,method in pairs({on="getStatus",formed="isFormed",temperature="getTemperature",
    coolant="getCoolantFilledPercentage",heated="getHeatedCoolantFilledPercentage",
    waste="getWasteFilledPercentage",damage="getDamagePercent",disabled="isForceDisabled"}) do
    jobs[#jobs+1]={t,P.reactor,method,key}
  end
  readParallel(jobs)
  for _,key in ipairs({"temperature","coolant","heated","waste","damage"}) do t[key]=number(t[key]) end
  return t
end
local function safetyLoop()
  while state.running do
    if not P.reactor then discover() end
    local t=fastSafety()
    local ok,why=control.safety(t,safetyPrev,cfg)
    if ok then
      healthySafety=math.min(10,healthySafety+1);safetyMissing=0;fastSafetyLast=t.ts
    else
      if why:find("SENSOR MISSING",1,true) or why=="NO REACTOR TELEMETRY" then
        safetyMissing=safetyMissing+1
        healthySafety=0
        if safetyMissing>=3 and (state.lastOn~=false) then emergency("SAFETY SENSORS LOST") end
      elseif t.on~=false or state.lastOn~=false then emergency(why) end
    end
    if t.on~=nil then state.lastOn=t.on end
    safetyPrev=t
    sleep(0.25)
  end
end
local latest=nil
local function setBurn(nextBurn)
  if not P.reactor then return false end
  if not valid(nextBurn) then return false end
  if latest and latest.maxBurn then nextBurn=clamp(nextBurn,0,latest.maxBurn) end
  if nextBurn<0.01 then nextBurn=0.01 end
  nextBurn=math.floor(nextBurn*100+0.5)/100
  local ok,msg=pcall(peripheral.call,P.reactor,"setBurnRate",nextBurn)
  if not ok then state.info="SET BURN FAILED: "..tostring(msg);return false end
  state.lastCommand=nextBurn
  return true
end
local lastLog=0
local LOG=ROOT.."/history.csv"
local function log(t,d)
  if t.ts-lastLog<15 then return end
  lastLog=t.ts
  local free=fs.getFreeSpace(ROOT)
  if type(free)=="number" and free<8000 then return end
  local size=fs.exists(LOG) and fs.getSize(LOG) or 0
  if size>90000 then
    local archived=LOG..".previous"
    local ok=pcall(function()
      if fs.exists(archived) then fs.delete(archived) end
      fs.move(LOG,archived)
    end)
    if not ok then return end
  end
  local exists=fs.exists(LOG)
  pcall(function()
    local f=assert(fs.open(LOG,"a"))
    if not exists then
      f.writeLine("utc,mode,burn,actual,target,cap,amRate,polonium,fuelAmount,fuelNet,fuelEstimate,temp,expected,coolant,heated,waste,steam,reason")
    end
    local cells={math.floor(t.ts),state.mode,fmt(t.burn,2),fmt(t.actual,2),fmt(d.target,2),fmt(d.cap,2),fmt(t.amRate,5),
      fmt(t.poloniumFill,4),fmt(t.fuelAmount,1),fmt(t.fuelNet,3),fmt(t.fuelEstimate,2),fmt(t.temperature,1),
      fmt(t.expectedTemp,1),fmt(t.coolant,3),fmt(t.heated,3),fmt(t.waste,3),fmt(t.turbineSteam,3),
      '"'..tostring(d.reason or ""):gsub('"','""')..'"'}
    f.writeLine(table.concat(cells,","));f.close()
  end)
end
local function telemetryLoop()
  while state.running do
    if epoch()-lastDiscovery>15 or not P.reactor then discover() end
    local ok,t=pcall(tsSample)
    if ok and t then
      latest=t
      if not state.latched and state.mode=="AUTO" and t.on==true then
        if healthySafety>=2 and t.ts-fastSafetyLast<4 then
          model:observe(t)
          local decision=model:decide(t)
          state.decision=decision
          if t.fuelAmount==nil or t.fuelCapacity==nil then
            state.info="AUTO HOLD: FISSILE FUEL TANK NOT VERIFIED"
          elseif not P.sps or t.amRate==nil or t.poloniumFill==nil then
            state.info="AUTO HOLD: SPS NOT VERIFIED"
          elseif t.solarUnknown>0 or t.solarCount==0 then
            state.info="AUTO HOLD: SOLAR PERIPHERALS MISSING"
          elseif valid(t.burn) and math.abs(decision.target-t.burn)>0.19 then
            if setBurn(decision.target) then state.info=decision.reason end
          else state.info=decision.reason end
        else state.info="AUTO HOLD: SAFETY LOOP NOT READY" end
      else
        model:observe(t) -- continued calibration in MANUAL also useful
        if state.mode=="AUTO" and not t.on then
          state.mode="MANUAL";state.info="REACTOR OFF. AUTO DOES NOT START IT."
        end
      end
      if not state.decision then state.decision=model.result end
      log(t,state.decision)
    else
      state.info="TELEMETRY ERROR: "..tostring(t)
    end
    sleep(2)
  end
end

-- This is a touchscreen UI, not the old status-only terminal.
local cache={}
local touch={}
local function draw(dev,side)
  if not dev then return end
  local ok,w,h=pcall(dev.getSize)
  if not ok or not valid(w) or not valid(h) then return end
  if cache[side]==nil or cache[side].w~=w or cache[side].h~=h then
    cache[side]={w=w,h=h,lines={}}
    pcall(dev.setBackgroundColor,colors.black)
    pcall(dev.clear)
  end
  local old=cache[side].lines
  local lines={}
  local function line(y,msg,col)
    if y<1 or y>h then return end
    lines[y]={t=tostring(msg or ""):sub(1,w),c=col or colors.white}
  end
  local t=latest or {}
  local d=state.decision or {}
  line(1,"PROJECT INFINITY   ANTIMATTER v1   "..state.mode,colors.cyan)
  line(2,"SAFETY "..(state.latched and "SCRAM "..state.alarm or (healthySafety>=2 and "ARMED" or "WAITING")),
    state.latched and colors.red or colors.lime)
  line(3,"Burn "..fmt(t.burn,2).." / actual "..fmt(t.actual,2).." / cap "..fmt(d.cap,1),colors.white)
  line(4,"AM "..fmt(t.amRate,5).." mB/t = "..fmt((t.amRate or 0)*1200,2).." mB/min",colors.lime)
  line(5,"FUEL "..fmt(t.fuelNet,3).." mB/t net | estimate "..fmt(t.fuelEstimate,1).." mB/t",colors.yellow)
  line(6,"Temp "..fmt(t.temperature,1).." / expected "..fmt(t.expectedTemp,1).." K",colors.white)
  line(7,"Coolant "..fmt((t.coolant or 0)*100,1).."% Heated "..fmt((t.heated or 0)*100,1).."% Waste "..fmt((t.waste or 0)*100,1).."%")
  line(8,"Polonium "..fmt((t.poloniumFill or 0)*100,2).."% / Solar "..tostring(t.solarWorking or 0).."/"..tostring(t.solarCount or 0))
  line(9,"Flux REF "..fmt(cfg.fluxFE/1000000,0).."M FE/t (MANUAL, NOT MEASURED)",colors.lightBlue)
  line(10,"User burn cap "..fmt(cfg.userCap,0).."  | Fuel tank "..fmt(t.fuelAmount,0).." mB",colors.white)
  line(11,"Turbine steam "..fmt((t.turbineSteam or 0)*100,1).."% (DIAGNOSTIC ONLY)",colors.gray)
  line(12,"Control: "..tostring(d.reason or "NO AUTO DECISION"),colors.yellow)
  line(13,"Info: "..tostring(state.info or ""),colors.orange)
  if h>19 then
    line(15,"Measured SPS / Fissile Fuel determine the optimum",colors.lightGray)
    line(16,"Turbine steam NEVER triggers reactor SCRAM",colors.lightGray)
    line(17,"Fuel source: "..tostring(P.fuelTank or "MISSING / AMBIGUOUS"),colors.gray)
    line(18,"SPS: "..tostring(P.sps or "MISSING / AMBIGUOUS"),colors.gray)
  end
  if h>=9 then
    local y=h-2
    local buttons={{"AUTO",function()
      if state.latched then state.info="RESET: INSPECT REACTOR FIRST";return end
      if latest and latest.on==true and P.fuelTank and P.sps and
        #P.solar>0 and healthySafety>=2 and not latest.fuelIsWrongGas then
        state.mode="AUTO";state.info="AUTO ENABLED; WILL NOT START REACTOR"
      else state.info="AUTO NEEDS RUNNING REACTOR, FUEL TANK, SPS, SNA" end end},
      {"MAN",function()state.mode="MANUAL";state.info="MANUAL: NO AUTO BURN CHANGES" end},
      {"SCRAM",function()emergency("OPERATOR SCRAM") end},
      {"FE-",function()local before=cfg.fluxFE;cfg.fluxFE=math.max(1000000,cfg.fluxFE-1000000)
        if not saveConfig() then cfg.fluxFE=before end
        model.cfg.fluxFE=cfg.fluxFE end},
      {"FE+",function()local before=cfg.fluxFE;cfg.fluxFE=cfg.fluxFE+1000000
        if not saveConfig() then cfg.fluxFE=before end
        model.cfg.fluxFE=cfg.fluxFE end},
      {"CAP-",function()local before=cfg.userCap;cfg.userCap=math.max(1,cfg.userCap-25)
        if not saveConfig() then cfg.userCap=before end
        model.cfg.userCap=cfg.userCap end},
      {"CAP+",function()local before=cfg.userCap;cfg.userCap=cfg.userCap+25
        if not saveConfig() then cfg.userCap=before end
        model.cfg.userCap=cfg.userCap end}}
    local x=1;touch[side]={}
    for _,entry in ipairs(buttons) do
      local label="["..entry[1].."]"
      if x+#label-1<=w then
        line(y,(lines[y] and lines[y].t or "")..label,colors.lightBlue)
        touch[side][#touch[side]+1]={x=x,last=x+#label-1,y=y,action=entry[2]}
        x=x+#label+1
        if x<=w then
          if lines[y] then lines[y].t=lines[y].t.." " end
        end
      end
    end
    line(h-1,"Keyboard: A AUTO / M MANUAL / X SCRAM / Q QUIT",colors.white)
    line(h,"No auto activation; hardware SCRAM strongly recommended",colors.gray)
  end
  for y=1,h do
    local item=lines[y] or {t="",c=colors.white}
    if not old[y] or item.t~=old[y].t or item.c~=old[y].c then
      pcall(function()
        dev.setCursorPos(1,y)
        dev.setBackgroundColor(colors.black)
        dev.setTextColor(item.c)
        dev.write(item.t..string.rep(" ",math.max(0,w-#item.t)))
      end)
      old[y]={t=item.t,c=item.c}
    end
  end
end
local function displayLoop()
  while state.running do
    if P.monitor then
      local dev=peripheral.wrap(P.monitor)
      if dev then pcall(dev.setTextScale,0.5);draw(dev,P.monitor) end
    end
    draw(term.current(),"computer")
    sleep(0.8)
  end
end
local function inputLoop()
  while state.running do
    local e,a,b,c=os.pullEvent()
    if e=="monitor_touch" and a==P.monitor then
      for _,hit in ipairs(touch[a] or {}) do
        if c==hit.y and b>=hit.x and b<=hit.last then
          hit.action();break
        end
      end
    elseif e=="char" then
      local ch=a:lower()
      if ch=="a" then
        if latest and latest.on and P.fuelTank and P.sps and #P.solar>0 and
           not latest.fuelIsWrongGas and
           healthySafety>=2 and not state.latched then
          state.mode="AUTO";state.info="AUTO ON. NEVER AUTO-STARTS."
        else state.info="AUTO NEEDS HEALTHY RUNNING REACTOR + TANK + SPS" end
      elseif ch=="m" then state.mode="MANUAL";state.info="MANUAL CONTROL"
      elseif ch=="x" or ch=="s" then emergency("OPERATOR SCRAM")
      elseif ch=="q" then state.running=false;state.info="EXIT: SCRAM ON EXIT"
      elseif ch=="+" or ch=="-" then
        if state.mode=="MANUAL" and latest and latest.on and not state.latched then
          local nextBurn=(latest.burn or 0)+(ch=="+" and 5 or -5)
          setBurn(nextBurn);state.info="MANUAL BURN REQUESTED "..fmt(nextBurn,1)
        else state.info="MANUAL ONLY: PRESS M FIRST" end
      end
    end
  end
end

local function main()
  if not fs.exists(ROOT) then fs.makeDir(ROOT) end
  state.running=true
  state.latched=false
  state.mode="MANUAL" -- NEVER resume AUTO or activate reactor on reboot.
  discover()
  print("Project Infinity Antimatter v1 | MODE: MANUAL")
  print("Reactor: "..tostring(P.reactor).." | SPS: "..tostring(P.sps))
  print("Fuel tank: "..tostring(P.fuelTank).." | SNAs: "..#P.solar)
  print("Press A for AUTO only after verifying hardware and reactor status.")
  local ok,err=xpcall(function()
    parallel.waitForAll(safetyLoop,telemetryLoop,displayLoop,inputLoop)
  end,debug.traceback)
  -- Fail-safe: don't let a Lua crash leave a live reactor uncontrolled.
  if P.reactor then pcall(peripheral.call,P.reactor,"scram") end
  if not ok then error("CONTROLLER STOPPED / SCRAM attempted: "..tostring(err),0) end
  print("STOPPED. SCRAM attempted. Manual reactor restart only.")
end
-- Allow pure mock runtime testing without actual CC.Tweaked hardware.
if rawget(_G,"ANTIMATTER_UNIT_TEST") then
  return {control=control,setBurn=setBurn,safety=control.safety,
    state=state,config=cfg}
end
main()
