-- Installer/updater for Project Infinity CC:Tweaked controller.
-- Run: wget run https://raw.githubusercontent.com/damian2603/Reactor/main/cc-mekanism/install.lua
local BASE="https://raw.githubusercontent.com/damian2603/Reactor/main/cc-mekanism/"
local DIR="/cc-mekanism"
if not http then error("HTTP is disabled in CC:Tweaked config") end
if not fs.exists(DIR) then fs.makeDir(DIR) end
local sources={"optimizer_math.lua","controller.lua","probe.lua","monitor-test.lua"}
for _,name in ipairs(sources) do
  print("Downloading "..name.." ...")
  local url=BASE..name.."?v="..tostring(os.epoch("utc"))
  local ok,res,err=pcall(http.get,url)
  if not ok or not res then error("Cannot download "..name..": "..tostring(err or res)) end
  local status=res.getResponseCode and res.getResponseCode() or 200
  local body=res.readAll()
  res.close()
  if status~=200 or type(body)~="string" or #body<100 then
    error("Invalid download "..name..": HTTP "..tostring(status))
  end
  local dest=DIR.."/"..name
  local tmp=dest..".new"
  local f=assert(fs.open(tmp,"w"))
  f.write(body)
  f.close()
  if fs.exists(dest) then fs.delete(dest) end
  fs.move(tmp,dest)
  print("OK: "..dest.." ("..#body.." bytes)")
end
print("")
print("Installation complete. Existing settings and history preserved.")
print("1) Test monitor: cc-mekanism/monitor-test")
print("2) Run: cc-mekanism/probe")
print("3) Run: cc-mekanism/controller")
print("For README: https://github.com/damian2603/Reactor/tree/main/cc-mekanism")
