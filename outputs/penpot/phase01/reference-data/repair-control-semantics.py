from pathlib import Path
p=Path('outputs/penpot/phase01/reference-data/capture-phase01.cjs');s=p.read_text()
s=s.replace("  // Keep its ancestry and recurse; inherited clipping still governs actual paint.\n", "  // Keep zero-sized wrapper ancestry and recurse; positive offscreen boxes need no paint.\n  if((visible.width<0.01||visible.height<0.01)&&b.width>0&&b.height>0)return;\n")
s=s.replace("draftRestored=false;render();status('محفوظ على جهازك');toast", "saleDraft={...freshSaleDraft(),date:'2026-10-27'};persistSaleDraft();draftRestored=false;render();status('محفوظ على جهازك');toast")
needle="  await run('new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)))');"
replace="""  const presentationOverrides=[];
  if(id==='desktop-invoice-new'||id==='phone-invoice-new'){
   const before=await run(`document.getElementById('invoice-old-balance').textContent`);
   await run(`document.getElementById('invoice-old-balance').textContent='137,500'`);
   presentationOverrides.push({selector:'#invoice-old-balance',before,after:'137,500',applied:before!=='137,500',scope:'Design-only synthetic presentation fixture. Match supplied reference footer; no model, posted record or accounting rule changed.'});
  }
  if(id==='phone-sales')presentationOverrides.push({field:'synthetic saleDraft.lines',after:[],scope:'Design-only narrow-reference fixture. Fresh empty local draft matches frozen visible product counts of zero; held-order list and posted synthetic records preserved.'});
"""+needle
assert needle in s;s=s.replace(needle,replace,1)
s=s.replace("const runs=[];for(const candidate of controls){try{const resolved=", """const runs=[],filteredControlRuns=[];for(const candidate of controls){try{
 const ownerResolved=await win.webContents.debugger.sendCommand('DOM.resolveNode',{backendNodeId:candidate.control.backendNodeId});
 const ownerResult=await win.webContents.debugger.sendCommand('Runtime.callFunctionOn',{objectId:ownerResolved.object.objectId,functionDeclaration:`function(){const b=this.getBoundingClientRect();const closed=this.closest('details:not([open])');const summary=closed?[...closed.children].find(c=>c.tagName==='SUMMARY'):null;const reasons=[];if(closed&&!summary?.contains(this))reasons.push('closed-details-descendant');for(let a=this;a;a=a.parentElement){const c=getComputedStyle(a);if(a.hidden||c.display==='none'||c.visibility==='hidden'||c.visibility==='collapse')reasons.push('hidden-ancestor');}if(!b.width||!b.height)reasons.push('empty-control-bounds');if(b.right<=0||b.bottom<=0||b.left>=innerWidth||b.top>=innerHeight)reasons.push('outside-viewport');return {domId:this.id,tag:this.tagName,className:this.className,bounds:{x:b.x,y:b.y,width:b.width,height:b.height},closedDetails:closed?{open:closed.open,summary:summary?.textContent}:null,paintVisible:reasons.length===0,reasons};}`,returnByValue:true});
 const owner=ownerResult.result.value;
 if(!owner?.paintVisible){filteredControlRuns.push({owner,text:candidate.node.nodeValue||'',kind:candidate.node.nodeType===3?'text':'indicator',reason:owner?.reasons||['unresolved-owner']});continue;}
 const resolved=""")
s=s.replace("runs.push({...measured.result.value,control:candidate.control,backendNodeId:candidate.node.backendNodeId})", "runs.push({...measured.result.value,owner,control:candidate.control,backendNodeId:candidate.node.backendNodeId})")
s=s.replace("controlSnapshots.push({id,viewport:{width,height},runs,markers,postProbeSha256", "controlSnapshots.push({id,viewport:{width,height},presentationOverrides,filteredControlRuns,runs,markers,postProbeSha256")
s=s.replace("data.id=id;data.sourceHashes=sourceHashChecks;", "data.id=id;data.presentationOverrides=presentationOverrides;data.sourceHashes=sourceHashChecks;")
# Add a bounded raster-ink location check for the visible invoice quantity zero.
needle="for(let i=0;i<runs.length;i++){const r=runs[i];"
replace="""{const image=nativeImage.createFromPath(path.join(out,id+'.png')),size=image.getSize(),bits=image.toBitmap(),scale=size.width/width;for(const r of runs.filter(r=>r.kind==='text'&&r.owner?.domId==='line-pieces-1')){let x0=Math.floor((r.bounds.x-2)*scale),x1=Math.ceil((r.bounds.x+r.bounds.width+2)*scale),y0=Math.floor((r.bounds.y-8)*scale),y1=Math.ceil((r.bounds.y+r.bounds.height+8)*scale),points=[];for(let y=Math.max(0,y0);y<Math.min(size.height,y1);y++)for(let x=Math.max(0,x0);x<Math.min(size.width,x1);x++){const k=(y*size.width+x)*4;const B=bits[k],G=bits[k+1],R=bits[k+2];if((R+G+B)/3<120&&G>R+5)points.push([x/scale,y/scale]);}r.sourceInkBounds=points.length?{minX:Math.min(...points.map(p=>p[0])),maxX:Math.max(...points.map(p=>p[0])),minY:Math.min(...points.map(p=>p[1])),maxY:Math.max(...points.map(p=>p[1])),pixelCount:points.length,method:'Read-only dark-green glyph-pixel bounds in the known isolated quantity input; no image modification.'}:null;}}
"""+needle
assert needle in s;s=s.replace(needle,replace,1);p.write_text(s)
p=Path('outputs/penpot/phase01/reference-data/build-artwork-phase01.py');s=p.read_text();old="""        matches=[n for n in j['nodes'] if n.get('kind')=='control' and n['bounds']['x']-1<=cx<=n['bounds']['x']+n['bounds']['width']+1 and n['bounds']['y']-1<=cy<=n['bounds']['y']+n['bounds']['height']+1]
        if matches:
            owner=min(matches,key=lambda n:n['bounds']['width']*n['bounds']['height']);attached.setdefault(owner['id'],[]).append(c)
"""
new="""        attributes=c.get('control',{}).get('attributes',[])
        dom_id=c.get('owner',{}).get('domId') or (attributes[attributes.index('id')+1] if 'id' in attributes else None)
        exact=[n for n in j['nodes'] if n.get('kind')=='control' and dom_id and (n.get('name')=='#'+dom_id or n.get('name','').startswith('#'+dom_id+'.'))]
        matches=exact or [n for n in j['nodes'] if n.get('kind')=='control' and n['bounds']['x']-1<=cx<=n['bounds']['x']+n['bounds']['width']+1 and n['bounds']['y']-1<=cy<=n['bounds']['y']+n['bounds']['height']+1]
        if matches:
            owner=exact[0] if exact else min(matches,key=lambda n:n['bounds']['width']*n['bounds']['height']);attached.setdefault(owner['id'],[]).append(c)
"""
assert old in s;s=s.replace(old,new);p.write_text(s)
