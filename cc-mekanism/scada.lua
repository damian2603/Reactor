-- Project Infinity SCADA: read-only SPS diagnostics dashboard
-- Run: wget run https://raw.githubusercontent.com/damian2603/Reactor/main/cc-mekanism/scada.lua
-- Independent of controller.lua; never writes to reactor or energy systems.
local function has(n,m)
 local ok,v=pcall(peripheral.getMethods,n)
 if not ok or type(v)~="table" then return false end
 for _,x in ipairs(v) do if x==m then return true end end
 return false
end
local function find(a,b)
 local found={}
 for _,n in ipairs(peripheral.getNames()) do
  if has(n,a) and (not b or has(n,b)) then found[#found+1]=n end
 end
 table.sort(found)
 return #found==1 and found[1] or nil,#found
end
local function call(n,m)
 if not n then return nil end
 local ok,v=pcall(peripheral.call,n,m)
 if ok then return v end
end
local function number(v)
 if type(v)=="table" then v=v.amount or v.value or v.energy end
 return tonumber(v)
end
local function val(n,m) return number(call(n,m)) end
local function fmt(v)
 if not v then return "--" end
 if math.abs(v)>=1e9 then return string.format("%.2fG",v/1e9) end
 if math.abs(v)>=1e6 then return string.format("%.2fM",v/1e6) end
 if math.abs(v)>=1e3 then return string.format("%.1fk",v/1e3) end
 return string.format("%.3f",v)
end
local function pct(v) return v and string.format("%.1f%%",v*100) or "--" end
local monitor=peripheral.find("monitor") or term.current()
if monitor.setTextScale then monitor.setTextScale(0.5) end
local sps,spsCount=find("getProcessRate","getInputFilledPercentage")
local reactor,reactorCount=find("getBurnRate","getActualBurnRate")
local turbine=find("getMaxFlowRate","getProductionRate")
local matrix=find("getLastInput","getLastOutput")
local history,alarms={},{}
local page=1
local running=true
local function sample()
 local t={ts=os.epoch("utc")/1000}
 t.rate=val(sps,"getProcessRate")
 t.input=val(sps,"getInputFilledPercentage")
 t.output=val(sps,"getOutputFilledPercentage")
 t.inputAmount=val(sps,"getInput")
 t.inputCapacity=val(sps,"getInputCapacity")
 t.energy=val(sps,"getEnergy")
 t.maxEnergy=val(sps,"getMaxEnergy")
 t.burn=val(reactor,"getBurnRate")
 t.actual=val(reactor,"getActualBurnRate")
 t.temp=val(reactor,"getTemperature")
 t.coolant=val(reactor,"getCoolantFilledPercentage")
 t.waste=val(reactor,"getWasteFilledPercentage")
 t.damage=val(reactor,"getDamagePercent")
 t.steam=val(turbine,"getSteamFilledPercentage")
 t.power=val(turbine,"getProductionRate")
 t.flow=val(turbine,"getFlowRate")
 t.matrixIn=val(matrix,"getLastInput")
 t.matrixOut=val(matrix,"getLastOutput")
 t.solarCount,t.solarActive,t.solarRate=0,0,0
 for _,n in ipairs(peripheral.getNames()) do
  if has(n,"canSeeSun") and has(n,"getPeakProductionRate") and has(n,"getProductionRate") then
   t.solarCount=t.solarCount+1
   local r=val(n,"getProductionRate")
   if r and r>0 then t.solarActive=t.solarActive+1 end
   t.solarRate=t.solarRate+(r or 0)
  end
 end
 if #history>0 then
  local old=history[#history]
  local dt=t.ts-old.ts
  if dt>0 and t.inputAmount and old.inputAmount then t.inputTrend=(t.inputAmount-old.inputAmount)/dt end
 end
 history[#history+1]=t
 if #history>180 then table.remove(history,1) end
 alarms={}
 if not sps then alarms[#alarms+1]="SPS peripheral missing/ambiguous ("..spsCount..")" end
 if not reactor then alarms[#alarms+1]="Reactor peripheral missing/ambiguous ("..reactorCount..")" end
 if t.output and t.output>0.90 then alarms[#alarms+1]="Antimatter output near full" end
 if t.waste and t.waste>0.70 then alarms[#alarms+1]="Fission waste buffer high" end
 if t.coolant and t.coolant<0.85 then alarms[#alarms+1]="Reactor coolant below 85%" end
 if t.solarCount==0 then alarms[#alarms+1]="Solar activators not visible" end
 return t
end
local function draw(t)
 local w,h=monitor.getSize()
 local function line(y,s,fg,bg)
  if y<1 or y>h then return end
  monitor.setCursorPos(1,y)
  monitor.setBackgroundColor(bg or colors.black)
  monitor.setTextColor(fg or colors.white)
  s=tostring(s)
  monitor.write(s:sub(1,w)..string.rep(" ",math.max(0,w-#s)))
 end
 monitor.setBackgroundColor(colors.black)
 monitor.clear()
 line(1," PROJECT INFINITY  |  SCADA  |  READ ONLY ",colors.black,colors.cyan)
 line(2," SPS  REACTOR  TURBINE  ALARMS  |  page "..page,colors.lightBlue)
 if page==1 then
  line(4,"ANTIMATTER OUTPUT",colors.lime)
  line(5," "..fmt(t.rate).." mB/t   |   "..fmt((t.rate or 0)*20*60).." mB/min",colors.white)
  line(7,"Polonium buffer "..pct(t.input).."  | AM buffer "..pct(t.output))
  line(8,"Solar "..t.solarActive.."/"..t.solarCount.."  capacity "..fmt(t.solarRate).."/t")
  line(9,"SPS energy stored "..fmt(t.energy).." / "..fmt(t.maxEnergy))
  line(10,"Input change "..fmt(t.inputTrend).." mB/s")
  line(12,"Production history (last "..#history.." samples)",colors.cyan)
  local graphY=13
  local gh=math.max(0,math.min(7,h-graphY-2))
  if gh>0 and #history>1 then
   local max=0
   for _,x in ipairs(history) do max=math.max(max,x.rate or 0) end
   max=math.max(max,0.00001)
   for x=1,math.min(w,#history) do
    local v=history[#history-math.min(w,#history)+x].rate or 0
    local level=math.floor(v/max*gh+0.5)
    for y=0,level-1 do
     monitor.setCursorPos(x,graphY+gh-1-y)
     monitor.setTextColor(colors.lime)
     monitor.write("|")
    end
   end
  end
 elseif page==2 then
  line(4,"FISSION REACTOR",colors.cyan)
  line(6,"Burn "..fmt(t.burn).." | actual "..fmt(t.actual).." mB/t")
  line(7,"Temperature "..fmt(t.temp).." K")
  line(8,"Coolant "..pct(t.coolant).." | waste "..pct(t.waste))
  line(9,"Damage "..fmt(t.damage).."%")
  line(11,"Controller operates separately. No commands sent.",colors.yellow)
 elseif page==3 then
  line(4,"TURBINE / ENERGY",colors.cyan)
  line(6,"Production "..fmt(t.power).." J/t")
  line(7,"Steam "..pct(t.steam).." | flow "..fmt(t.flow))
  line(9,"Matrix input "..fmt(t.matrixIn).." J/t")
  line(10,"Matrix output "..fmt(t.matrixOut).." J/t")
  line(12,"Flux Point limit is MANUAL.",colors.yellow)
 elseif page==4 then
  line(4,"DIAGNOSTICS / ALARMS",colors.cyan)
  if #alarms==0 then line(6,"No basic telemetry warnings",colors.lime) end
  for i,a in ipairs(alarms) do line(5+i,"! "..a,colors.orange) end
  line(math.min(h-3,13),"No claims of optimality without FE input data.",colors.yellow)
 end
 line(h-1,"Touch bottom: 1 SPS | 2 REACTOR | 3 FE | 4 ALARMS",colors.black,colors.lightGray)
 line(h,"[1] SPS    [2] REACTOR    [3] FE    [4] ALARMS",colors.black,colors.gray)
end
local last=sample()
local function poll()
 while running do
  last=sample()
  draw(last)
  sleep(2)
 end
end
local function events()
 while running do
  local e,a,x,y=os.pullEvent()
  if e=="monitor_touch" then
   local w,h=monitor.getSize()
   if y>=h-1 then page=math.min(4,math.max(1,math.floor((x-1)/math.max(1,w/4))+1)) end
  elseif e=="key" then
   if a==keys.one then page=1 elseif a==keys.two then page=2
   elseif a==keys.three then page=3 elseif a==keys.four then page=4
   elseif a==keys.q then running=false;return end
  elseif e=="peripheral" or e=="peripheral_detach" then
   sps,spsCount=find("getProcessRate","getInputFilledPercentage")
   reactor,reactorCount=find("getBurnRate","getActualBurnRate")
   turbine=find("getMaxFlowRate","getProductionRate")
   matrix=find("getLastInput","getLastOutput")
  end
  draw(last)
 end
end
parallel.waitForAny(poll,events)
monitor.setBackgroundColor(colors.black)
monitor.clear()
monitor.setCursorPos(1,1)
print("SCADA dashboard stopped")
