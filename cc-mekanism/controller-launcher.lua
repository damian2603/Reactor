-- Small launch entry point installed as /cc-mekanism/controller.lua.
-- Full readable source: github.com/damian2603/Reactor/blob/main/cc-mekanism/controller.lua
-- The payload is verified and expanded in RAM; no second 97KB file on disk.
local payload="/cc-mekanism/controller.packed.lua"
if not fs.exists(payload) then
  error("Missing "..payload.."; rerun the CC:Mekanism installer",0)
end
return dofile(payload)
