-- READ-ONLY peripheral inventory and Mekanism telemetry report.
-- Run after enabling wired modems on all relevant blocks.
local path="/cc-mekanism/probe.txt"
if not fs.exists("/cc-mekanism") then fs.makeDir("/cc-mekanism") end
local f=assert(fs.open(path,"w"))
local function out(msg) msg=tostring(msg); print(msg);f.writeLine(msg) end
local selected={
  "isFormed","getLength","getWidth","getHeight","getFuelAssemblies",
  "getFuelSurfaceArea","getBoilEfficiency","getBurnRate","getActualBurnRate","getMaxBurnRate",
  "getTemperature","getDamagePercent","getCoolantFilledPercentage",
  "getHeatedCoolantFilledPercentage","getWasteFilledPercentage",
  "getFuelFilledPercentage","getHeatingRate","isForceDisabled",
  "canSeeSun","getPeakProductionRate","getProductionRate",
  "getInput","getOutput","getInputNeeded","getOutputNeeded",
  "getFlowRate","getMaxFlowRate","getLastSteamInputRate",
  "getSteamFilledPercentage","getEnergyFilledPercentage","getProductionRate",
  "getMaxProduction","getMaxWaterOutput","getWaterFilledPercentage",
  "getProcessRate","getInputFilledPercentage","getOutputFilledPercentage",
  "getCoils","getBlades","getCondensers","getVents","getDispersers",
  "getFuelCapacity","getCoolantCapacity","getWasteCapacity","getSteamCapacity",
  "getInputCapacity","getOutputCapacity","getMaxProduction",
  "getLastInput","getLastOutput","getBoilCapacity",
  "getStored","getStoredGas","getStoredChemical","getCapacity",
  "getTankCapacity","getFilledPercentage"
}
local names=peripheral.getNames()
table.sort(names)
out("CC:Tweaked + Mekanism device audit")
out("Peripherals detected: "..#names)
for _,name in ipairs(names) do
  out("")
  out("["..name.."] "..tostring(peripheral.getType(name)))
  local ok,methods=pcall(peripheral.getMethods,name)
  if ok and type(methods)=="table" then
    local set={}
    for _,m in ipairs(methods) do set[m]=true end
    table.sort(methods)
    out("Methods: "..table.concat(methods,", "))
    for _,method in ipairs(selected) do
      if set[method] then
        local good,result=pcall(peripheral.call,name,method)
        local v=good and textutils.serialize(result) or ("ERR "..tostring(result))
        out("  "..method.." = "..v)
      end
    end
  else
    out("ERROR: Cannot read peripheral methods")
  end
end
f.close()
print("")
print("Saved: "..path)
