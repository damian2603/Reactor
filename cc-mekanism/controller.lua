-- Project Infinity / Mekanism Fission-Turbine-SPS Controller 2.1 (adaptive geometry)
-- CC:Tweaked 1.20.1. Standalone, no dependencies.
-- Adapted from analysis of Mekanism's CC API; inspired by cc-mek-scada's
-- fail-safe alarm philosophy. Not a copy of upstream code.
-- IMPORTANT: independent Fission Logic Adapters are still required.
local ROOT = "/cc-mekanism"
local CONF, CSV = ROOT.."/settings", ROOT.."/history.csv"
if not fs.exists(ROOT) then fs.makeDir(ROOT) end
local defaults = {
  reactor="", turbine="", sps="", boiler="", matrix="", monitor="",
  sampleSeconds=1, logSeconds=10,
  maxAutoBurn=1.0, step=0.1, stepSeconds=15,
  autoBurnCeiling=0, -- 0=use detected reactor maximum; manual override only
  autoRampFraction=0.005, -- 0.5% of detected max burn per ramp interval
  tempTrip=1000, tempWarn=850, damageTrip=0,
  coolantTrip=0.60, coolantWarn=0.85, coolantDropTrip=0.08,
  wasteTrip=0.85, wasteWarn=0.68, heatedTrip=0.85, heatedWarn=0.68,
  steamTrip=0.86, steamWarn=0.65, turbineEnergyWarn=0.90,
  spsInputWarn=0.85, spsOutputWarn=0.90,
  safetyFlowFactor=0.78, requireTurbine=true,
  returnWaterRequired=false,
  alarmRedstoneSide="", -- optional output (e.g. "right"), true when latched
}
local c = {}
for k,v in pairs(defaults) do c[k]=v end
if fs.exists(CONF) then
  local f=fs.open(CONF,"r")
  if f then
    local ok,loaded=pcall(textutils.unserialize,f.readAll())
    f.close()
    if ok and type(loaded)=="table" then
      for k,v in pairs(defaults) do
        if type(loaded[k])==type(v) then c[k]=loaded[k] end
      end
      -- v2 used a hard default 1 mB/t; new AUTO is capped by actual
      -- structure telemetry, not the old fixed starter cap.
      if type(loaded.autoBurnCeiling)~="number" and
          type(loaded.maxAutoBurn)=="number" and loaded.maxAutoBurn>1.0 then
        c.autoBurnCeiling=loaded.maxAutoBurn
      end
    end
  end
else
  local f=fs.open(CONF,"w")
  if f then f.write(textutils.serialize(c));f.close() end
end
local function save()
  local f=fs.open(CONF,"w")
  if f then f.write(textutils.serialize(c));f.close() end
end
local function N(x)
  if type(x)=="table" then x=x.amount or x.value or x.stored or x.energy end
  if type(x)=="string" then x=tonumber(x) or tonumber(x:match("[%d%.]+")) end
  if type(x)=="number" and x==x and x~=math.huge and x~=-math.huge then return x end
end
local function clamp(x,a,b) return math.max(a,math.min(x,b)) end
local function p(x) return N(x) and string.format("%4.1f%%",x*100) or "--.-%" end
local function n(x,d) return N(x) and string.format("%."..(d or 1).."f",x) or "--" end
local function fmt(x)
  x=N(x); if not x then return "--" end
  if math.abs(x)>=1e12 then return n(x/1e12,2).."T"
  elseif math.abs(x)>=1e9 then return n(x/1e9,2).."G"
  elseif math.abs(x)>=1e6 then return n(x/1e6,2).."M"
  elseif math.abs(x)>=1e3 then return n(x/1e3,1).."k" end
  return n(x,1)
end
local function pc(name,method,...)
  if not name or not peripheral.isPresent(name) then return nil end
  local ok,v=pcall(peripheral.call,name,method,...)
  if ok then return v end
  return nil
end
local function has(name,method)
  local ok,methods=pcall(peripheral.getMethods,name)
  if not ok or type(methods)~="table" then return false end
  for _,v in ipairs(methods) do if v==method then return true end end
  return false
