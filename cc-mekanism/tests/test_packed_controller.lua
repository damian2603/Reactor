-- Verify that the installed RAM-only patch produces the exact readable
-- controller source while retaining the older checksummed LZW base payload.
local f=assert(io.open("cc-mekanism/controller.lua","rb"))
local readable=f:read("*a")
f:close()
CC_MEKANISM_PAYLOAD_TEST=true
local base=assert(loadfile("cc-mekanism/controller.packed.lua"))()
local current=assert(loadfile("cc-mekanism/controller-launcher.lua"))()
CC_MEKANISM_PAYLOAD_TEST=nil
assert(type(base)=="string" and type(current)=="string")
assert(#base<#readable,"packed base expected to precede steam update")
assert(#current==#readable,"runtime patch source length mismatch")
assert(current==readable,
  "RAM-only controller patch MUST reproduce readable Github source exactly")
local ok,why=load(current,"@cc-mekanism/controller.lua","t",_ENV)
assert(ok,why)
print("packed base + RAM-only turbine patch parity: OK ("..#current.." bytes)")
