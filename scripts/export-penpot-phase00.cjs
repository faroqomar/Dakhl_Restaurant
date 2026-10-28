// Phase 00 reference export only. Never loads production Storage or accounts.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),os=require('node:os');
const root=path.resolve(__dirname,'..'),referenceRoot=path.join(root,'electron-reference');
const runtimeRoot=process.env.DAFTAR_REFERENCE_RUNTIME || '/Users/eros/Dev/Eros_Projects/Dakhl_Restaurant/electron-reference';
const runtimeRequire=require('node:module').createRequire(path.join(runtimeRoot,'package.json'));
const {app,BrowserWindow,ipcMain,nativeImage}=runtimeRequire('electron');
const RealDate=Date,fixed='2026-10-27T10:00:00.000Z';
global.Date=class extends RealDate {constructor(...a){super(...(a.length?a:[fixed]));}static now(){return new RealDate(fixed).getTime();}};
const M=require(path.join(referenceRoot,'app/ui/model.js'));
const {previewFixture}=require(path.join(referenceRoot,'scripts/preview-fixture.cjs'));
const date='2026-10-27',stamp=date+'T10:00:00.000Z';
const out=path.join(root,'outputs/penpot/phase00/reference-data');fs.mkdirSync(out,{recursive:true});
const profile=fs.mkdtempSync(path.join(os.tmpdir(),'daftar-penpot-reference-'));
app.setName('Daftar Isolated Reference Export');app.setPath('userData',profile);app.commandLine.appendSwitch('force-device-scale-factor','1');
function fixture() {
  let s = previewFixture();
  s.preferences.restaurant = { name: 'مطعم توضيحي', contact: '', footer: 'شكراً لزيارتكم · بيانات توضيحية' };
  s.categories.push({ id:'gas', name:'الغاز', type:'additional' });
  s.days[date] = structuredClone(M.day(s, date));
  s.days[date].expenses = [
    {id:'expense-daily',categoryId:'bread',amount:15000,note:'مثال مصروف يومي',createdAt:stamp,funding:{source:'daily',dailyAmount:15000,cashAmount:0}},
    {id:'expense-shared',categoryId:'gas',amount:30000,note:'مثال دفع مشترك',createdAt:stamp,funding:{source:'shared',dailyAmount:20000,cashAmount:10000}},
    {id:'expense-cash',categoryId:'market',amount:10000,note:'مثال من القاصة',createdAt:stamp,funding:{source:'cash',dailyAmount:0,cashAmount:10000}}
  ];
  s.days[date].chickenUsed=12;s.days[date].chickenLeft=8;
  s.transactions.push({id:'deposit',date,type:'deposit',amount:300000,note:'رصيد توضيحي',createdAt:stamp},{id:'withdrawal',date,type:'withdrawal',amount:10000,note:'سحب توضيحي',createdAt:stamp});
  s.suppliers.push({id:'supplier',name:'مورد توضيحي',phone:'',note:'بيانات مصطنعة للمرجع فقط',categoryId:'market',openingBalance:50000,archived:false});
  s.materials.push({id:'rice',name:'رز توضيحي',unit:'كيلو',price:2500,priceCarton:40000,pricePiece:2500,archived:false});
  s.invoices.push({id:'invoice',supplierId:'supplier',number:'DEMO-001',date,lines:[{materialId:'rice',name:'رز توضيحي',unit:'كيلو',quantityCartons:2,quantityPieces:3,priceCarton:40000,pricePiece:2500}],note:'فاتورة توضيحية',createdAt:stamp});
  s.debts.push({id:'debt',supplierId:'supplier',date,amount:20000,note:'دين توضيحي',createdAt:stamp});
  s.payments.push({id:'payment',supplierId:'supplier',invoiceId:'invoice',date,amount:20000,invoiceAmount:20000,debtAmount:0,categoryId:'market',funding:{source:'shared',dailyAmount:15000,cashAmount:5000},note:'تسديد توضيحي',createdAt:stamp});
  s=M.validate(s);
  s=M.completeSale(s,{date,lines:[{productId:'p0',quantity:3},{productId:'p1',quantity:2}],discount:1001,orderType:'صالة',note:'بيع توضيحي'},'sale',stamp);
  s=M.returnSale(s,'sale',{date,reason:'مرتجع توضيحي',lines:[{productId:'p0',quantity:1,restock:true}]},'return',date+'T11:00:00.000Z');
  s=M.completeSale(s,{date,lines:[{productId:'p4',quantity:2}],discount:0,orderType:'سفري'},'sale-void',stamp);
  s=M.voidSale(s,'sale-void','تصحيح توضيحي',stamp);
  s=M.completeSale(s,{date,lines:[{productId:'p2',quantity:1}],discount:0,orderType:'توصيل'},'sale-paid',stamp);
  M.recordRemaining(s,date,100000);M.transferRemaining(s,date,20000,'transfer',stamp);
  return M.validate(s);
}

