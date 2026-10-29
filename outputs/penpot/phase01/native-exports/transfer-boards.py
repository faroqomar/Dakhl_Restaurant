import json,subprocess,hashlib,xml.etree.ElementTree as E
from pathlib import Path
root=Path('/Users/eros/.codex/worktrees/phase01-scope-app/Dakhl_Restaurant');base=root/'outputs/penpot/phase01';out=base/'native-exports';tmp=out/'transfer';tmp.mkdir(exist_ok=True)
helper='/Users/eros/.codex/skills/penpot/scripts/penpot-client.mjs'
old=json.loads(Path('/Users/eros/.codex/worktrees/phase00-penpot/Dakhl_Restaurant/outputs/penpot/phase00/reference-data/desktop-sales.json').read_text());photoMap={Path(im['assetPath']).name:im['id'] for im in reversed(old['images'])}
controlBy={v['id']:v for v in json.loads((base/'reference-data/control-runs.json').read_text())}
ns='{http://www.w3.org/2000/svg}';E.register_namespace('','http://www.w3.org/2000/svg');E.register_namespace('xlink','http://www.w3.org/1999/xlink')
screens=[('desktop-navigation','Desktop navigation',1520,3000,1440,1000),('design-system','Design inventory',0,3000,1440,1200),('desktop-invoice-new','Desktop invoice dialog',3040,3000,1440,1000),('phone-sales','Narrow sales',1520,5700,390,844),('phone-invoice-new','Narrow invoice dialog',2070,5700,390,844),('medium-sales','Medium sales shell',900,8400,1024,768),('wide-sales','Wide sales shell',2050,8400,1920,1080)]
ledger=json.loads((out/'import-ledger.json').read_text()) if (out/'import-ledger.json').exists() else []
done={(v['screen'],v['kind']) for v in ledger}
def call(args):
 r=subprocess.run(['node',helper]+args,cwd=root,text=True,capture_output=True)
 if r.returncode: raise RuntimeError((r.stderr or r.stdout)[-1300:])
 return r.stdout
