/* Project Infinity 0.1 · fast large-scale FE/t search. Fuel and redstone only; layouts are revalidated in index.html. */
(function(){
'use strict';
const DIR=[[1,0,0],[-1,0,0],[0,1,0],[0,-1,0],[0,0,1],[0,0,-1]];
const cache=new Map();
function geom(dims){
 const key=dims.join('x');if(cache.has(key))return cache.get(key);
 const [w,h,d]=dims,N=w*h*d,neighbors=Array(N),parity=[[],[]];
 for(let i=0;i<N;i++){
  const x=i%w,z=Math.floor(i/w)%d,y=Math.floor(i/(w*d));
  parity[(x+y+z)&1].push(i);
  const adj=[];for(const [dx,dy,dz] of DIR){const a=x+dx,b=y+dy,c=z+dz;if(a>=0&&a<w&&b>=0&&b<h&&c>=0&&c<d)adj.push((b*d+c)*w+a)}
  neighbors[i]=adj;
 }
 const g={N,neighbors,parity};cache.set(key,g);return g;
}
function energyInfo(f,moderatorLinks,redstones,p){
 const moderation=Number(p.moderation)||0,heatBase=f+(moderatorLinks/3)*Math.max(.1,moderation);
 const heat=Number(p.heat)*heatBase,cooling=redstones*90,net=heat-cooling;
 const ratio=heat/Math.max(1,cooling);
 const hMult=ratio>0?Math.max(0,Math.round((Math.log10(ratio)/(1+Math.exp(Math.min(600,ratio)))+1)*100)/100):0;
 const storedZero=(.125**5)+.9999694824;
 const fe=Math.trunc(Number(p.power)*(f+moderatorLinks/6*moderation)*(hMult+storedZero-1));
 const fullHeat=Number(p.heat)*(f+moderatorLinks/3);
 const ok=net<=-(p.reserve||0)+1e-7&&(!p.safeAtFull||fullHeat-cooling<=-(p.reserve||0)+1e-7);
 return {ok,fe,net,heat,cooling,fullHeat};
}
async function search(data,shouldStop,isPaused){
 const {dims,p,iterations,index,limits}=data,[w,h,d]=dims,{N,neighbors,parity}=geom(dims);
 let seed=(data.rng>>>0)||0x9e3779b9;
 function rand(){seed^=seed<<13;seed^=seed>>>17;seed^=seed<<5;return(seed>>>0)/4294967296}
 const next=n=>Math.floor(rand()*n);
 const maxFuel=Math.max(1,Math.min(Math.floor(p.maxFuel)||1,parity[0].length,N));
 const redLimit=Math.max(0,Number(limits?.redstone??9999));
 const reserve=Math.max(0,Number(p.reserve)||0);
 let done=0,unique=0,highest=-Infinity,sent=0;const emittedBuckets=new Set();
 const workerYield=()=>new Promise(r=>setTimeout(r,0));
 const trials=Math.max(1,Math.floor(iterations));
 for(let it=0;it<trials;it++){
  if(shouldStop())break;
  while(isPaused()&&!shouldStop())await new Promise(r=>setTimeout(r,35));
  if(shouldStop())break;
  const pattern=parity[(it+index)&1],targetLow=Math.max(1,Math.floor(maxFuel*(it%11===0?.4:it%5===0?.65:.84)));
  const desired=it%10===0?maxFuel:targetLow+next(maxFuel-targetLow+1);
  const g=Array(N).fill('.'),cover=new Uint8Array(N),occupied=new Uint8Array(N);
  const selected=[];
  // Favor low-overlap coolant adjacency; this avoids redstone competing for the same air cells.
  for(let t=0;t<desired;t++){
   let best=-1,bestScore=-1e12;
   for(let j=0;j<24;j++){
    const c=pattern[next(pattern.length)];
    if(occupied[c])continue;
    let fresh=0;for(const a of neighbors[c])if(!cover[a])fresh++;
    const score=fresh*10+neighbors[c].length*.15+rand()*5;
    if(score>bestScore){bestScore=score;best=c}
   }
   if(best<0)break;
   occupied[best]=1;g[best]='F';selected.push(best);
   for(const a of neighbors[best])cover[a]++;
  }
  // Only sinks directly adjacent to a fuel cell are used. Every redstone sink is therefore valid.
  let sinkCount=0;
  for(let i=0;i<N;i++)if(!occupied[i]&&cover[i]&&sinkCount<redLimit){g[i]='redstone';sinkCount++}
  // Use some spare heat budget to add moderators which improve FE at positive moderation.
  // Avoid opposite fuel pairs across a moderator (which would raise cell heat multipliers).
  let moderatorLinks=0;
  if(p.moderation>.001){
   const places=[];for(let i=0;i<N;i++)if(g[i]==='redstone'){
    const adj=neighbors[i].filter(n=>g[n]==='F');
    if(!adj.length)continue;
    let opposite=false;
    const x=i%w,z=Math.floor(i/w)%d,y=Math.floor(i/(w*d));
    for(let axis=0;axis<3;axis++){
     const [a,b,c]=axis===0?[x-1,x+1,w]:axis===1?[y-1,y+1,h]:[z-1,z+1,d];
     if(a<0||b>=c)continue;
     const n1=axis===0?i-1:axis===1?i-w*d:i-w;
     const n2=axis===0?i+1:axis===1?i+w*d:i+w;
     if(g[n1]==='F'&&g[n2]==='F'){opposite=true;break}
    }
    if(!opposite)places.push({i,adj:adj.length});
   }
   places.sort((a,b)=>b.adj-a.adj||rand()-.5);
   let headroom=sinkCount*90-Number(p.heat)*selected.length-reserve;
   for(const place of places){
    const cost=90+Number(p.heat)*place.adj/3*Math.max(.1,Number(p.moderation));
    if(headroom<cost+Math.max(50,headroom*.2)||moderatorLinks>maxFuel*.7)continue;
    if(rand()>.7)continue;
    g[place.i]='M';sinkCount--;moderatorLinks+=place.adj;headroom-=cost;
   }
  }
  const info=energyInfo(selected.length,moderatorLinks,sinkCount,p);
  const power=info.fe;
  if(info.ok&&Number.isFinite(power)){
   const bucket=[Math.floor(selected.length/8),Math.floor(power/Math.max(500,Number(p.power)*4)),Math.floor(Math.max(0,-info.net)/5000)].join(':');
   const record=power>highest;
   if(record)highest=power;
   if((record||!emittedBuckets.has(bucket))&&sent<50){
    emittedBuckets.add(bucket);sent++;self.postMessage({type:'candidate',grid:g,index,kind:record?'best':'alternative',metadata:{fe:power,heat:info.heat,cooling:info.cooling,net:info.net,fuel:selected.length}});
   }
  }
  unique++;done=it+1;
  if(it%6===0){self.postMessage({type:'progress',index,done,unique});await workerYield()}
 }
 self.postMessage({type:'done',index,done,unique});
}
self.runLargeEnergy=search;
})();