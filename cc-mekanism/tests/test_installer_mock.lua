-- Test the REAL installer under constrained CC:Tweaked disk capacities.
-- No network or actual peripheral required. Uses local repo source files.
local hostRead=assert(io.open)
local realPrint=print
local filesOnHost={}
for _,name in ipairs({"optimizer_math.lua","thermal_model.lua",
                       "controller.packed.lua","controller-launcher.lua",
                       "probe.lua","monitor-test.lua"}) do
  local f=assert(io.open("cc-mekanism/"..name,"rb"))
  filesOnHost[name]=f:read("*a")
  f:close()
  assert(#filesOnHost[name]>100)
end
local runSource=assert(loadfile("cc-mekanism/install.lua"))
local disk,capacity,answer,prompts=nil,nil,nil,nil
local function used()
  local n=0
  for _,v in pairs(disk) do n=n+#v end
  return n
end
local function newDisk(allowed,yes)
  disk={}
  capacity=allowed
  answer=yes and "CLEAN" or ""
  prompts=0
  _G.fs={}
  function fs.exists(path) return path=="/cc-mekanism" or disk[path]~=nil end
  function fs.isDir(path) return path=="/cc-mekanism" end
  function fs.makeDir() end
  function fs.getFreeSpace() return math.max(0,capacity-used()) end
  function fs.getSize(path) return #(disk[path] or "") end
  function fs.list()
    local result={}
    for path in pairs(disk) do
      result[#result+1]=path:match("[^/]+$")
    end
    table.sort(result)
    return result
  end
  function fs.delete(path) disk[path]=nil end
  function fs.move(a,b)
    assert(disk[a]~=nil,"missing source: "..a)
    assert(disk[b]==nil,"destination exists: "..b)
    disk[b]=disk[a]
    disk[a]=nil
  end
  function fs.open(path,mode)
    if mode=="r" and disk[path]==nil then return nil end
    if mode=="w" then disk[path]="" end
    if mode=="a" and disk[path]==nil then disk[path]="" end
    return {
      readAll=function() return disk[path] end,
      write=function(body)
        local output=disk[path]..tostring(body)
        if used()-#disk[path]+#output>capacity then
          error("Out of space",0)
        end
        disk[path]=output
      end,
      close=function() end
    }
  end
  _G.read=function()
    prompts=prompts+1
    return answer
  end
  _G.write=function() end
  _G.http={
    get=function(url)
      local name=url:match("/([^/?]+)%?v=")
      assert(filesOnHost[name],"unexpected HTTP file "..tostring(name))
      return {
        getResponseCode=function() return 200 end,
        readAll=function() return filesOnHost[name] end,
        close=function() end
      }
    end
  }
end
local oldEpoch=os.epoch
os.epoch=function() return 1234567890 end

-- Clean only older history files by explicit consent, not settings or
-- unrelated user data. Test old controller safely replaced in full.
newDisk(325000,true)
local oldController=string.rep("-",92000)
local savedSettings="{autoBurnCeiling=550,fluxLimitFE=22000000}"
disk["/cc-mekanism/controller.lua"]=oldController
disk["/cc-mekanism/settings"]=savedSettings
disk["/cc-mekanism/history_v4.csv"]=string.rep("H",100000)
disk["/cc-mekanism/history_v4_stable.csv"]=string.rep("H",75000)
local succeeded,errorText=pcall(runSource)
assert(succeeded,tostring(errorText))
assert(prompts==1,"low disk prompts once for explicit consent")
assert(disk["/cc-mekanism/settings"]==savedSettings,"settings preserved")
assert(disk["/cc-mekanism/controller.lua"]==filesOnHost["controller-launcher.lua"],
  "installed tiny launcher after safely staging packed source")
assert(disk["/cc-mekanism/controller.packed.lua"]==filesOnHost["controller.packed.lua"],
  "correct compressed controller installed and staged")
assert(disk["/cc-mekanism/history_v4.csv"]==nil,
  "one older history freed after confirmation")
assert(disk["/cc-mekanism/history_v4_stable.csv"]~=nil,
  "preserve other historical logs if sufficient space")
assert(not disk["/cc-mekanism/controller.lua.new"],"no leftover staging files")

-- Refusing cleanup must NOT replace the old controller or erase settings.
newDisk(325000,false)
disk["/cc-mekanism/controller.lua"]=oldController
disk["/cc-mekanism/settings"]=savedSettings
disk["/cc-mekanism/history_v4.csv"]=string.rep("H",100000)
disk["/cc-mekanism/history_v4_stable.csv"]=string.rep("H",75000)
local rejected=pcall(runSource)
assert(not rejected,"refusing cleanup must stop safely")
assert(prompts==1)
assert(disk["/cc-mekanism/controller.lua"]==oldController,
  "refused cleanup must preserve previous controller")
assert(disk["/cc-mekanism/settings"]==savedSettings)
assert(disk["/cc-mekanism/history_v4.csv"]~=nil)
assert(disk["/cc-mekanism/history_v4_stable.csv"]~=nil)

-- Exact 2026-10-24 screenshot: 78,827 bytes free but a full readable
-- controller needs ~101,003 bytes of duplicated staging space.
-- Compressed 72KB payload MUST install without deleting user histories
-- or demanding space that does not exist.
newDisk(92000+#savedSettings+78827,false)
disk["/cc-mekanism/controller.lua"]=oldController
disk["/cc-mekanism/settings"]=savedSettings
local screenshotOkay,screenshotError=pcall(runSource)
assert(screenshotOkay,"78,827 B free must install compressed: "..tostring(screenshotError))
assert(prompts==0,"no history cleanup is required with packed installation")
assert(disk["/cc-mekanism/controller.lua"]==filesOnHost["controller-launcher.lua"])
assert(disk["/cc-mekanism/controller.packed.lua"]==filesOnHost["controller.packed.lua"])
assert(disk["/cc-mekanism/settings"]==savedSettings)

-- Fully up-to-date installation should not duplicate large files,
-- even when less than 4K remains free.
local total=#savedSettings
for _,body in pairs(filesOnHost) do total=total+#body end
newDisk(total+2000,false)
disk["/cc-mekanism/settings"]=savedSettings
for name,body in pairs(filesOnHost) do
  local installed=name=="controller-launcher.lua" and "controller.lua" or name
  disk["/cc-mekanism/"..installed]=body
end
local unchanged,unchangedError=pcall(runSource)
assert(unchanged,tostring(unchangedError))
assert(prompts==0,"no prompt or extra space needed for identical files")
assert(disk["/cc-mekanism/settings"]==savedSettings)

os.epoch=oldEpoch
print("disk-aware installer scenarios: OK")