end
local schema={
  reactor={"setBurnRate","scram","getTemperature"},
  turbine={"getMaxFlowRate","getProductionRate"},
  sps={"getProcessRate","getInputFilledPercentage"},
  boiler={"getBoilCapacity","getSteamFilledPercentage"},
  matrix={"getLastInput","getLastOutput","getEnergyFilledPercentage"},
  monitor={"setTextScale","getSize"},
}
local order={"reactor","turbine","sps","boiler","matrix","monitor"}
local names,duplicates={},{}
local function discover()
  local all=peripheral.getNames()
  table.sort(all)
  for _,kind in ipairs(order) do
    local matches={}
    for _,per in ipairs(all) do
      local valid=true
      for _,method in ipairs(schema[kind]) do
        if not has(per,method) then valid=false;break end
      end
      if valid then matches[#matches+1]=per end
    end
    local selected=c[kind]
    if selected~="" then
      names[kind]=peripheral.isPresent(selected) and selected or nil
      duplicates[kind]=nil
    elseif #matches==1 then
      names[kind]=matches[1];duplicates[kind]=nil
    else
      names[kind]=nil
      duplicates[kind]=#matches>1 and table.concat(matches,", ") or nil
    end
  end
end
discover()
local mode="MANUAL" -- NEVER persist automatic operation or auto-start
local latched=false
local alarm,info="","Boot: MANUAL, auto-start disabled"
local current={}, previous=nil
local recentValid=0
local lastChange,lastLog=0,0
local learnedSteamPerBurn=nil
local startConfirmUntil=0
local active=true
local screen=term.current()
local buttons={}
local function redstoneAlarm(on)
  if c.alarmRedstoneSide~="" then
    pcall(redstone.setOutput,c.alarmRedstoneSide,on)
  end
end
local function trip(reason)
  latched=true;alarm=tostring(reason)
  mode="MANUAL"
  redstoneAlarm(true)
  if names.reactor and peripheral.isPresent(names.reactor) then
    local ok,err=pcall(peripheral.call,names.reactor,"scram")
    info=ok and "SCRAM: "..alarm or "SCRAM attempted: "..tostring(err)
  else
    info="ALARM: "..alarm.." (reactor unreachable)"
  end
end
local function burn(rate)
  local r=names.reactor
  if not r or not current.maxBurn then return false,"reactor unavailable" end
  rate=N(rate);if not rate then return false,"invalid rate" end
  rate=math.floor(clamp(rate,0,current.maxBurn)*100+0.5)/100
  local ok,err=pcall(peripheral.call,r,"setBurnRate",rate)
  return ok,ok and rate or tostring(err)
end
local function read()
  local t={ts=os.epoch("utc")/1000}
  local r,u,sp,b,im=names.reactor,names.turbine,names.sps,names.boiler,names.matrix
  t.formed=pc(r,"isFormed")
  t.on=pc(r,"getStatus")
  t.burn=N(pc(r,"getBurnRate"))
  t.actual=N(pc(r,"getActualBurnRate"))
  t.maxBurn=N(pc(r,"getMaxBurnRate"))
  t.rLength=N(pc(r,"getLength"))
  t.rWidth=N(pc(r,"getWidth"))
  t.rHeight=N(pc(r,"getHeight"))
  t.assemblies=N(pc(r,"getFuelAssemblies"))
  t.boilEfficiency=N(pc(r,"getBoilEfficiency"))
  t.fuelCapacity=N(pc(r,"getFuelCapacity"))
  t.wasteCapacity=N(pc(r,"getWasteCapacity"))
  t.coolantCapacity=N(pc(r,"getCoolantCapacity"))
  t.temp=N(pc(r,"getTemperature"))
  t.damage=N(pc(r,"getDamagePercent"))
  t.coolant=N(pc(r,"getCoolantFilledPercentage"))
  t.heated=N(pc(r,"getHeatedCoolantFilledPercentage"))
  t.waste=N(pc(r,"getWasteFilledPercentage"))
  t.fuel=N(pc(r,"getFuelFilledPercentage"))
  t.steamMade=N(pc(r,"getHeatingRate"))
  t.disabled=pc(r,"isForceDisabled")
  t.tFormed=pc(u,"isFormed")
  t.steam=N(pc(u,"getSteamFilledPercentage"))
  t.flow=N(pc(u,"getFlowRate"))
  t.maxFlow=N(pc(u,"getMaxFlowRate"))
  t.tLength=N(pc(u,"getLength"))
  t.tWidth=N(pc(u,"getWidth"))
  t.tHeight=N(pc(u,"getHeight"))
  t.blades=N(pc(u,"getBlades"))
  t.coils=N(pc(u,"getCoils"))
  t.vents=N(pc(u,"getVents"))
  t.condensers=N(pc(u,"getCondensers"))
  t.dispersers=N(pc(u,"getDispersers"))
  t.maxProduction=N(pc(u,"getMaxProduction"))
  t.steamCapacity=N(pc(u,"getSteamCapacity"))
  t.steamIn=N(pc(u,"getLastSteamInputRate"))
  t.power=N(pc(u,"getProductionRate"))
  t.energy=N(pc(u,"getEnergyFilledPercentage"))
  t.waterOut=N(pc(u,"getMaxWaterOutput"))
  t.dump=pc(u,"getDumpingMode")
  t.bFormed=pc(b,"isFormed")
  t.bSteam=N(pc(b,"getSteamFilledPercentage"))
  t.bHot=N(pc(b,"getHeatedCoolantFilledPercentage"))
  t.bWater=N(pc(b,"getWaterFilledPercentage"))
  t.bBoilCapacity=N(pc(b,"getBoilCapacity"))
  t.spFormed=pc(sp,"isFormed")
  t.spInput=N(pc(sp,"getInputFilledPercentage"))
  t.spOutput=N(pc(sp,"getOutputFilledPercentage"))
  t.spRate=N(pc(sp,"getProcessRate"))
  t.spLength=N(pc(sp,"getLength"))
  t.spWidth=N(pc(sp,"getWidth"))
  t.spHeight=N(pc(sp,"getHeight"))
  t.spCoils=N(pc(sp,"getCoils"))
  t.spInputCapacity=N(pc(sp,"getInputCapacity"))
  t.spOutputCapacity=N(pc(sp,"getOutputCapacity"))
  t.imEnergy=N(pc(im,"getEnergyFilledPercentage"))
  t.imIn=N(pc(im,"getLastInput"));t.imOut=N(pc(im,"getLastOutput"))
  if previous then
    local dt=t.ts-previous.ts
    if dt>0.2 and dt<15 then
      for _,field in ipairs({"coolant","waste","heated","steam","energy","spInput"}) do
        if t[field] and previous[field] then t[field.."Delta"]=(t[field]-previous[field])/dt end
      end
    end
  end
  previous=t
  return t
end
local function required(t)
  if not names.reactor then return false,duplicates.reactor and "multiple reactors: configure settings" or "reactor disconnected" end
  local fields={"formed","on","burn","actual","maxBurn","temp","damage","coolant","heated","waste","fuel"}
  for _,field in ipairs(fields) do if t[field]==nil then return false,"reactor read failed: "..field end end
  if t.formed~=true then return false,"reactor not formed" end
  if c.requireTurbine then
    if not names.turbine then return false,"turbine disconnected/ambiguous" end
    if t.tFormed~=true or t.steam==nil or t.maxFlow==nil or t.energy==nil then
      return false,"turbine telemetry failed"
    end
  end
  return true
end
local function safety(t)
  local good,why=required(t)
  if not good then return false,why end
  if t.disabled==true then return false,"reactor force disabled" end
  if t.temp>=c.tempTrip then return false,"critical temperature" end
  if t.damage>c.damageTrip then return false,"reactor damage" end
  if t.coolant<c.coolantTrip then return false,"coolant too low" end
  if t.waste>=c.wasteTrip then return false,"nuclear waste full" end
  if t.heated>=c.heatedTrip then return false,"heated coolant full" end
  if t.steam and t.steam>=c.steamTrip then return false,"turbine steam full" end
  if t.bSteam and t.bSteam>=c.steamTrip then return false,"boiler steam full" end
  if t.bHot and t.bHot>=c.heatedTrip then return false,"boiler heated coolant full" end
  if t.coolantDelta and t.coolantDelta<=-c.coolantDropTrip then return false,"coolant dropping quickly" end
  return true
end
local function bottleneck(t)
  local reasons={}
  local function add(test,msg) if test then reasons[#reasons+1]=msg end end
  add(t.temp and t.temp>=c.tempWarn,"TEMP")
  add(t.coolant and t.coolant<c.coolantWarn,"COOLANT")
  add(t.coolantDelta and t.coolantDelta< -0.004,"COOLANT FALL")
  add(t.waste and t.waste>=c.wasteWarn,"WASTE OUT")
  add(t.wasteDelta and t.wasteDelta>0.001,"WASTE GROWTH")
  add(t.heated and t.heated>=c.heatedWarn,"HOT COOLANT")
  add(t.steam and t.steam>=c.steamWarn,"STEAM")
  add(t.steamDelta and t.steamDelta>0.003,"STEAM GROWTH")
  add(t.bSteam and t.bSteam>=c.steamWarn,"BOILER STEAM")
  add(t.bHot and t.bHot>=c.heatedWarn,"BOILER HOT")
  add(t.energy and t.energy>=c.turbineEnergyWarn,"TURBINE FE FULL")
  add(mode=="FE" and t.imEnergy and t.imEnergy>=0.90,"MATRIX FE FULL")
  add(mode=="SPS" and t.spInput and t.spInput>=c.spsInputWarn,"POLONIUM BUFFER")
  add(mode=="SPS" and t.spOutput and t.spOutput>=c.spsOutputWarn,"ANTIMATTER OUT")
  add(t.fuel and t.fuel<0.05,"LOW FUEL")
  return table.concat(reasons,", ")
end
local function safeCap(t)
  local cap=t.maxBurn or 0
  -- Max burn is calculated by Mekanism from the actual Fuel Assemblies.
  if c.autoBurnCeiling>0 then cap=math.min(cap,c.autoBurnCeiling) end
  -- For sodium + boiler the reactor heating rate cannot be equated
  -- to steam production. Boiler/turbine pressure must drive feedback.
  -- Learn empirical steam generated per 1 mB of actual fissile fuel.
  -- This works for direct water cooling. On sodium, boiler telemetry is
  -- also required and heated coolant/steam accumulation governs safety.
  if t.bFormed~=true and t.actual and t.actual>0.09 and t.steamMade and t.steamMade>0 then
    local value=t.steamMade/t.actual
    if value>50 and value<2000000 then
      learnedSteamPerBurn=learnedSteamPerBurn and
        (learnedSteamPerBurn*0.8+value*0.2) or value
    end
  end
  if t.bFormed~=true and learnedSteamPerBurn and t.maxFlow and t.maxFlow>0 then
    cap=math.min(cap,t.maxFlow*c.safetyFlowFactor/learnedSteamPerBurn)
    if c.returnWaterRequired and t.waterOut and t.waterOut>0 then
      cap=math.min(cap,t.waterOut*c.safetyFlowFactor/learnedSteamPerBurn)
    end
  end
  return math.floor(math.max(0,cap)*100+0.5)/100
end
local function auto(t)
  if mode=="MANUAL" or latched or t.on~=true then return end
  if mode=="SPS" and (not names.sps or t.spFormed~=true or
      t.spInput==nil or t.spOutput==nil or t.spRate==nil) then
    mode="MANUAL";info="AUTO SPS disabled: no SPS data";return
  end
  if c.returnWaterRequired and (not t.waterOut or t.waterOut==0) then
    mode="MANUAL";info="AUTO disabled: no condenser water output";return
  end
  if not t.burn or not t.maxBurn then return end
  local cap=safeCap(t)
  local dynamicStep=math.max(0.1,math.floor(t.maxBurn*clamp(c.autoRampFraction,0.0001,0.05)*100+0.5)/100)
  local problem=bottleneck(t)
  local target=t.burn
  if t.burn>cap then
    target=cap; info="AUTO cap reached"
  elseif problem~="" then
    target=math.max(0,math.min(cap,t.burn-math.max(dynamicStep*2,t.burn*0.25)))
    info="Throttle: "..problem
    lastChange=t.ts
  elseif t.ts-lastChange>=c.stepSeconds then
    target=math.min(cap,t.burn+dynamicStep)
    lastChange=t.ts
    info="AUTO ramp toward safe cap"
  end
  if math.abs(target-t.burn)>=0.009 then
    local ok,v=burn(target)
    if not ok then mode="MANUAL";info="AUTO setBurnRate failed: "..tostring(v) end
  end
  t.safeCap=cap
  t.limit=problem
end
local fields={"ts","on","burn","actual","temp","damage","coolant","heated","waste",
  "fuel","steamMade","rLength","rWidth","rHeight","assemblies","boilEfficiency",
  "steam","steamIn","flow","maxFlow","power","energy","tLength","tWidth","tHeight",
  "blades","coils","vents","condensers","maxProduction","waterOut",
  "spInput","spOutput","spRate","spLength","spWidth","spHeight","spCoils",
  "bSteam","bHot","bWater","bBoilCapacity","imEnergy","imIn","imOut"}
local function history(t)
  if t.ts-lastLog<c.logSeconds then return end
  lastLog=t.ts
  local exists=fs.exists(CSV)
  local f=fs.open(CSV,"a")
  if not f then return end
  if not exists then f.writeLine(table.concat(fields,",")..",mode,alarm") end
  local vals={}
  for _,key in ipairs(fields) do
    local v=t[key]
    if type(v)=="boolean" then v=v and 1 or 0 end
    vals[#vals+1]=v==nil and "" or tostring(v)
  end
  vals[#vals+1]=mode
  vals[#vals+1]='"'..alarm:gsub('"',"'")..'"'
  f.writeLine(table.concat(vals,","));f.close()
end
local function row(dev,y,label,clr)
  local w,h=dev.getSize();if y<1 or y>h then return end
  dev.setCursorPos(1,y)
  dev.setBackgroundColor(colors.black)
  dev.setTextColor(clr or colors.white)
  local v=tostring(label):sub(1,w)
  dev.write(v..string.rep(" ",math.max(0,w-#v)))
end
local function btn(dev,y,x,label,id)
  local w,h=dev.getSize()
  local s="["..label.."]"
  if x+#s-1>w or y<1 or y>h then return end
  dev.setCursorPos(x,y);dev.setBackgroundColor(colors.gray)
  dev.setTextColor(colors.white);dev.write(s)
  buttons[#buttons+1]={y=y,x=x,last=x+#s-1,id=id}
end
local function render(dev,isMonitor)
  if not dev then return end
  local ok=pcall(function()
    if dev.setTextScale then dev.setTextScale(0.5) end
    local w,h=dev.getSize()
    dev.setBackgroundColor(colors.black);dev.setTextColor(colors.white);dev.clear()
    row(dev,1,"PROJECT INFINITY / MEKANISM | "..mode..
        (latched and " | ALARM LATCHED" or (current.on and " | ACTIVE" or " | OFF")),latched and colors.red or colors.cyan)
    row(dev,2,"Reactor "..(tostring(current.rLength or "?").."x"..tostring(current.rWidth or "?").."x"..tostring(current.rHeight or "?"))..
        " | Assemblies "..fmt(current.assemblies).." | Turbine "..tostring(current.tLength or "?").."x"..
        tostring(current.tWidth or "?").."x"..tostring(current.tHeight or "?"))
    row(dev,3,"Burn: "..n(current.burn,2).." actual: "..n(current.actual,2).." max: "..n(current.maxBurn,2).." mB/t")
    row(dev,4,"AUTO ceiling: "..(c.autoBurnCeiling>0 and n(c.autoBurnCeiling,2) or "DETECTED MAX")..
      "  effective cap: "..n(current.safeCap,2).." mB/t")
    row(dev,5,"Temperature: "..n(current.temp,1).." K  Damage: "..n(current.damage,0).."%")
    row(dev,6,"Coolant "..p(current.coolant).."  Hot "..p(current.heated).."  Waste "..p(current.waste))
    row(dev,7,"Fuel "..p(current.fuel).."  Steam created "..fmt(current.steamMade).." mB/t")
    row(dev,8,"Turbine steam "..p(current.steam).."  energy "..p(current.energy))
    row(dev,9,"Turbine flow "..fmt(current.flow).."/"..fmt(current.maxFlow).."  input "..fmt(current.steamIn))
    row(dev,10,"Turbine gen "..fmt(current.power).."/"..fmt(current.maxProduction)..
      " | blades "..fmt(current.blades).." | condensers "..fmt(current.condensers))
    row(dev,11,"Boiler: "..(names.boiler and ("steam "..p(current.bSteam).." hot "..p(current.bHot)..
        " water "..p(current.bWater)) or "not connected"))
    row(dev,12,"SPS: "..(names.sps and ("polonium "..p(current.spInput)..
        " antimatter "..p(current.spOutput).." rate "..n(current.spRate,3)..
        " | coils "..fmt(current.spCoils)) or "not connected"))
    row(dev,13,"Induction Matrix "..p(current.imEnergy).."  FE in "..fmt(current.imIn).." out "..fmt(current.imOut))
    row(dev,14,"Bottleneck: "..(current.limit or bottleneck(current)))
    row(dev,15,"Info: "..info,colors.yellow)
    row(dev,16,"Alarm: "..(alarm~="" and alarm or "none"),latched and colors.red or colors.lime)
    if isMonitor and h>=20 then
      buttons={}
      btn(dev,h-2,1,"-", "minus");btn(dev,h-2,6,"+","plus")
      btn(dev,h-2,11,"CAP-","capminus");btn(dev,h-2,19,"CAP+","capplus")
      btn(dev,h-1,1,"MAN","manual");btn(dev,h-1,7,"FE","fe")
      btn(dev,h-1,12,"SPS","sps");btn(dev,h-1,18,"SCRAM","scram")
      btn(dev,h-1,26,"START","start")
    end
    row(dev,h,"Keyboard: +/- B burn C cap M manual F FE P SPS S stop R start Q quit",colors.lightGray)
  end)
  if not ok then info="Display error; check monitor size" end
end
local function display()
  if names.monitor and peripheral.isPresent(names.monitor) then
    render(peripheral.wrap(names.monitor),true)
    screen.setBackgroundColor(colors.black);screen.setTextColor(colors.white)
    screen.clear();screen.setCursorPos(1,1)
    print("Project Infinity | "..mode.." | "..(latched and "ALARM" or "OK"))
    print("Burn "..n(current.burn,2).." / actual "..n(current.actual,2))
    print("Temp "..n(current.temp,1).." K | coolant "..p(current.coolant)..
      " waste "..p(current.waste).." turbine steam "..p(current.steam))
    print("SPS polonium "..p(current.spInput).." antimatter "..p(current.spOutput))
    print("Alarm "..(alarm~="" and alarm or "none"))
    print("Keys: +/- b c m f p s r q")
  else render(screen,false) end
end
local function canStart()
  local ok,why=safety(current)
  if not ok then return false,why end
  if current.on then return false,"reactor is already active" end
  if current.temp>=c.tempWarn or current.coolant<c.coolantWarn or current.waste>=c.wasteWarn then
    return false,"startup needs extra headroom"
  end
  if current.burn==nil or current.burn<=0 then return false,"set burn rate first" end
  if recentValid<4 then return false,"wait for four good readings" end
  return true
end
local function command(cmd)
  if cmd=="scram" then trip("manual SCRAM");return end
  if cmd=="manual" then mode="MANUAL";info="MANUAL (safety still enabled)";return end
  if cmd=="fe" or cmd=="sps" then
    if latched then info="ALARM LATCHED: restart requires manual reset";return end
    if cmd=="sps" and (not names.sps or current.spInput==nil) then
      info="No SPS peripheral";return
    end
    mode=cmd=="fe" and "FE" or "SPS"
    lastChange=current.ts or os.epoch("utc")/1000
    info="AUTO "..mode.." enabled; reactor never auto-starts"
    return
  end
  if cmd=="minus" or cmd=="plus" then
    if latched then info="ALARM LATCHED";return end
    local ok,v=burn((current.burn or 0)+(cmd=="plus" and c.step or -c.step))
    if ok then mode="MANUAL";info="Manual burn set to "..n(v,2)
    else info="Burn error: "..tostring(v) end
    return
  end
  if cmd=="capminus" or cmd=="capplus" then
    local max=current.maxBurn or 0
    if max<=0 then info="Waiting for reactor size";return end
    local step=math.max(0.1,math.floor(max*0.05*100+0.5)/100)
    local cap=c.autoBurnCeiling>0 and c.autoBurnCeiling or max
    if cmd=="capplus" then cap=cap+step else cap=cap-step end
    if cap>=max then c.autoBurnCeiling=0
    else c.autoBurnCeiling=math.max(0.1,math.floor(cap*100+0.5)/100) end
    save()
    info="Auto ceiling: "..(c.autoBurnCeiling==0 and "DETECTED MAX" or n(c.autoBurnCeiling,2))
    return
  end
  if cmd=="start" then
    local ok,reason=canStart()
    if not ok then info="START denied: "..reason;return end
    local now=os.epoch("utc")/1000
    if now>startConfirmUntil then
      startConfirmUntil=now+7;info="Press START/R again within 7 seconds";return
    end
    startConfirmUntil=0
    local good,err=pcall(peripheral.call,names.reactor,"activate")
    if good then latched=false;alarm="";redstoneAlarm(false);info="Manual activation sent"
    else info="Activation failed: "..tostring(err) end
    return
  end
end
local edit,buffer=nil,""
local function setTyped()
  local v=tonumber(buffer)
  if not v or v<0 then info="Invalid number";return end
  if edit=="cap" then
    -- Enter 0 to restore automatic cap from detected structure.
    c.autoBurnCeiling=math.floor(v*100+0.5)/100
    save();info="AUTO ceiling "..(v==0 and "DETECTED MAX" or n(v,2))
  elseif edit=="burn" then
    if latched then info="ALARM LATCHED";return end
    local ok,r=burn(v)
    if ok then mode="MANUAL";info="Manual burn "..n(r,2)
    else info="Burn error: "..tostring(r) end
  end
end
local function inputLoop()
  while active do
    local ev,a,b,d=os.pullEvent()
    if edit then
      if ev=="char" and a:match("[0-9%.]") and #buffer<15 then buffer=buffer..a
      elseif ev=="key" and a==keys.backspace then buffer=buffer:sub(1,-2)
      elseif ev=="key" and a==keys.escape then edit=nil;buffer="";info="Edit cancelled"
      elseif ev=="key" and (a==keys.enter or a==keys.numPadEnter) then
        setTyped();edit=nil;buffer=""
      end
    elseif ev=="char" then
      if a=="q" then active=false;return
      elseif a=="b" then edit="burn";buffer=tostring(current.burn or 0);info="Enter burn: "..buffer
      elseif a=="c" then edit="cap";buffer=tostring(c.autoBurnCeiling);info="Enter ceiling (0=automatic): "..buffer
      else
        local m={["-"]="minus",["+"]="plus",["="]="plus",
          m="manual",f="fe",p="sps",s="scram",r="start"}
        if m[a] then command(m[a]) end
      end
      if edit then info="Editing "..edit..": "..buffer.." (Enter saves, Esc cancels)" end
    elseif ev=="monitor_touch" and a==names.monitor then
      for _,v in ipairs(buttons) do
        if d==v.y and b>=v.x and b<=v.last then command(v.id);break end
      end
    elseif ev=="peripheral" or ev=="peripheral_detach" then discover()
    end
    display()
  end
end
local function monitorLoop()
  while active do
    if not names.reactor or not peripheral.isPresent(names.reactor) or
        (c.requireTurbine and not names.turbine) then discover() end
    current=read()
    local good,reason=safety(current)
    if good then recentValid=recentValid+1 else recentValid=0 end
    if not good and current.on~=false then trip(reason) end
    if latched and current.on==true then trip(alarm) end
    if good and not latched then auto(current) end
    if current.safeCap==nil then current.safeCap=safeCap(current) end
    current.limit=bottleneck(current)
    history(current)
    display()
    sleep(math.max(0.2,c.sampleSeconds))
  end
end
local ok,err=xpcall(function() parallel.waitForAny(monitorLoop,inputLoop) end,
  function(e) return tostring(e) end)
if names.reactor and peripheral.isPresent(names.reactor) then
  pcall(peripheral.call,names.reactor,"scram")
end
redstoneAlarm(not ok or latched)
screen.setBackgroundColor(colors.black);screen.setTextColor(colors.white)
screen.clear();screen.setCursorPos(1,1)
print(ok and "Stopped; SCRAM attempted." or ("ERROR: "..tostring(err).." (SCRAM attempted)"))
