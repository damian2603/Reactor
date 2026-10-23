/* Reactor Studio 4.2: shared solid-fission FE/t optimizer for browser and Web Workers. Project Infinity 0.1, NC Neoteric 1.20. */
(function fePatch(){
'use strict';
const isEnergy=p=>p&&p.goal==='energy';
const oldScore=v3SearchValue;
v3SearchValue=function(s,p){
 if(!isEnergy(p))return oldScore(s,p);
 const base=oldScore(s,p);
 return s.safe?1000000+s.energy*10+Math.max(0,-s.net)*0.002-s.fuelCells*.01:base;
};
const oldRank=safeRank;
safeRank=function(s,p){return isEnergy(p)?(s.safe?s.energy*1000+Math.max(0,-s.net)*.001:-Infinity):oldRank(s,p)};
const oldStats=statsForSearch;
statsForSearch=function(g,dims,p){
 if(!isEnergy(p))return oldStats(g,dims,p);
 const r=oldStats(g,dims,{...p,machines:0,autoMachines:false});
 const reserve=Math.max(0,p.reserve||0);
 r.machines=0;r.radiHeat=0;r.heat=r.baseHeat;r.net=r.heat-r.cooling;r.excess=-r.net;r.perMinute=0;
 r.fullHeat=p.heat*(r.heatMult+r.modHeat);r.fullNet=r.fullHeat-r.cooling;
 r.safe=r.layoutOK&&r.fuelCells>0&&r.badMods.length===0&&r.net<=-reserve+1e-7&&(!p.safeAtFull||r.fullNet<=-reserve+1e-7);
 return r;
};
const oldRandom=randomCore;
function energySeed(dims,p){
 const [w,h,d]=dims,N=w*h*d,g=Array(N).fill('.'),geo=geometry(...dims);
 const maximum=Math.max(1,Math.min(p.maxFuel||1,N-1,18));
 const target=rand()<.57?maximum:randomInt(Math.max(1,Math.ceil(maximum*.4)),maximum);
 const cluster=rand()<.56;
 for(let step=0;step<target;step++){
  const candidates=[];
  for(let i=0;i<N;i++){
   if(g[i]!=='.')continue;
   const [x,y,z]=geo.coords[i];
   let adjacent=0,distant=0;
   for(const j of geo.nb[i])if(j>=0&&g[j]==='F')adjacent++;
   for(const [dx,dy,dz] of DIR){
    const nx=x+2*dx,ny=y+2*dy,nz=z+2*dz;
    if(nx>=0&&ny>=0&&nz>=0&&nx<w&&ny<h&&nz<d&&g[idx(nx,ny,nz,w,d)]==='F')distant++;
   }
   candidates.push({i,score:rand()*4+(cluster?adjacent*4+distant*1.5:-adjacent*3+distant*.75)});
  }
  if(!candidates.length)break;
  candidates.sort((a,b)=>b.score-a.score);
  g[pick(candidates.slice(0,Math.min(8,candidates.length))).i]='F';
 }
 const mods=Math.min(N-target,Math.round(target*(.5+rand()*1.2)));
 for(let n=0;n<mods;n++){
  const options=[];
  for(let i=0;i<N;i++)if(g[i]==='.'){
   const touch=geo.nb[i].filter(j=>j>=0&&g[j]==='F').length;
   if(touch)options.push({i,score:rand()*3+touch*3});
  }
  if(!options.length)break;
  options.sort((a,b)=>b.score-a.score);
  g[pick(options.slice(0,Math.min(9,options.length))).i]='M';
 }
 if(rand()<.07){
  const possible=shuffle(geo.triads).filter(([f,m,c])=>g[f]==='F'&&g[m]==='M'&&g[c]==='.');
  if(possible.length)g[pick(possible)[2]]='I';
 }
 return g;
}
randomCore=function(dims,p){return isEnergy(p)?energySeed(dims,p):oldRandom(dims,p)};
const oldMutate=mutateCore;
function energyMutate(parent,dims,p,strength){
 const g=coreOnly(parent),geo=geometry(...dims),steps=strength>1?randomInt(2,6):randomInt(1,3);
 for(let n=0;n<steps;n++){
  const fs=[],ms=[],free=[],ics=[];
  g.forEach((t,i)=>{if(t==='F')fs.push(i);else if(t==='M')ms.push(i);else if(t==='I')ics.push(i);else free.push(i)});
  const mode=rand();
  if(mode<.23&&fs.length<p.maxFuel&&free.length){
   const weighted=free.map(i=>({i,score:rand()*4+geo.nb[i].filter(j=>j>=0&&g[j]==='F').length*(rand()<.6?4:-2)}));
   weighted.sort((a,b)=>b.score-a.score);
   g[pick(weighted.slice(0,Math.min(8,weighted.length))).i]='F';
  }else if(mode<.39&&fs.length>1){g[pick(fs)]='.'}
  else if(mode<.62&&fs.length&&free.length){g[pick(fs)]='.';g[pick(free)]='F'}
  else if(mode<.83){
   const options=free.filter(i=>geo.nb[i].some(j=>j>=0&&g[j]==='F'));
   if(options.length)g[pick(options)]='M';else if(ms.length)g[pick(ms)]='.';
  }else if(ms.length)g[pick(ms)]='.';
  else if(ics.length)g[pick(ics)]='.';
 }
 while(g.filter(x=>x==='F').length>p.maxFuel){const fs=[];g.forEach((t,i)=>{if(t==='F')fs.push(i)});g[pick(fs)]='.'}
 removeDangling(g,dims);
 return g.includes('F')?g:energySeed(dims,p);
}
mutateCore=function(parent,dims,p,strength){return isEnergy(p)?energyMutate(parent,dims,p,strength):oldMutate(parent,dims,p,strength)};
const oldTune=v3CoreTune;
v3CoreTune=function(a,dims,p){return isEnergy(p)?energyMutate(a,dims,p,1):oldTune(a,dims,p)};
if(typeof document==='undefined')return;
const oldParams=getParams;
getParams=function(){const p=oldParams();if(isEnergy(p)){p.machines=0;p.autoMachines=false}return p};
const oldRemember=rememberCandidate;
rememberCandidate=function(c,p){
 if(!isEnergy(p))return oldRemember(c,p);
 if(!c)return null;
 const copy=()=>({g:c.g.slice(),s:c.s,score:merit(c.s,p)});
 if(c.s.safe){
  if(!state.bestSafe||safeRank(c.s,p)>safeRank(state.bestSafe.s,p)){state.bestSafe=copy();return 'safe'}
 }else if(c.s.layoutOK&&c.s.fuelCells>0){
  if(!state.bestNear||merit(c.s,p)>merit(state.bestNear.s,p)){state.bestNear=copy();return 'near'}
 }
 return null;
};
const oldShow=showBest;
showBest=function(){
 if(!isEnergy(getParams()))return oldShow();
 const good=state.bestSafe,near=state.bestNear;
 const f=c=>c?`${fmt(c.s.energy)} FE/t · ${c.s.fuelCells} Fuel Cells · Net ${fmt(c.s.net)} H/t`:'brak';
 $('bestSummary').innerHTML=`<span class="good">Najlepszy stabilny:</span> <b>${f(good)}</b><br><span class="warntext">Kandydat wymagający chłodzenia:</span> ${f(near)}`;
 $('applyBest').disabled=!good;$('applyNear').disabled=!near;
};
const oldArchive=v3ArchiveDisplay;
v3ArchiveDisplay=function(){
 if(!isEnergy(getParams()))return oldArchive();
 const el=$('v3Archive');if(!el)return;
 if(!V3.archive.length){el.innerHTML='<div class="hint">Uruchom optymalizację FE/t, aby zobaczyć różne stabilne reaktory.</div>';return}
 el.replaceChildren();
 V3.archive.slice(0,12).forEach((entry,i)=>{
  const btn=document.createElement('button');btn.className='v3result';btn.title='Wczytaj wariant';
  const label=document.createElement('strong');label.textContent=`#${i+1} · ${fmt(entry.s.energy)} FE/t`;
  const desc=document.createElement('span');desc.textContent=`${entry.s.fuelCells} Fuel Cells · ${entry.s.mods} Moderatorów · Cooling ${fmt(entry.s.cooling)} H/t · Net ${fmt(entry.s.net)} H/t`;
  btn.append(label,desc);btn.onclick=()=>{if(state.opt)return;applyStored(entry)};el.append(btn);
 });
};
const oldCheck=releaseCheck;
releaseCheck=function(){const data=oldCheck();if(isEnergy(data.p))data.fatal=data.fatal.filter(x=>x!=='Brak czynnej Irradiation Line');return data};
const oldApply=applyStored;
applyStored=function(c){oldApply(c);if(c&&isEnergy(getParams()))info(`Wczytano projekt energetyczny: ${fmt(c.s.energy)} FE/t, ${c.s.fuelCells} Fuel Cells, Net ${fmt(c.s.net)} H/t. Sprawdź w grze.`)};
const oldUpdate=updateMetrics;
updateMetrics=function(){
 const r=oldUpdate();
 if(isEnergy(getParams()))$('details').insertAdjacentHTML('beforeend','<br><b>Tryb FE/t:</b> 0 Irradiation Lines i 0 Irradiatorów są prawidłowe. Energia liczona dla wychłodzonego reaktora.');
 return r;
};
function finished(){
 if(!isEnergy(getParams())||!state.bestSafe)return;
 if($('status').textContent.includes('Błąd'))return;
 const b=state.bestSafe.s;
 info(`Optymalizacja FE/t zakończona: ${fmt(b.energy)} FE/t · ${b.fuelCells} Fuel Cells · Cooling ${fmt(b.cooling)} H/t · Net ${fmt(b.net)} H/t. ${V3.archive.length} zapisanych projektów. Wynik należy potwierdzić w grze.`);
}
const oldLocalRun=runOptimizerV3;
runOptimizerV3=async function(){await oldLocalRun();finished()};
const oldWorkerRun=runOptimizerWorkers;
runOptimizerWorkers=async function(){await oldWorkerRun();finished()};
let savedMachines=null,savedModeration=null;
const goal=$('goal');
function changeGoal(){
 if(state.opt)return;
 const active=goal.value==='energy';
 if(active){
  if(savedMachines===null)savedMachines=Number($('machineCount').value)||0;
  if(savedModeration===null)savedModeration=num('moderation',0);
  $('machineCount').value='0';$('autoMachines').checked=false;state.wall=wallsForDims(state.dims,0);
  state.trial=0;$('trialCount').value='0';
  if(num('moderation',0)===0){$('moderation').value='100';$('modLabel').textContent='100%'}
 }else if(savedMachines!==null){
  const m=savedMachines;savedMachines=null;$('machineCount').value=String(m);
  state.wall=wallsForDims(state.dims,m);state.trial=m;$('trialCount').value=String(m);
  if(savedModeration!==null){$('moderation').value=String(savedModeration);$('modLabel').textContent=fmt(savedModeration)+'%';savedModeration=null}
 }
 $('machineCount').disabled=active;$('autoMachines').disabled=active;
 state.bestSafe=null;state.bestNear=null;V3.archive=[];V3.seen.clear();
 updateAll();showBest();v3ArchiveDisplay();
 if(active)info('Tryb FE/t: optymalizacja rdzenia energetycznego bez obowiązkowych Irradiatorów. Moderacja 100% zwykle zwiększa FE; ustawienie można zmienić.');
}
goal.addEventListener('change',changeGoal);
if(goal.value==='energy')changeGoal();
})();
