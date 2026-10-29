import json,subprocess,hashlib
from pathlib import Path
r=Path('/Users/eros/.codex/worktrees/phase01-scope-app/Dakhl_Restaurant');o=r/'outputs/penpot/phase01/native-exports';helper='/Users/eros/.codex/skills/penpot/scripts/penpot-client.mjs'
def code(text,name):
 f=o/(name+'.js');f.write_text(text);p=o/(name+'.json');v=subprocess.run(['node',helper,'run-code',str(f),'--out',str(p)],cwd=r,text=True,capture_output=True)
 if v.returncode:raise RuntimeError(v.stderr or v.stdout)
 return json.loads(p.read_text())
text=json.loads((r/'outputs/penpot/phase01/reference-data/desktop-sales.json').read_text())['texts'];strings=[t.get('characters',t.get('text','')) for t in text]
code("const copy="+json.dumps(strings,ensure_ascii=False)+";for(const id of ['812c55ce-996a-805c-8008-dcf124e008ef','812c55ce-996a-805c-8008-dcf1263a146e'])penpotUtils.findShapeById(id).setPluginData('phase01-original-text',JSON.stringify(copy));return {metadataOnly:true};",'reference-text-metadata')
roots=code("return penpot.root.children.filter(s=>s.type==='board'&&s.name.startsWith('01 ·')).map(b=>({id:b.id,name:b.name,x:b.x,y:b.y,w:b.width,h:b.height,clipContent:b.clipContent,status:b.getPluginData('phase01-status')}));",'board-manifest')
assert len(roots)==22
result=[]
for i in range(0,len(roots),4):
 ids=[b['id'] for b in roots[i:i+4]]
 js="const ids="+json.dumps(ids)+";return ids.map(id=>{const b=penpotUtils.findShapeById(id),all=penpotUtils.findShapes(()=>true,b),counts={},images=[];for(const s of all){counts[s.type]=(counts[s.type]||0)+1;for(const f of s.fills||[])if(f.fillImage)images.push({shape:s.id,name:s.name,w:s.width,h:s.height,imageW:f.fillImage.width,imageH:f.fillImage.height,wholeScreen:s.width>=b.width*.85&&s.height>=b.height*.85});}return {id:b.id,name:b.name,counts,imageFills:images,originalStringsRetained:!!b.getPluginData('phase01-original-text'),editableTextCount:counts.text||0,source:b.getPluginData('phase01-source')};});"
 result.extend(code(js,'layer-audit-'+str(i//4)))
prior=[('ac11b0df-9658-80a2-8008-dba3890ab081','Superseded · 00 · Baseline · Wireframes and design',-15000,0,2460,4060),('ac11b0df-9658-80a2-8008-dba38a39c1cc','Superseded · 00 · Action components',-15000,0,500,280),('ac11b0df-9658-80a2-8008-dbac713710a2','00 · Design · Settings and data / الإعدادات والبيانات',3040,0,1440,1000),('ac11b0df-9658-80a2-8008-dbadcd99fbd0','00 · Design · Daily expenses / المصاريف اليومية',1520,0,1440,1000),('ac11b0df-9658-80a2-8008-dbadcb522959','00 · Design · Sales / المبيعات',0,0,1440,1000),('ac11b0df-9658-80a2-8008-dbadd18eaab7','00 · Wireframe · Sales / المبيعات',0,1226,1440,1000),('ac11b0df-9658-80a2-8008-dbadd43f22a2','00 · Wireframe · Daily expenses / المصاريف اليومية',1520,1226,1440,1000),('ac11b0df-9658-80a2-8008-dbb0068776eb','00 · Wireframe · Settings and data / الإعدادات والبيانات',3040,1226,1440,1000)]
preserved=code("const prior="+json.dumps(prior,ensure_ascii=False)+";return prior.map(([id,name,x,y,w,h])=>{const b=penpotUtils.findShapeById(id);return {id,preserved:!!b&&b.name===name&&b.x===x&&b.y===y&&b.width===w&&b.height===h};});",'prior-board-preservation')
assert all(x['preserved'] for x in preserved)
assert not any(x['wholeScreen'] for v in result for x in v['imageFills'])
(o/'native-layer-audit.json').write_text(json.dumps({'file':'122350ae-89ad-8027-8008-dba0bd5cf454','page':'122350ae-89ad-8027-8008-dba0bd5cf455','boards':result,'priorBoards':preserved,'wholeScreenRasterFills':0},indent=2,ensure_ascii=False)+'\n')
print(json.dumps({'boards':len(roots),'preservedPrior':len(preserved),'wholeScreenRasterFills':0,'editableProposalTextShapes':sum(x['editableTextCount'] for x in result if 'Proposal' in x['name'])}),flush=True)
