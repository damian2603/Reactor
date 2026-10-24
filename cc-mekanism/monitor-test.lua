-- CC:Tweaked monitor troubleshooting for Project Infinity.
-- Run outside the controller: cc-mekanism/monitor-test
local HEADER="CC:Tweaked Monitor Diagnostic"
print(HEADER)
print("Listing peripherals visible to THIS computer...")
local all=peripheral.getNames()
table.sort(all)
local monitors={}
for _,name in ipairs(all) do
  local kinds={peripheral.getType(name)}
  local kindText=table.concat(kinds,", ")
  print(" - "..name.." ("..kindText..")")
  local isMonitor=false
  if peripheral.hasType then
    local ok,result=pcall(peripheral.hasType,name,"monitor")
    if ok and result then isMonitor=true end
  end
  if not isMonitor then
    for _,t in ipairs(kinds) do
      if t=="monitor" then isMonitor=true end
    end
  end
  if isMonitor then monitors[#monitors+1]=name end
end
print("Monitors detected: "..#monitors)
if #monitors==0 then
  print("")
  print("NO MONITOR FOUND.")
  print("Fix: place a Wired Modem on the monitor.")
  print("Connect it with Networking Cable to the computer's modem.")
  print("Right-click the modem to enable the peripheral connection.")
  print("Alternative: place the monitor directly against the computer.")
  print("Then rerun this diagnostic.")
  return
end
for _,name in ipairs(monitors) do
  local ok,err=pcall(function()
    local m=assert(peripheral.wrap(name),"Cannot wrap peripheral")
    m.setTextScale(0.5)
    local w,h=m.getSize()
    print("Found monitor "..name.." ("..w.." x "..h.." chars)")
    m.setBackgroundColor(colors.blue)
    m.setTextColor(colors.white)
    m.clear()
    m.setCursorPos(2,2)
    m.write("MONITOR CONNECTED!")
    m.setCursorPos(2,3)
    m.write(name)
    m.setCursorPos(2,4)
    m.write("Screen: "..w.." x "..h)
    m.setCursorPos(2,6)
    m.write("Run controller now")
  end)
  if not ok then print("ERROR on "..name..": "..tostring(err)) end
end
if #monitors>1 then
  print("")
  print("Multiple monitors: configure 'monitor' in /cc-mekanism/settings.")
  print("Example: monitor = \""..monitors[1].."\"")
end
print("")
print("Monitor test finished. If screen stayed black, verify cables/modems.")