const stored=fixture();
const sha=p=>crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
function extractVisible(){
 const vp={x:0,y:0,width:innerWidth,height:innerHeight},nodes=[],texts=[],images=[],svgs=[];
 const bbox=r=>({x:r.x,y:r.y,width:r.width,height:r.height});
 const intersect=(a,b)=>{const x=Math.max(a.x,b.x),y=Math.max(a.y,b.y),right=Math.min(a.x+a.width,b.x+b.width),bottom=Math.min(a.y+a.height,b.y+b.height);return{x,y,width:Math.max(0,right-x),height:Math.max(0,bottom-y)}};
 const cssKeys=['font','backgroundColor','backgroundImage','color','borderTopColor','borderRightColor','borderBottomColor','borderLeftColor','borderTopWidth','borderRightWidth','borderBottomWidth','borderLeftWidth','borderTopStyle','borderRightStyle','borderBottomStyle','borderLeftStyle','borderTopLeftRadius','borderTopRightRadius','borderBottomRightRadius','borderBottomLeftRadius','boxShadow','opacity','fontFamily','fontSize','fontWeight','fontStyle','fontStretch','fontKerning','fontFeatureSettings','fontVariationSettings','fontVariantNumeric','fontVariantLigatures','fontVariantCaps','whiteSpace','wordSpacing','textIndent','textOverflow','textDecorationLine','textDecorationColor','textDecorationStyle','textDecorationThickness','writingMode','lineHeight','letterSpacing','textAlign','textTransform','direction','paddingTop','paddingRight','paddingBottom','paddingLeft','objectFit','objectPosition','position','zIndex','overflow','overflowX','overflowY','transform','outline','appearance','display','visibility'];
 const styles=cs=>Object.fromEntries(cssKeys.map(k=>[k,cs[k]]));
 let seq=0;
 function walk(el,parentId,clip,opacity=1){
  if(el.nodeType!==1)return;const cs=getComputedStyle(el);
  if(cs.display==='none'||cs.visibility==='hidden'||cs.visibility==='collapse'||Number(cs.opacity)===0||el.hidden)return;
  const b=bbox(el.getBoundingClientRect()),visible=intersect(b,clip),id='n'+(++seq),alpha=opacity*Number(cs.opacity),tag=el.tagName.toLowerCase();
  if(visible.width<0.01||visible.height<0.01)return;
  const entry={id,parentId,order:seq,tag,name:(el.id?'#'+el.id:tag)+(el.className&&typeof el.className==='string'?'.'+el.className.trim().split(/\s+/).join('.'):''),bounds:b,clip:clip,visibleBounds:visible,style:styles(cs),opacity:alpha};const closedDetails=el.closest('details:not([open])');if(closedDetails&&closedDetails!==el){const summary=[...closedDetails.children].find(c=>c.tagName==='SUMMARY');if(!summary?.contains(el))entry.paintVisible=false;}nodes.push(entry);
  if(tag==='svg'){
   const clone=el.cloneNode(true);clone.setAttribute('width',b.width);clone.setAttribute('height',b.height);clone.setAttribute('xmlns','http://www.w3.org/2000/svg');
   const all=[clone,...clone.querySelectorAll('*')],originals=[el,...el.querySelectorAll('*')];
   all.forEach((e,i)=>{for(const prop of ['fill','stroke','stroke-width','stroke-linecap','stroke-linejoin']){const val=getComputedStyle(originals[i]).getPropertyValue(prop);if(val)e.setAttribute(prop,val)}});
   entry.kind='svg';entry.svg=clone.outerHTML;svgs.push(entry);return;
  }
  if(tag==='img'){entry.kind='image';entry.src=el.currentSrc||el.src;entry.naturalWidth=el.naturalWidth;entry.naturalHeight=el.naturalHeight;images.push(entry);return;}
  if(['input','select','textarea'].includes(tag)){
   entry.kind='control';entry.control={type:el.type,value:el.value,placeholder:el.getAttribute('placeholder'),checked:el.checked,disabled:el.disabled,options:tag==='select'?[...el.options].map(o=>({value:o.value,text:o.text,selected:o.selected})):undefined};
   return;
  }
  let childClip=clip;
  if(['hidden','clip','auto','scroll'].includes(cs.overflowX)||['hidden','clip','auto','scroll'].includes(cs.overflowY)){
   const c={x:b.x+el.clientLeft,y:b.y+el.clientTop,width:el.clientWidth,height:el.clientHeight};
   const constrained={x:['hidden','clip','auto','scroll'].includes(cs.overflowX)?c.x:clip.x,y:['hidden','clip','auto','scroll'].includes(cs.overflowY)?c.y:clip.y,width:['hidden','clip','auto','scroll'].includes(cs.overflowX)?c.width:clip.width,height:['hidden','clip','auto','scroll'].includes(cs.overflowY)?c.height:clip.height};childClip=intersect(clip,constrained);
  }
  for(const child of el.childNodes){
   if(child.nodeType===1)walk(child,id,childClip,alpha);
   else if(child.nodeType===3 && child.textContent.trim()){
    const range=document.createRange();range.selectNodeContents(child);const rects=[...range.getClientRects()].map(bbox).filter(r=>intersect(r,childClip).width>0&&intersect(r,childClip).height>0);if(!rects.length)continue;
    const chars=[];let offset=0;for(const ch of child.textContent){range.setStart(child,offset);range.setEnd(child,offset+ch.length);const rr=range.getBoundingClientRect();if(rr.height>0)chars.push({text:ch,start:offset,end:offset+ch.length,bounds:bbox(rr)});offset+=ch.length;}
    const groups=[];for(const c of chars){let g=groups.find(g=>Math.abs(g.y-c.bounds.y)<0.5);if(!g){g={y:c.bounds.y,chars:[]};groups.push(g);}g.chars.push(c);}
    const lines=groups.map(g=>{const first=Math.min(...g.chars.map(c=>c.start)),last=Math.max(...g.chars.map(c=>c.end)),x=Math.min(...g.chars.map(c=>c.bounds.x)),right=Math.max(...g.chars.map(c=>c.bounds.x+c.bounds.width));return {text:child.textContent.slice(first,last).replace(/\s+/g,' ').trim(),start:first,end:last,bounds:{x,y:g.y,width:right-x,height:Math.max(...g.chars.map(c=>c.bounds.height))}}});
    range.selectNodeContents(child);const tb=bbox(range.getBoundingClientRect());
    // Measure the actual layout baseline, then restore the text node before capture.
    for(const line of lines){const wrapper=document.createElement('span'),before=document.createTextNode(child.textContent.slice(0,line.end)),after=document.createTextNode(child.textContent.slice(line.end)),marker=document.createElement('span');wrapper.style.cssText='all:unset;display:inline;';marker.style.cssText='all:initial;display:inline-block;width:0;height:0;margin:0;padding:0;border:0;vertical-align:baseline;line-height:0;';child.replaceWith(wrapper);wrapper.append(before,marker,after);const probe=document.createRange();probe.selectNodeContents(wrapper);const rb=probe.getBoundingClientRect(),mr=marker.getBoundingClientRect();line.domBaseline=mr.y;line.baselineMethod='zero-size inline-block vertical-align:baseline';line.baselineLayoutDelta={x:rb.x-tb.x,y:rb.y-tb.y,width:rb.width-tb.width,height:rb.height-tb.height};line.baselineWithinLine=mr.y>=line.bounds.y&&mr.y<=line.bounds.y+line.bounds.height;line.baselineReliable=line.baselineWithinLine&&Math.max(...Object.values(line.baselineLayoutDelta).map(Math.abs))<0.05;wrapper.replaceWith(child);}

    const context=document.createElement('canvas').getContext('2d');context.font=[cs.fontStyle,cs.fontWeight,cs.fontSize,cs.fontFamily.replace(/-apple-system|BlinkMacSystemFont/g,'system-ui')].join(' ');context.direction=cs.direction;const measure=value=>{const mt=context.measureText(value);return Object.fromEntries(['width','actualBoundingBoxLeft','actualBoundingBoxRight','fontBoundingBoxAscent','fontBoundingBoxDescent','actualBoundingBoxAscent','actualBoundingBoxDescent','emHeightAscent','emHeightDescent','hangingBaseline','alphabeticBaseline','ideographicBaseline'].filter(k=>typeof mt[k]==='number').map(k=>[k,mt[k]]));};const metrics=measure(child.textContent.replace(/\s+/g,' ').trim());for(const line of lines)line.metrics=measure(line.text);
    const text={id:'t'+(++seq),parentId:id,order:seq,kind:'text',text:child.textContent,characters:child.textContent.replace(/\s+/g,' ').trim(),bounds:tb,lineRects:rects,lines,charRects:chars,canvasFont:context.font,metrics,clip:childClip,style:styles(cs),opacity:alpha};texts.push(text);nodes.push(text);
   }
  }
  for(const pseudo of ['::before','::after']){const p=getComputedStyle(el,pseudo);if(p.content!=='none'&&p.content!=='normal'&&p.content!=='""')entry[pseudo]={content:p.content,style:styles(p),left:p.left,right:p.right,top:p.top,bottom:p.bottom,width:p.width,height:p.height};}
 }
 walk(document.body,null,vp);const hiddenIds=new Set();for(const entry of nodes){if(entry.paintVisible===false||hiddenIds.has(entry.parentId)){entry.paintVisible=false;hiddenIds.add(entry.id);}else entry.paintVisible=true;}for(const list of[nodes,texts,images,svgs])for(let i=list.length-1;i>=0;i--)if(list[i].paintVisible===false)list.splice(i,1);return {viewport:vp,devicePixelRatio,scrollHeight:document.documentElement.scrollHeight,fontCheck:document.fonts.check('15px "Geeza Pro"'),nodes,texts,images,svgs,html:document.documentElement.outerHTML};
}
app.whenReady().then(async()=>{
 const manifest=JSON.parse(fs.readFileSync(path.join(root,'docs/planning/flutter-rebuild/screenshot-manifest.json'),'utf8'));
 const sourceHashChecks=Object.entries(manifest.sourceHashes).map(([f,expected])=>({file:f,match:sha(path.join(referenceRoot,'app/ui',f))===expected}));
 if(sourceHashChecks.some(s=>!s.match))throw new Error('Frozen UI source hash mismatch');
 ipcMain.handle('accounts:load',()=>({ok:true,data:stored,directory:'Isolated synthetic reference data'}));
 ipcMain.handle('accounts:save',(_e,d)=>({ok:true,data:M.validate(d)}));
 ipcMain.handle('accounts:backup-info',()=>({ok:true,backupInfo:{lastExport:null,previousAvailable:true}}));
 for(const channel of ['pdf','export','import','folder','restore','print','open-export'])ipcMain.handle('accounts:'+channel,()=>({ok:true,canceled:true}));
 const win=new BrowserWindow({width:1440,height:1000,useContentSize:true,show:false,webPreferences:{preload:path.join(referenceRoot,'app/preload.cjs'),contextIsolation:true,nodeIntegration:false,sandbox:true,backgroundThrottling:false}});
 const run=code=>win.webContents.executeJavaScript(code);
 console.log('stage: loading isolated reference');await win.loadFile(path.join(referenceRoot,'app/ui/index.html'));console.log('stage: isolated reference loaded');
 await new Promise(r=>setTimeout(r,550));
 await run(`{const OriginalDate=Date,fixed='${fixed}';window.Date=class extends OriginalDate{constructor(...a){super(...(a.length?a:[fixed]));}static now(){return new OriginalDate(fixed).getTime();}};}void 0;`);
 await run(`selectedDate='${date}';saleFilter={from:'${date}',to:'${date}',query:'',status:''};statementFilter={from:'${date}',to:'${date}',categoryId:'',source:'all'};selectedSupplier='supplier';saleDraft={...freshSaleDraft(),date:'${date}',lines:[{productId:'p0',quantity:2,price:12000,name:'كباب لحم',unit:'قطعة'},{productId:'p4',quantity:1,price:2000,name:'تمن أحمر',unit:'قطعة'}],discount:'1000'};heldOrders=[{id:'held-demo',label:'طلب توضيحي',savedAt:'${stamp}',draft:structuredClone(saleDraft)}];draftRestored=true;persistSaleDraft();status('محفوظ على جهازك');`);
 const controlsOnly=process.env.DAFTAR_CONTROL_EXPORT==='1';const controlSnapshots=[];
 if(controlsOnly)win.webContents.debugger.attach('1.3');
 const results=[];
 for(const [id,view,extra]of[['desktop-sales','sales',''],['desktop-expenses','expenses',''],['desktop-settings-data','settings',`activateSettingsSection('data');updateSettingsSaveState();`]]){
  await run(`closeDrawer(true);sidebarCollapsed=true;selectedDate='${date}';view='${view}';render();window.scrollTo(0,0);${extra}`);
  if(id==='desktop-settings-data'){await run('window.scrollTo(0,20)');await new Promise(r=>setTimeout(r,30));await run('window.scrollTo(0,0)');}await new Promise(r=>setTimeout(r,190));console.log('stage: export '+id);
  if(controlsOnly){const snapshot=await win.webContents.debugger.sendCommand('DOMSnapshot.captureSnapshot',{computedStyles:['font','font-family','font-size','font-weight','font-style','color','direction','line-height','letter-spacing','text-align','padding-left','padding-right'],includePaintOrder:true,includeDOMRects:true});const document=await win.webContents.debugger.sendCommand('DOM.getDocument',{depth:-1,pierce:true});const controls=[];function walkControl(n,control=null,shadow=false){if(['INPUT','SELECT','TEXTAREA'].includes(n.nodeName))control={backendNodeId:n.backendNodeId,attributes:n.attributes,tag:n.nodeName};if(control&&shadow&&(n.nodeType===3||n.attributes?.includes('-webkit-calendar-picker-indicator')))controls.push({node:n,control});for(const c of n.children||[])walkControl(c,control,shadow);for(const c of n.shadowRoots||[])walkControl(c,control,true);}walkControl(document.root);const runs=[];for(const candidate of controls){try{const resolved=await win.webContents.debugger.sendCommand('DOM.resolveNode',{backendNodeId:candidate.node.backendNodeId});const measured=await win.webContents.debugger.sendCommand('Runtime.callFunctionOn',{objectId:resolved.object.objectId,functionDeclaration:`function(){const el=this.nodeType===3?this.parentElement:this;const cs=getComputedStyle(el),range=document.createRange();range.selectNodeContents(this);const r=this.nodeType===3?range.getBoundingClientRect():el.getBoundingClientRect();if(!r.width||!r.height||cs.display==='none'||cs.visibility==='hidden')return null;const style={};for(const k of ['font','fontFamily','fontSize','fontWeight','fontStyle','fontStretch','fontKerning','fontFeatureSettings','fontVariationSettings','fontVariantNumeric','fontVariantLigatures','lineHeight','letterSpacing','direction','color','backgroundImage','backgroundSize','backgroundPosition','backgroundOrigin','backgroundClip','backgroundRepeat','paddingTop','paddingRight','paddingBottom','paddingLeft','boxSizing','opacity'])style[k]=cs[k];const text=this.nodeType===3?this.textContent:'';const ctx=document.createElement('canvas').getContext('2d');ctx.font=[cs.fontStyle,cs.fontWeight,cs.fontSize,cs.fontFamily.replace(/-apple-system|BlinkMacSystemFont/g,'system-ui')].join(' ');ctx.direction=cs.direction;const mt=ctx.measureText(text),metrics={};for(const k of ['width','fontBoundingBoxAscent','fontBoundingBoxDescent','actualBoundingBoxAscent','actualBoundingBoxDescent','actualBoundingBoxLeft','actualBoundingBoxRight'])metrics[k]=mt[k];let baseline=null;if(this.nodeType===3){const wrapper=document.createElement('span'),marker=document.createElement('span'),copy=document.createTextNode(text);wrapper.style.cssText='all:unset;display:inline;';marker.style.cssText='all:initial;display:inline-block;width:0;height:0;margin:0;padding:0;border:0;vertical-align:baseline;line-height:0;';this.replaceWith(wrapper);wrapper.append(copy,marker);const probe=document.createRange();probe.selectNodeContents(wrapper);const rb=probe.getBoundingClientRect(),mr=marker.getBoundingClientRect(),delta={x:rb.x-r.x,y:rb.y-r.y,width:rb.width-r.width,height:rb.height-r.height};baseline={domBaseline:mr.y,baselineMethod:'zero-size inline-block vertical-align:baseline',baselineLayoutDelta:delta,baselineReliable:Math.max(...Object.values(delta).map(Math.abs))<0.05};wrapper.replaceWith(this);}return {text,kind:this.nodeType===3?'text':'indicator',bounds:{x:r.x,y:r.y,width:r.width,height:r.height},style,canvasFont:ctx.font,metrics,...baseline};}`,returnByValue:true});if(measured.result.value)runs.push({...measured.result.value,control:candidate.control,backendNodeId:candidate.node.backendNodeId});}catch(e){console.log('control skipped '+e.message);}}for(let i=0;i<runs.length;i++){const r=runs[i];r.id=id+'-control-'+i;r.characters=r.text;r.lines=r.kind==='text'?[{text:r.text,bounds:r.bounds,metrics:r.metrics,domBaseline:r.domBaseline,baselineMethod:r.baselineMethod,baselineLayoutDelta:r.baselineLayoutDelta,baselineReliable:r.baselineReliable}]:[];r.lineRects=r.kind==='text'?[r.bounds]:[];if(r.kind==='indicator'&&r.style.backgroundImage.startsWith('url("data:image/svg+xml;base64,')){const b64=r.style.backgroundImage.slice(31,-2);const svg=Buffer.from(b64,'base64').toString('utf8');r.svg=svg;const pad={left:parseFloat(r.style.paddingLeft)||0,right:parseFloat(r.style.paddingRight)||0,top:parseFloat(r.style.paddingTop)||0,bottom:parseFloat(r.style.paddingBottom)||0};r.backgroundContentBounds={x:r.bounds.x+pad.left,y:r.bounds.y+pad.top,width:r.bounds.width-pad.left-pad.right,height:r.bounds.height-pad.top-pad.bottom};const scale=Math.min(r.backgroundContentBounds.width/16,r.backgroundContentBounds.height/15);r.backgroundPaintBounds={x:r.backgroundContentBounds.x,y:r.backgroundContentBounds.y,width:16*scale,height:15*scale};fs.writeFileSync(path.join(out,id+'-calendar.svg'),svg);}}if(id==='desktop-sales'){const source=nativeImage.createFromPath(path.join(out,id+'.png'));const arrowPath=path.join(out,'desktop-sales-select-indicator.png');fs.writeFileSync(arrowPath,source.crop({x:2110,y:1226,width:20,height:14}).toPNG());runs.push({id:id+'-select-indicator',kind:'indicator',assetPath:arrowPath,bounds:{x:1055,y:613,width:10,height:7},source:'Discrete native select chevron crop only; DPR2; no input surface'});}await new Promise(r=>setTimeout(r,60));const postProbePng=(await win.webContents.capturePage()).toPNG(),postProbeSha256=crypto.createHash('sha256').update(postProbePng).digest('hex');const markers=[];async function markerWalk(n){for(const p of n.pseudoElements||[]){if(p.pseudoType==='marker'){try{const b=await win.webContents.debugger.sendCommand('DOM.getBoxModel',{backendNodeId:p.backendNodeId});const rect=b.model.border,x=Math.floor(rect[0]*2),y=Math.floor(rect[1]*2),w=Math.ceil(rect[2]*2)-x,h=Math.ceil(rect[5]*2)-y,assetPath=path.join(out,id+'-details-marker.png');fs.writeFileSync(assetPath,nativeImage.createFromPath(path.join(out,id+'.png')).crop({x,y,width:w,height:h}).toPNG());const resolved=await win.webContents.debugger.sendCommand('DOM.resolveNode',{backendNodeId:n.backendNodeId});const description=await win.webContents.debugger.sendCommand('Runtime.callFunctionOn',{objectId:resolved.object.objectId,functionDeclaration:`function(){const cs=getComputedStyle(this,'::marker');return {summary:this.textContent,open:this.parentElement.open,font:cs.font,color:cs.color,listStyleType:cs.listStyleType,content:cs.content}}`,returnByValue:true});markers.push({backendNodeId:p.backendNodeId,parentAttributes:n.attributes,box:b.model,assetPath,assetBounds:{x:x/2,y:y/2,width:w/2,height:h/2},...description.result.value});}catch(e){markers.push({backendNodeId:p.backendNodeId,parentAttributes:n.attributes,error:e.message});}}}for(const c of n.children||[])await markerWalk(c);}await markerWalk(document.root);controlSnapshots.push({id,viewport:{width:1440,height:1000},runs,markers,postProbeSha256,postProbeScreenshotUnchanged:postProbeSha256===sha(path.join(out,id+'.png'))});continue;}
  const data=await run('('+extractVisible.toString()+')()');console.log('stage: DOM '+id+' '+data.nodes.length);
  await new Promise(r=>setTimeout(r,60));const png=(await win.webContents.capturePage()).toPNG();console.log('stage: PNG '+id);fs.writeFileSync(path.join(out,id+'.png'),png);
  for(const im of data.images){if(im.src.startsWith('file://')){const p=require('node:url').fileURLToPath(im.src);im.assetPath=p;im.assetSha256=sha(p);im.dataUrl='data:image/'+(p.endsWith('.webp')?'webp':p.endsWith('.jpg')||p.endsWith('.jpeg')?'jpeg':'png')+';base64,'+fs.readFileSync(p).toString('base64');}}
  fs.writeFileSync(path.join(out,id+'.html'),data.html);delete data.html;
  data.id=id;data.sourceHashes=sourceHashChecks;data.frozenScreenshot=path.join(root,'docs/planning/flutter-rebuild/screenshots',id+'.png');
  const actual=nativeImage.createFromBuffer(png),expected=nativeImage.createFromPath(data.frozenScreenshot);const a=actual.toBitmap(),e=expected.toBitmap();
  let changed=0,totalDiff=0,maxDiff=0,minX=Infinity,minY=Infinity,maxX=0,maxY=0;for(let i=0;i<a.length&&i<e.length;i+=4){let pixelDiff=false;for(let c=0;c<3;c++){const d=Math.abs(a[i+c]-e[i+c]);totalDiff+=d;maxDiff=Math.max(maxDiff,d);if(d)pixelDiff=true;}if(pixelDiff){changed++;const p=i/4,x=p%actual.getSize().width,y=Math.floor(p/actual.getSize().width);minX=Math.min(minX,x);minY=Math.min(minY,y);maxX=Math.max(maxX,x);maxY=Math.max(maxY,y);}}
  data.comparison={actualSize:actual.getSize(),expectedSize:expected.getSize(),equalDimensions:a.length===e.length,changedPixels:changed,totalPixels:a.length/4,changedPixelRatio:changed/(a.length/4),differenceBounds:changed?{minX,minY,maxX,maxY}:null,meanAbsoluteChannelDifference:totalDiff/((a.length/4)*3),maxChannelDifference:maxDiff,actualSha256:sha(path.join(out,id+'.png')),expectedSha256:sha(data.frozenScreenshot)};
  fs.writeFileSync(path.join(out,id+'.json'),JSON.stringify(data,null,2)+'\n');results.push({id,elements:data.nodes.length,texts:data.texts.length,images:data.images.length,svgs:data.svgs.length,...data.comparison});console.log(JSON.stringify(results.at(-1)));
 }
 if(controlsOnly){fs.writeFileSync(path.join(out,'control-runs.json'),JSON.stringify(controlSnapshots));app.quit();return;}
 fs.writeFileSync(path.join(out,'manifest.json'),JSON.stringify({date,isolatedProfile:profile,syntheticOnly:true,viewport:{width:1440,height:1000},sourceHashChecks,results},null,2)+'\n');
 app.quit();
}).catch(e=>{console.error(e);app.exit(1)});
