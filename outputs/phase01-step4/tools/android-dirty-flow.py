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
nodes=json.loads((OUT/'android-repaired-invoice-form.json').read_text());field=nodes[9];assert field['class']=='android.widget.EditText' and not label(field)
x1,y1,x2,y2=map(int,re.findall(r'\d+',field['bounds']));call('tap',str((x1+x2)//2),str((y1+y2)//2));call('text','q');nodes=dump('android-repaired-dirty-q');assert any(n['class']=='android.widget.EditText' and n['text']=='q' for n in nodes)
call('swipe','1078','1000','620','1000','350');nodes=dump('android-repaired-dirty-back-first');edges=1
if not any(label(n)=='تغييرات غير محفوظة' for n in nodes):
 assert any(n['class']=='android.widget.EditText' and n['text']=='q' for n in nodes)
 call('swipe','1078','1000','620','1000','350');nodes=dump('android-repaired-dirty-back-guard');edges=2
assert any(label(n)=='تغييرات غير محفوظة' for n in nodes);call('screenshot','android-repaired-dirty-back-guard');tap(nodes,'متابعة التعديل');nodes=dump('android-repaired-dirty-retained');assert any(n['class']=='android.widget.EditText' and n['text']=='q' for n in nodes);call('screenshot','android-repaired-dirty-retained')
(OUT/'android-native-back-current.json').write_text(json.dumps({'source':'final repaired147test source, current main APK','legacyKeyRepeat':'pass afterregistrationrepair','systemEdgeInventoryToSales':'pass','dirtySystemEdge':'pass, guarded modal decision, never discarded silently','edgeCountWithIme':edges,'continueEditingRetainedQ':True,'domainSaveSubmitted':False,'fixtureState':'q retained temporarily for authorized TalkBack checks, cleanup pending','accessibilitySettingsUnchangedSoFar':True},indent=2)+'\n');print('Android native clean+dirty Back PASSED; q retained for TalkBack',flush=True)
