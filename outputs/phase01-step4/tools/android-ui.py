import subprocess,xml.etree.ElementTree as ET,json,uuid,re,sys,pathlib
ADB='/Users/eros/Library/Android/sdk/platform-tools/adb'
ROOT=pathlib.Path('/Users/eros/.codex/worktrees/phase01-build-app/Dakhl_Restaurant')
OUT=ROOT/'outputs/phase01-step4';OUT.mkdir(exist_ok=True)
def adb(*args):
 p=subprocess.run([ADB,'-s','emulator-5554',*args],capture_output=True,timeout=25)
 if p.returncode:raise RuntimeError('ADB failed '+str(args[:3])+': '+p.stderr.decode(errors='replace')[-200:])
 return p.stdout
if sys.argv[1]=='dump':
 remote='/sdcard/phase01-step4-'+str(uuid.uuid4())+'.xml'
 assert subprocess.run([ADB,'-s','emulator-5554','shell','test','-e',remote]).returncode!=0
 try:
  adb('shell','uiautomator','dump',remote)
  xml=adb('exec-out','cat',remote);nodes=[]
  for n in ET.fromstring(xml).iter('node'):
   a=n.attrib
   if a.get('package') not in ['com.eros.dakhlrestaurant.phase00','com.google.android.marvin.talkback']:continue
   if a.get('text') or a.get('content-desc') or a.get('clickable')=='true' or a.get('class')=='android.widget.EditText':
    nodes.append({k:a.get(k,'') for k in ['class','text','content-desc','clickable','focusable','focused','enabled','bounds']})
  label=sys.argv[2];(OUT/(label+'.json')).write_text(json.dumps(nodes,ensure_ascii=False,indent=2)+'\n')
  for i,n in enumerate(nodes[:45]):print(i,n['class'].split('.')[-1],(n['text'] or n['content-desc'])[:65],n['bounds'],'focused='+n['focused'])
 finally:adb('shell','rm',remote)
elif sys.argv[1]=='tap':
 adb('shell','input','tap',sys.argv[2],sys.argv[3])
elif sys.argv[1]=='back':adb('shell','input','keyevent','KEYCODE_BACK')
elif sys.argv[1]=='text':adb('shell','input','text',sys.argv[2])
elif sys.argv[1]=='swipe':adb('shell','input','swipe',*sys.argv[2:])
elif sys.argv[1]=='screenshot':
 (OUT/(sys.argv[2]+'.png')).write_bytes(adb('exec-out','screencap','-p'));print('Saved screenshot',sys.argv[2])
