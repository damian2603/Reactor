/* Reactor Studio 4.4 — large-grid NuclearCraft irradiation optimizer.
 * Fast generation uses spatial fuel lattices + genuine Fuel-Moderator-Chamber lines.
 * Main-thread simulation verifies every reported full grid before it is accepted.
 */
(function () {
  'use strict';
  const DIRECTIONS = [[1,0,0],[-1,0,0],[0,1,0],[0,-1,0],[0,0,1],[0,0,-1]];
  const geometryCache = new Map();
  function geometry(dims) {
    const key = dims.join('/');
    if (geometryCache.has(key)) return geometryCache.get(key);
    const [w,h,d] = dims, N=w*h*d;
    const coords = Array(N), adjacent=Array(N), candidates=Array(6);
    for(let k=0;k<6;k++) candidates[k]=[];
    for(let i=0;i<N;i++){
      const x=i%w, y=Math.floor(i/(w*d)), z=Math.floor(i/w)%d;
      coords[i]=[x,y,z]; const neighbors=[];
      for(let k=0;k<6;k++){
        const [dx,dy,dz]=DIRECTIONS[k], a=x+dx,b=y+dy,c=z+dz;
        const j=a>=0&&a<w&&b>=0&&b<h&&c>=0&&c<d?(b*d+c)*w+a:-1;
        neighbors.push(j);
        const ex=x+2*dx,ey=y+2*dy,ez=z+2*dz;
        candidates[k][i]=ex>=0&&ex<w&&ey>=0&&ey<h&&ez>=0&&ez<d?(ey*d+ez)*w+ex:-1;
      }
      adjacent[i]=neighbors;
    }
    const out={N,w,h,d,coords,adjacent,endpoints:candidates};
    geometryCache.set(key,out);return out;
  }
  async function runLargeIrradiation(data,shouldStop,isPaused) {
    const {dims,p,iterations,index=0,limits={},seed:incoming=[]}=data;
    const geo=geometry(dims),{N,w,h,d,coords,adjacent,endpoints}=geo;
    let state=(data.rng>>>0)||0x12345678;
    const rand=()=>{state^=state<<13;state^=state>>>17;state^=state<<5;return (state>>>0)/4294967296};
    const pick=n=>Math.floor(rand()*n);
    const wait=()=>new Promise(resolve=>setTimeout(resolve,0));
    const maxF=Math.max(1,Math.min(N,Math.trunc(p.maxFuel)||1));
    const maxM=Math.max(0,Math.trunc(p.machines)||0);
    const redLimit=Math.max(0,Math.trunc(limits.redstone??9999));
    const quartzLimit=Math.max(0,Math.trunc(limits.quartz??9999));
    const cobaltLimit=Math.max(0,Math.trunc(limits.cobalt??9999));
    const waterLimit=Math.max(0,Math.trunc(limits.water??9999));
    const liquidHeliumLimit=Math.max(0,Math.trunc(limits.liquid_helium??9999));
    const magnesiumLimit=Math.max(0,Math.trunc(limits.magnesium??9999));
    const boronLimit=Math.max(0,Math.trunc(limits.boron??9999));
    const trialCount=Math.max(1,Math.floor(iterations));
    let best=-Infinity, emitted=0, unique=0, done=0;
    const buckets=new Map(),sentSignatures=new Set();
    // Lattice-based seeds avoid overlapping F-M-F chains, which multiply reactor heat.
    // Coarse lattice spacing and density vary to explore high-cooling and high-irradiation regimes.
    for(let t=0;t<trialCount;t++) {
      if(shouldStop())break;
      while(isPaused()&&!shouldStop())await new Promise(r=>setTimeout(r,40));
      if(shouldStop())break;
      let g=Array(N).fill('.'),Fs=[],Ms=[],Is=[];
      const step=t%13===3?2:t%7===0?4:3;
      const ox=pick(Math.min(step,w)),oy=pick(Math.min(step,h)),oz=pick(Math.min(step,d));
      let sites=[];
      for(let y=oy;y<h;y+=step)for(let z=oz;z<d;z+=step)for(let x=ox;x<w;x+=step)sites.push((y*d+z)*w+x);
      // Randomly reorder sites for fair inclusion across 3 dimensions.
      for(let i=sites.length-1;i>0;i--){const j=pick(i+1);[sites[i],sites[j]]=[sites[j],sites[i]]}
      const density=step===2?(.36+rand()*.48):t%11===0?.98:t%7===0?.92:.40+rand()*.55;
      const nFuel=Math.min(maxF,sites.length,Math.max(1,Math.floor(sites.length*density)));
      for(let i=0;i<nFuel;i++){const loc=sites[i];g[loc]='F';Fs.push(loc)}
      // Build real F-M-I linear connections. Never place a chamber where a fuel already exists.
      // A few variations favor many lines, many sinks, or compromise between the two.
      const lineFraction=t%9===0?.17:t%9===1?.30:t%9===2?.75:.35+rand()*.55;
      let estimatedLines=0;
      for(const f of Fs){
        const attempts=1+(rand()<lineFraction*.55?1:0)+(rand()<lineFraction*.22?1:0);
        for(let a=0;a<attempts;a++){
          if(rand()>lineFraction)continue;
          let candidates=[];
          for(let dir=0;dir<6;dir++){
            const m=adjacent[f][dir],c=endpoints[dir][f];
            if(m<0||c<0)continue;
            if(g[m]!=='M'&&g[m]!=='.')continue;
            if(g[c]!=='I'&&g[c]!=='.')continue;
            const score=(g[m]==='M'?5:0)+(g[c]==='I'?9:0)+rand()*5;
            candidates.push({m,c,score});
          }
          if(!candidates.length)continue;
          candidates.sort((a,b)=>b.score-a.score);
          const {m,c}=candidates[0];
          if(g[m]==='.')Ms.push(m);
          if(g[c]==='.')Is.push(c);
          g[m]='M';g[c]='I';estimatedLines++;
        }
      }
      if(!Is.length){
        for(const f of Fs){let created=false;for(let dir=0;dir<6;dir++){
          const m=adjacent[f][dir],c=endpoints[dir][f];if(m>=0&&c>=0&&g[m]==='.'&&g[c]==='.'){
            g[m]='M';g[c]='I';Ms.push(m);Is.push(c);estimatedLines++;created=true;break;
          }
        }if(created)break}
      }
      if(!Is.length){done=t+1;continue}
      // Place guaranteed-valid redstone sinks, each directly adjacent to a Fuel Cell.
      let red=0,quartz=0,cobalt=0,water=0,helium=0,magnesium=0,boron=0;
      const coverF=new Uint8Array(N),coverM=new Uint8Array(N),coverI=new Uint8Array(N);
      for(const f of Fs)for(const i of adjacent[f])if(i>=0)coverF[i]++;
      for(const m of Ms)for(const i of adjacent[m])if(i>=0)coverM[i]++;
      for(const c of Is)for(const i of adjacent[c])if(i>=0)coverI[i]++;
      const available=[];
      for(let i=0;i<N;i++)if(g[i]==='.')available.push(i);
      // Adjacent two-fuel sink can provide 160 cooling vs 90 for Redstone, when >=2 F.
      const cryoLimit=Math.max(0,Math.trunc(limits.cryotheum??9999));let cryo=0;
      for(const i of available)if(g[i]==='.'&&coverF[i]>=2&&cryo<cryoLimit){g[i]='cryotheum';cryo++}
      for(const i of available)if(g[i]==='.'&&coverF[i]&&red<redLimit){g[i]='redstone';red++}
      // Remaining spaces adjoining moderators / chambers.
      for(const i of available){if(g[i]!=='.')continue;
        if(coverM[i]&&quartz<quartzLimit){g[i]='quartz';quartz++}
        else if(coverI[i]&&cobalt<cobaltLimit){g[i]='cobalt';cobalt++}
        else if(coverF[i]&&water<waterLimit){g[i]='water';water++}
      }
      // Boundary cooling: liquid helium touches a casing AND an existing redstone sink.
      for(const i of available)if(g[i]==='.'&&helium<liquidHeliumLimit){
        const [x,y,z]=coords[i];if(x!==0&&x!==w-1&&y!==0&&y!==h-1&&z!==0&&z!==d-1)continue;
        if(adjacent[i].some(n=>n>=0&&g[n]==='redstone')){g[i]='liquid_helium';helium++}
      }
      // Boundary magnesium touches the casing and a moderator.
      for(const i of available)if(g[i]==='.'&&magnesium<magnesiumLimit&&coverM[i]){
        const [x,y,z]=coords[i];if(x===0||x===w-1||y===0||y===h-1||z===0||z===d-1){g[i]='magnesium';magnesium++}
      }
      // Boron can be placed next to quartz and a moderator or casing.
      for(const i of available)if(g[i]==='.'&&boron<boronLimit){
        if(!adjacent[i].some(n=>n>=0&&g[n]==='quartz'))continue;
        const [x,y,z]=coords[i];if(coverM[i]||x===0||x===w-1||y===0||y===h-1||z===0||z===d-1){g[i]='boron';boron++}
      }
      // Only emit candidates likely to satisfy requested heat budget.
      // The main simulator handles fuel adjacency bonuses, moderator heat and all sink rules exactly.
      const cool=cryo*160+red*90+quartz*90+cobalt*75+water*60+helium*140+magnesium*110+boron*160;
      const roughHeat=Fs.length*(Number(p.heat)||0)+Ms.length*(Number(p.heat)||0)*Math.max(.1,p.moderation||0)/3;
      const lines=Math.max(1,estimatedLines);
      const possibleMachines=Math.floor((cool-roughHeat-(p.reserve||0))/(15*lines));
      const activeMachines=p.autoMachines?Math.min(maxM,possibleMachines):maxM;
      const likelyValid=cool>=roughHeat+15*lines*Math.max(0,activeMachines)+(p.reserve||0);
      if(likelyValid&&activeMachines>0){
        const score=p.goal==='lines'?lines*200+activeMachines:lines*activeMachines*100;
        const bucket=[Math.floor(lines/5),Math.floor(activeMachines/5),Math.floor(Fs.length/12)].join(':');
        const prior=buckets.get(bucket),record=score>best;
        if(record)best=score;
        if((record||prior===undefined||score>prior*1.07)&&emitted<45){
          buckets.set(bucket,score);
          const sig=[Fs.length,lines,activeMachines,red,quartz,cryo].join(':');
          if(!sentSignatures.has(sig)){
            sentSignatures.add(sig);emitted++;
            self.postMessage({type:'candidate',grid:g,index,kind:record?'best':'alternative',metadata:{fuel:Fs.length,lines,machines:activeMachines,coolingApprox:cool}});
          }
        }
      }
      unique++;done=t+1;
      if(t%4===0){self.postMessage({type:'progress',index,done,unique});await wait()}
    }
    self.postMessage({type:'done',index,done,unique});
  }
  self.runLargeIrradiation=runLargeIrradiation;
})();