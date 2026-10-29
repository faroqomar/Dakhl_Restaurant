from pathlib import Path
import subprocess,json,time,hashlib
r=Path('/Users/eros/.codex/worktrees/phase01-build-app/Dakhl_Restaurant');out=r/'outputs/phase01-step4/final';out.mkdir(parents=True,exist_ok=True);records=[]
def check(name,command,timeout=900):
 start=time.time()
 with (out/(name+'.log')).open('w') as log:p=subprocess.run(command,cwd=r,stdout=log,stderr=subprocess.STDOUT,timeout=timeout)
 records.append({'name':name,'command':command,'exitCode':p.returncode,'elapsedSeconds':round(time.time()-start,1)});(out/'checks.json').write_text(json.dumps(records,indent=2)+'\n');print(name,p.returncode,flush=True)
 if p.returncode:raise SystemExit(p.returncode)
check('app-tests',['flutter','test','--no-pub'])
check('app-analysis',['flutter','analyze','--no-pub'])
check('format',['dart','format','--output=none','--set-exit-if-changed','lib','test','integration_test'])
check('engine-source',['python3','scripts/check-engine.py'])
check('android-main-build',['flutter','build','apk','--debug','--no-pub'])
adb='/Users/eros/Library/Android/sdk/platform-tools/adb'
check('android-main-install',[adb,'-s','emulator-5554','install','-r','-t','build/app/outputs/flutter-apk/app-debug.apk'],90)
check('android-main-launch',[adb,'-s','emulator-5554','shell','am','start','-W','-n','com.eros.dakhlrestaurant.phase00/.MainActivity'],45)
(out/'android-ready.json').write_text(json.dumps({'state':'current repaired main launched preserving data','apkSha256':hashlib.sha256((r/'build/app/outputs/flutter-apk/app-debug.apk').read_bytes()).hexdigest(),'sourceAppSha256':hashlib.sha256((r/'lib/app/app.dart').read_bytes()).hexdigest()},indent=2)+'\n')
check('ios-main-build',['flutter','run','--no-pub','--no-resident','-d','4445755D-8F85-40F6-94C4-1ABF06D23981'])
check('macos-main-build',['flutter','build','macos','--debug','--no-pub'])
