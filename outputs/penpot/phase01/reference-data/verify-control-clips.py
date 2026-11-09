from pathlib import Path
import importlib.util,json,hashlib,xml.etree.ElementTree as E
p=Path(__file__).parent/'build-artwork-phase01.py';spec=importlib.util.spec_from_file_location('build_phase01',p);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);art=p.parent.parent/'source-artwork';updates=[];reports=[]
for screen in ['desktop-invoice-new','phone-invoice-new']:
 for wire in [False,True]:updates.append(m.build(screen,wire))
 a=json.loads((art/(screen+'-control-clips.json')).read_text());omitted=[x for x in a['controls']if x['omitted']];kept=[x for x in a['controls']if not x['omitted']];markers=[x for x in a['markers']if not x['omitted']];assert not any(x['partialClip']for x in kept+markers)
 for wire in [False,True]:
  f=art/(screen+('-wireframe'if wire else'-design')+'.svg');r=E.parse(f).getroot();ids={g.get('id','').split(' ')[0]for g in r.iter()};assert all(x['runId']not in ids for x in omitted);assert all(x['runId']in ids for x in kept)
  for x in kept:
   clip=r.find('.//{http://www.w3.org/2000/svg}clipPath[@id="clip-'+x['runId']+'"]/{http://www.w3.org/2000/svg}rect');assert clip is not None
   assert all(abs(float(clip.get(k))-x['appliedPaintClip'][k])<.001 for k in ['x','y','width','height'])
 reports.append({'screen':screen,'omitted':[(x.get('ownerDomId'),x.get('text'),x['reason'])for x in omitted],'keptShadowRuns':len(kept),'markers':markers,'partialKeptRuns':0,'files':{u['file']:hashlib.sha256((art/u['file']).read_bytes()).hexdigest()for u in updates if u['screen']==screen}})
allstats=json.loads((art/'artwork-manifest.json').read_text());allstats=[next((u for u in updates if u['file']==x['file']),x)for x in allstats];(art/'artwork-manifest.json').write_text(json.dumps(allstats,indent=2)+'\n');v=json.loads((art/'source-verification.json').read_text())
for x in v['artwork']:
 u=next((u for u in updates if u['file']==x['file']),None)
 if u:
  x.update(u);f=art/u['file'];x['sha256']=hashlib.sha256(f.read_bytes()).hexdigest();x['svgImageElements']=len(E.parse(f).getroot().findall('.//{http://www.w3.org/2000/svg}image'))
v['finalInvoiceClipRepair']='See invoice-control-clipping-verification.json and per-screen control-clips.json: missing/clipped actual owners omitted; text/indicator/disclosure clip paths use actual owner-visible bounds intersected with inherited source clip; no geometric fallback. All kept runs fully inside clip, so no partial-glyph importer clipping is required.';(art/'source-verification.json').write_text(json.dumps(v,ensure_ascii=False,indent=2)+'\n');(art/'invoice-control-clipping-verification.json').write_text(json.dumps({'scope':'Only four invoice SVGs rebuilt; source geometry/capture/semantics and other SVGs preserved.','nativeImporterClipSupport':'Not assumed; all kept shadow runs/markers fully inside actual source paint clip, so current fixes work by omitting fully clipped owners.','reports':reports},ensure_ascii=False,indent=2)+'\n');print(json.dumps(reports,ensure_ascii=False,indent=2))
