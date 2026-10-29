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
nodes=dump('android-after-talkback-off');assert any(n['class']=='android.widget.EditText' and n['text']=='q' for n in nodes)
tap(nodes,'إلغاء');nodes=dump('android-test-fixture-discard-guard');tap(nodes,'تجاهل التغييرات');nodes=dump('android-fixture-discarded');assert any(label(n)=='فواتير المشتريات' for n in nodes) and not any(n['class']=='android.widget.EditText' and n['text']=='q' for n in nodes)
call('swipe','1078','1200','620','1200','350');nodes=dump('android-final-restored-sales');assert any(label(n)=='المبيعات / فاتورة جديدة' for n in nodes);call('screenshot','android-final-clean-main')
p=OUT/'android-native-back-current.json';d=json.loads(p.read_text());d['fixtureState']='explicitly discarded only testfixture; returned original Sales route';d['talkbackSettingsRestored']=True;d['screenReaderTraversal']='pending, not passed';d['cleanupVerified']=True;p.write_text(json.dumps(d,indent=2)+'\n');print('Android TalkBack settings restored; synthetic draft discarded; original Sales route restored',flush=True)
