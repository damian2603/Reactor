-- Disk-aware installer/updater for Project Infinity CC:Tweaked.
-- Run: wget run https://raw.githubusercontent.com/damian2603/Reactor/main/cc-mekanism/install.lua
-- NEVER silently delete saved settings, old controllers or CSV history.
local BASE="https://raw.githubusercontent.com/damian2603/Reactor/main/cc-mekanism/"
local DIR="/cc-mekanism"
-- Download the packed controller first and only then install its tiny
-- launcher over the previous /cc-mekanism/controller.lua. This works even
-- when the CC disk has less than 100KB free and preserves the old program
-- until the verified compressed payload has been staged.
local SOURCES={
  {remote="optimizer_math.lua"},
  {remote="thermal_model.lua"},
  {remote="controller.packed.lua"},
  {remote="controller-launcher.lua",target="controller.lua"},
  {remote="probe.lua",optional=true},
  {remote="monitor-test.lua",optional=true}
}
local MIN_HEADROOM=4096
local OPTIONAL_DISK_RESERVE=16000 -- leave space for settings and controller logs

if not http then error("HTTP is disabled in CC:Tweaked config") end
if not fs.exists(DIR) then fs.makeDir(DIR) end

local function freeBytes()
  if not fs.getFreeSpace then return nil end
  local ok,v=pcall(fs.getFreeSpace,DIR)
  if ok and type(v)=="number" then return v end
  return nil -- unlimited filesystem or unsupported reporting
end
local function pretty(n)
  if type(n)~="number" then return "unlimited/unknown" end
  return tostring(n).." B ("..string.format("%.1f KiB",n/1024)..")"
end
local function fileSize(path)
  local ok,v=pcall(fs.getSize,path)
  return ok and type(v)=="number" and v or 0
end
local function oldHistory()
  local items={}
  for _,name in ipairs(fs.list(DIR)) do
    if name:match("^history.*%.csv$") and
        not fs.isDir(DIR.."/"..name) then
      local priority=name=="history_v5_thermal.csv" and 1 or 0
      items[#items+1]={path=DIR.."/"..name,name=name,
        size=fileSize(DIR.."/"..name),priority=priority}
    end
  end
  table.sort(items,function(a,b)
    if a.priority~=b.priority then return a.priority<b.priority end
    return a.size>b.size
  end)
  return items
end

local function makeRoom(target)
  local free=freeBytes()
  if not free or free>=target then return true end
  local entries=oldHistory()
  print("")
  print("LOW DISK SPACE: free "..pretty(free)..
    ", require ~"..pretty(target).." for safe update.")
  print("History CSV log files (settings and code are NEVER listed):")
  local total=0
  for _,e in ipairs(entries) do
    total=total+e.size
    print("  "..e.name.."  "..pretty(e.size))
  end
  if total==0 or free+total<target then
    print("Not enough old history logs to recover sufficient space.")
    print("Back up/delete other files manually or expand CC disk limit.")
    return false
  end
  print("Old log histories may contain useful diagnostics.")
  print("Type CLEAN to delete only as many listed CSV histories as")
  print("needed to complete the update (old versions first).")
  print("Press Enter to cancel. Settings, programs and")
  print("fe_trials.csv will be preserved.")
  write("> ")
  local reply=read()
  if reply~="CLEAN" then
    print("Cancelled. Existing files were not changed.")
    return false
  end
  for _,e in ipairs(entries) do
    if (freeBytes() or target)>=target then break end
    local ok,err=pcall(fs.delete,e.path)
    if not ok then
      print("Cannot remove "..e.name..": "..tostring(err))
      return false
    end
    print("Freed "..e.name.." ("..pretty(e.size)..")")
  end
  local now=freeBytes()
  if now and now<target then
    print("Still insufficient space: "..pretty(now))
    return false
  end
  return true
end

