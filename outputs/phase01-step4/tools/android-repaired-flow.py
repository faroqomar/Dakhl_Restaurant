from pathlib import Path
import subprocess,json,re,hashlib
ROOT=Path('/Users/eros/.codex/worktrees/phase01-build-app/Dakhl_Restaurant');OUT=ROOT/'outputs/phase01-step4';HELP='/tmp/phase01-step4-android-ui.py';ADB='/Users/eros/Library/Android/sdk/platform-tools/adb'
def call(*args):
 return subprocess.run(['python3',HELP,*args],check=True,capture_output=True,text=True,timeout=40).stdout
def dump(label):
 call('dump',label);return json.loads((OUT/(label+'.json')).read_text())
def label(n):return n['text'] or n['content-desc']
def tap(nodes,name):
 found=[n for n in nodes if label(n)==name and n['clickable']=='true'];assert len(found)==1,(name,len(found));x1,y1,x2,y2=map(int,re.findall(r'\d+',found[0]['bounds']));call('tap',str((x1+x2)//2),str((y1+y2)//2))
nodes=dump('android-repaired-start');tap(nodes,'القائمة الرئيسية');nodes=dump('android-repaired-menu');tap(nodes,'المخزن');nodes=dump('android-repaired-inventory');assert any(label(n)=='المخزن' for n in nodes)
pre=subprocess.run([ADB,'-s','emulator-5554','shell','dumpsys','activity','activities'],capture_output=True,text=True).stdout
call('back');nodes=dump('android-repaired-key-back');keyPassed=any(label(n)=='المبيعات / فاتورة جديدة' for n in nodes)
post=subprocess.run([ADB,'-s','emulator-5554','shell','dumpsys','activity','activities'],capture_output=True,text=True).stdout
(OUT/'android-repaired-key-back.json').write_text(json.dumps({'pass':keyPassed,'beforeActivity':[l.strip() for l in pre.splitlines() if 'topResumedActivity' in l],'afterActivity':[l.strip() for l in post.splitlines() if 'topResumedActivity' in l],'originalFailedAttemptPreserved':True},indent=2)+'\n')
print('Repaired Android KEYCODE_BACK:',keyPassed,flush=True)
assert keyPassed,'Native legacy key repeat stillfailed; inspect saved state before more input'
tap(nodes,'القائمة الرئيسية');nodes=dump('android-repaired-edge-menu');tap(nodes,'المخزن');nodes=dump('android-repaired-edge-inventory');assert any(label(n)=='المخزن' for n in nodes)
call('swipe','1078','1200','620','1200','350');nodes=dump('android-repaired-edge-sales');assert any(label(n)=='المبيعات / فاتورة جديدة' for n in nodes);call('screenshot','android-repaired-edge-sales');print('Repaired actual Android edge Inventory→Sales PASS',flush=True)
tap(nodes,'القائمة الرئيسية');nodes=dump('android-repaired-invoice-menu');tap(nodes,'فواتير المشتريات');nodes=dump('android-repaired-invoice-shell');tap(nodes,'قائمة جديدة');nodes=dump('android-repaired-invoice-form')
for i,n in enumerate(nodes):
 if n['class']=='android.widget.EditText' or any(x in label(n) for x in ['المادة','إلغاء','حفظ']):print(i,n['class'].split('.')[-1],label(n),n['bounds'],flush=True)
(OUT/'android-native-back-progress.json').write_text(json.dumps({'cleanNativeBack':'pass on repairedsource','legacyKeyRepeat':'pass on repairedsource','actualInputs':['adbKEYCODE_BACK','actualrightedgegesture'],'developmentAppOnly':True,'startRoute':'Sales','currentState':'synthetic invoice form open, no edit/domainsave yet','talkBack':'notenabledyet'},indent=2)+'\n')
