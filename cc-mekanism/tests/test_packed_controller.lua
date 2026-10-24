-- Verify packed distribution is lossless and in sync with readable source.
-- The generated payload runs from RAM; no extra 97KB source file on CC disk.
local f=assert(io.open("cc-mekanism/controller.lua","rb"))
local original=f:read("*a")
f:close()
CC_MEKANISM_PAYLOAD_TEST=true
local packed=assert(loadfile("cc-mekanism/controller.packed.lua"))()
CC_MEKANISM_PAYLOAD_TEST=nil
assert(type(packed)=="string","packed runner must return source under test flag")
assert(#packed==#original,"decoded controller source length changed")
assert(packed==original,"packed controller does not match readable Github source")
local launcher=assert(io.open("cc-mekanism/controller-launcher.lua","rb"))
local text=launcher:read("*a")
launcher:close()
assert(text:find("/cc-mekanism/controller.packed.lua",1,true),
  "launcher must find packed controller path")
print("packed controller checksum and source parity: OK ("..#packed.." bytes)")
