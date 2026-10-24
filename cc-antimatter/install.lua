-- Independent clean install; does NOT touch legacy /cc-mekanism files.
local root='/cc-antimatter'
local base='https://raw.githubusercontent.com/damian2603/Reactor/main/cc-antimatter/'
if not fs.exists(root) then fs.makeDir(root) end
print('Project Infinity: clean Antimatter Controller v1')
print('Legacy /cc-mekanism preserved. Stop the OLD controller first.')
for _,name in ipairs({'control.lua','main.lua'}) do
  local url=base..name..'?fresh='..tostring(os.epoch('utc'))
  local response,err=http.get(url)
  if not response then error('Download '..name..': '..tostring(err),0) end
  local code=response.readAll();response.close()
  if type(code)~='string' or #code<1000 then error('Invalid '..name,0) end
  local free=fs.getFreeSpace(root)
  if type(free)=='number' and free<#code+4096 then
    error('Insufficient storage: need '..(#code+4096)..' bytes, have '..free..
      '. Use a NEW CC computer or back up/remove OLD files manually.',0)
  end
  local dest=root..'/'..name
  local same=false
  if fs.exists(dest) then
    local f=fs.open(dest,'r')
    if f then same=f.readAll()==code;f.close() end
  end
  if not same then
    local tmp=dest..'.new'
    if fs.exists(tmp) then fs.delete(tmp) end
    local f=assert(fs.open(tmp,'w'),'Staging file error')
    f.write(code);f.close()
    assert(fs.getSize(tmp)==#code,'Incomplete download '..name)
    if fs.exists(dest) then fs.delete(dest) end
    fs.move(tmp,dest)
    print('Installed '..name..' ('..#code..' bytes)')
  else print('Unchanged '..name) end
end
print('Done. NEVER auto-starts reactor.')
print('Start: cc-antimatter/main')
print('Hardware Fission Logic Adapter strongly recommended.')