for screen,label,x,y,w,h in screens:
 data=json.loads((base/'reference-data'/f'{screen}.json').read_text());photos=[{'node':im['id'],'sourceNode':photoMap.get(Path(im['assetPath']).name,photoMap.get(Path(im['assetPath']).name.replace('-240.','-480.'))),**im['bounds']} for im in data['images']]
 for kind in ['design','wireframe']:
  if (screen,kind) in done: continue
  src=base/'source-artwork'/f'{screen}-{kind}.svg';svg=E.fromstring(src.read_text());tiny=[]
  for parent in svg.iter():
   for el in list(parent):
    if el.tag!=ns+'image':continue
    if float(el.get('width','0'))<50 and float(el.get('height','0'))<50:
     info={k:float(el.get(k,'0')) for k in ['x','y','width','height']};info['kind']='disclosure' if 'disclosure' in (el.get('id') or '') else 'select';info['open']=(controlBy.get(screen,{}).get('markers') or [{}])[0].get('open',True);tiny.append(info)
     replacement=E.Element(ns+'rect',{'id':'native-discrete-'+str(len(tiny)),'x':el.get('x','0'),'y':el.get('y','0'),'width':el.get('width','0'),'height':el.get('height','0'),'fill':'#AAAAAA'});i=list(parent).index(el);parent.remove(el);parent.insert(i,replacement)
    else:
     clipId=(el.get('clip-path') or '').replace('url(#','').replace(')','');clip=next((q for q in svg.iter() if q.tag==ns+'clipPath' and q.get('id')==clipId),None);cp=next((q for q in clip.iter() if q.tag==ns+'path'),None) if clip is not None else None
     if cp is not None: replacement=E.Element(ns+'path',{'d':cp.get('d'),'fill':'#AAAAAA'})
     else: replacement=E.Element(ns+'rect',{'x':el.get('x','0'),'y':el.get('y','0'),'width':el.get('width','0'),'height':el.get('height','0'),'rx':'8','fill':'#AAAAAA'})
     i=list(parent).index(el);parent.remove(el);parent.insert(i,replacement)
  if screen in ['desktop-invoice-new','phone-invoice-new']:
   footer=next(n for n in data['nodes'] if n.get('name')=='div.form-footer');fb=footer['bounds'];fx,fy,fw,fh=[fb[k] for k in ['x','y','width','height']];rr=13
   fg=next(q for q in svg.iter() if q.tag==ns+'g' and (q.get('id') or '').split(' ')[0]==footer['id']);background=next(q for q in fg.iter() if q.tag==ns+'path' and q.get('fill') not in [None,'none'])
   background.set('d',f'M{fx} {fy}H{fx+fw}V{fy+fh-rr}A{rr} {rr} 0 0 1 {fx+fw-rr} {fy+fh}H{fx+rr}A{rr} {rr} 0 0 1 {fx} {fy+fh-rr}Z')
  transfer=tmp/f'{screen}-{kind}.svg';transfer.write_text(E.tostring(svg,encoding='unicode'))
  stage=json.loads(call(['stage-svg',str(transfer)]));key=stage['storageKey'];title=f'01 · Reference · {label} · {kind.capitalize()} · v1';yy=y+(1350 if kind=='wireframe' else 0)
  spec={'screen':screen,'kind':kind,'name':title,'x':x,'y':yy,'w':w,'h':h,'sourceSha256':hashlib.sha256(src.read_bytes()).hexdigest(),'text':[t.get('characters',t.get('text','')) for t in data['texts']],'photos':photos if kind=='design' else [],'tiny':tiny}
  code="""if(penpot.currentFile.id!=='122350ae-89ad-8027-8008-dba0bd5cf454'||penpot.currentPage.id!=='122350ae-89ad-8027-8008-dba0bd5cf455')throw Error('Wrong destination');
const spec=SPEC;const prior=penpot.root.children.find(s=>s.type==='board'&&s.name===spec.name);
const art=penpot.createShapeFromSvg(storage[KEY]);if(!art)throw Error('SVG import failed');let b=prior;if(!b){b=penpot.createBoard();b.name=spec.name;b.resize(spec.w,spec.h);b.x=spec.x;b.y=spec.y;b.fills=[{fillColor:'#F6F7F2',fillOpacity:1}];}const old=prior?[...b.children].map(s=>s.id):[];b.appendChild(art);penpotUtils.setParentXY(art,0,0);art.name='Layered reference artwork / '+spec.screen;
const source=penpotUtils.findShapeById(spec.kind==='design'?'ac11b0df-9658-80a2-8008-dbadcb522959':'ac11b0df-9658-80a2-8008-dbadd18eaab7');let photoCount=0,markerCount=0;
for(const p of spec.photos){const original=penpotUtils.findShape(s=>s.name==='Product photo · '+p.sourceNode,source);if(!original)throw Error('Missing reviewed photo source '+p.sourceNode);const target=penpotUtils.findShapes(s=>s.type==='path'&&Math.abs(s.x-b.x-p.x)<.2&&Math.abs(s.y-b.y-p.y)<.2&&Math.abs(s.width-p.width)<.2&&Math.abs(s.height-p.height)<.2,art).at(-1);if(!target)throw Error('Missing photo geometry '+p.node);target.fills=original.fills;target.name='Product photo · '+p.node;photoCount++;}
for(const p of spec.tiny){const closed=p.kind==='disclosure'&&!p.open;const markerSource=closed?penpotUtils.findShapeById(spec.kind==='design'?'ac11b0df-9658-80a2-8008-dbac713710a2':'ac11b0df-9658-80a2-8008-dbb0068776eb'):source;const original=penpotUtils.findShape(s=>s.fills?.some(f=>f.fillImage)&&Math.abs(s.width-(p.kind==='select'?10:closed?9.5:8))<.3&&Math.abs(s.height-(p.kind==='select'?7:closed?17.5:15))<.3,markerSource);if(!original)throw Error('Missing discrete marker source');const target=penpotUtils.findShapes(s=>s.type==='rectangle'&&Math.abs(s.x-b.x-p.x)<.3&&Math.abs(s.y-b.y-p.y)<.3&&Math.abs(s.width-p.width)<.3&&Math.abs(s.height-p.height)<.3,art)[0];if(!target)throw Error('Missing discrete marker geometry');target.fills=original.fills;target.name='Native '+p.kind+' marker';markerCount++;}
b.setPluginData('phase01-status','Draft reference reproduction; explicit owner approval pending; no UI implementation authorization');b.setPluginData('phase01-source',spec.screen+' '+spec.sourceSha256);b.setPluginData('phase01-original-text',JSON.stringify(spec.text));b.setPluginData('phase01-editability','Layered native vector geometry and outlined lettering; text strings retained in metadata/source JSON. Discrete reviewed photo/marker fills reused; no whole-screen raster.');
for(const id of old){if(id!==art.id)penpotUtils.findShapeById(id)?.remove();}return {id:b.id,art:art.id,name:b.name,screen:spec.screen,kind:spec.kind,x:b.x,y:b.y,w:b.width,h:b.height,photoCount,markerCount};""".replace('SPEC',json.dumps(spec,ensure_ascii=False)).replace('KEY',json.dumps(key))
  codefile=tmp/f'{screen}-{kind}-import.js';codefile.write_text(code);resultfile=out/f'{screen}-{kind}-native.json';call(['run-code',str(codefile),'--out',str(resultfile)]);v=json.loads(resultfile.read_text());ledger.append(v);(out/'import-ledger.json').write_text(json.dumps(ledger,indent=2)+'\n');print(json.dumps({'imported':screen,'kind':kind,'id':v.get('id'),'photos':v.get('photoCount')}),flush=True)
  call(['export',v['id'],str(out/f'{screen}-{kind}.png'),'--scale','2']);print(json.dumps({'exported':screen,'kind':kind}),flush=True)