local function fetch(name)
  local url=BASE..name.."?v="..tostring(os.epoch("utc"))
  local ok,res,err=pcall(http.get,url)
  if not ok or not res then
    return nil,"HTTP failed for "..name..": "..tostring(err or res)
  end
  local status=res.getResponseCode and res.getResponseCode() or 200
  local success,body=pcall(res.readAll)
  pcall(res.close)
  if not success or status~=200 or type(body)~="string" or #body<100 then
    return nil,"Invalid download "..name.." (HTTP "..tostring(status)..")"
  end
  return body
end

local function install(name,body,target)
  local dest=DIR.."/"..(target or name)
  local tmp=dest..".new"
  -- Clean only a staging file left behind by an interrupted installer.
  if fs.exists(tmp) then pcall(fs.delete,tmp) end
  if fs.exists(dest) then
    local f=fs.open(dest,"r")
    if f then
      local original=f.readAll()
      f.close()
      if original==body then
        print("UNCHANGED "..name.." ("..pretty(#body)..")")
        return true
      end
    end
  end
  if not makeRoom(#body+MIN_HEADROOM) then
    return false,"Not enough free disk space to safely stage "..name
  end
  local ok,err=pcall(function()
    local f=assert(fs.open(tmp,"w"),"cannot create staging file")
    local written,writeError=pcall(f.write,body)
    local closed,closeError=pcall(f.close)
    if not written then error(writeError) end
    if not closed then error(closeError) end
    if fileSize(tmp)~=#body then error("incomplete staging write") end
  end)
  if not ok then
    pcall(fs.delete,tmp)
    return false,"Write failed for "..name..": "..tostring(err)
  end
  local moved,moveError=pcall(function()
    if fs.exists(dest) then fs.delete(dest) end
    fs.move(tmp,dest)
  end)
  if not moved then
    -- Preserve staging file for possible recovery if rename fails.
    return false,"Cannot activate "..name..": "..tostring(moveError)..
      ". Staging file kept at "..tmp
  end
  print("OK: "..dest.." ("..pretty(#body)..")")
  return true
end

print("Project Infinity CC:Mekanism updater")
print("Free disk: "..pretty(freeBytes()))
local optionalSkipped={}
for _,item in ipairs(SOURCES) do
  local name=item.remote
  print("Downloading "..name.."..."..
    (item.target and " -> "..item.target or ""))
  local body,err=fetch(name)
  if not body then
    if item.optional then
      print("SKIPPED optional "..name..": "..tostring(err))
      optionalSkipped[#optionalSkipped+1]=name
    else
      print("CORE UPDATE INCOMPLETE: "..tostring(err))
      error(err,0)
    end
  else
    local dest=DIR.."/"..(item.target or name)
    local free=freeBytes()
    local existing=fs.exists(dest)
    local identical=false
    if existing then
      local okRead,content=pcall(function()
        local f=assert(fs.open(dest,"r"))
        local data=f.readAll()
        f.close()
        return data
      end)
      identical=okRead and content==body
    end
    if item.optional and not identical and
        free and free<#body+MIN_HEADROOM+OPTIONAL_DISK_RESERVE then
      print("SKIPPED optional "..name.." (staging "..
        pretty(#body+MIN_HEADROOM).."; free "..pretty(free)..
        "; reserving "..pretty(OPTIONAL_DISK_RESERVE).." for core data)")
      optionalSkipped[#optionalSkipped+1]=name
    else
      local ok,reason=install(name,body,item.target)
      if not ok then
        if item.optional then
          print("SKIPPED optional "..name..": "..tostring(reason))
          optionalSkipped[#optionalSkipped+1]=name
        else
          print("CORE UPDATE INCOMPLETE: "..reason)
          print("Never start AUTO on a partially updated installation.")
          error(reason,0)
        end
      end
    end
  end
end
print("")
print("CORE INSTALLATION COMPLETE. Settings preserved.")
if #optionalSkipped>0 then
  print("Optional diagnostics not updated: "..table.concat(optionalSkipped,", "))
  print("They are NOT needed for running the reactor controller.")
end
print("Free disk after update: "..pretty(freeBytes()))
print("Run: cc-mekanism/controller")
print("Probe is optional: cc-mekanism/probe")
