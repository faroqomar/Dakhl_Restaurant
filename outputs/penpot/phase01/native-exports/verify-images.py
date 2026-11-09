import io,json,hashlib
from pathlib import Path
from PIL import Image,ImageCms
import numpy as np
r=Path('/Users/eros/.codex/worktrees/phase01-scope-app/Dakhl_Restaurant');base=r/'outputs/penpot/phase01';out=base/'native-exports';refs=r/'docs/planning/flutter-rebuild'
records=json.loads((out/'import-ledger.json').read_text())
records += [
 {'screen':'desktop-sales','kind':'design','id':'812c55ce-996a-805c-8008-dcf124e008ef','w':1440,'h':1000},
 {'screen':'desktop-sales','kind':'wireframe','id':'812c55ce-996a-805c-8008-dcf1263a146e','w':1440,'h':1000},
 {'screen':'component-states','kind':'design','id':'812c55ce-996a-805c-8008-dcf1d06dbde5','w':1440,'h':1200},
 {'screen':'component-states','kind':'wireframe','id':'812c55ce-996a-805c-8008-dcf1d6c3dfdf','w':1440,'h':1200},
 {'screen':'phone-invoice-adaptation','kind':'design','id':'812c55ce-996a-805c-8008-dcf2225706d4','w':390,'h':844},
 {'screen':'phone-invoice-adaptation','kind':'wireframe','id':'812c55ce-996a-805c-8008-dcf22540a496','w':390,'h':844},
 {'screen':'large-text-320','kind':'design','id':'812c55ce-996a-805c-8008-dcf2288ed2eb','w':320,'h':1100},
 {'screen':'large-text-320','kind':'wireframe','id':'812c55ce-996a-805c-8008-dcf22acd25e2','w':320,'h':1100}]
assert len(records)==22 and len({(x['screen'],x['kind']) for x in records})==22
frozen={x['id']:x for x in json.loads((refs/'screenshot-manifest.json').read_text())['screenshots']};selected={'design-system','desktop-navigation','desktop-invoice-new','phone-invoice-new','desktop-sales','phone-sales'}
for x in records:
 p=out/(x['screen']+'-'+x['kind']+'.png');x['png']=p.name;x['sha256']=hashlib.sha256(p.read_bytes()).hexdigest()
 with Image.open(p) as im:assert im.size==(x['w']*2,x['h']*2);x['pixelSize']=list(im.size)
 if x['kind']=='design' and x['screen'] in selected:
  s=frozen[x['screen']];sp=refs/'screenshots'/s['file'];assert hashlib.sha256(sp.read_bytes()).hexdigest()==s['sha256']
  with Image.open(sp) as orig, Image.open(p) as native:
   def srgb(im):
    rgb=im.convert('RGB');icc=im.info.get('icc_profile')
    return ImageCms.profileToProfile(rgb,ImageCms.ImageCmsProfile(io.BytesIO(icc)),ImageCms.createProfile('sRGB'),outputMode='RGB') if icc else rgb
   a=np.asarray(srgb(orig),dtype=np.int16);b=np.asarray(srgb(native),dtype=np.int16);diff=np.abs(a-b)
   x['referenceComparison']={'sourceSha256':s['sha256'],'equalDimensions':a.shape==b.shape,'sourceICC':bool(orig.info.get('icc_profile')),'nativeICC':bool(native.info.get('icc_profile')),'condition':'ICC to sRGB when present; untagged PNG assumed sRGB; RGB unmasked; scale2','meanAbsoluteRGBError':round(float(diff.mean()),6),'changedPixelRatio':round(float(np.any(diff,axis=2).mean()),6),'maxChannelDifference':int(diff.max()),'acceptance':'No aggregate threshold; actual native visual review and explicit owner approval required.'}
manifest={'date':'2026-10-29','file':'122350ae-89ad-8027-8008-dba0bd5cf454','page':'122350ae-89ad-8027-8008-dba0bd5cf455','status':'Native export set prepared for independent review and explicit owner approval','boards':records,'frozenReferenceHashMatches':6,'noRuntimeVerification':True}
(out/'native-manifest.json').write_text(json.dumps(manifest,indent=2,ensure_ascii=False)+'\n')
print(json.dumps({'nativePNGs':len(records),'dimensionsMatched':22,'frozenHashesMatched':6,'comparisons':{x['screen']:x['referenceComparison']['meanAbsoluteRGBError'] for x in records if 'referenceComparison' in x}},indent=2))
