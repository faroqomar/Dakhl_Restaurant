from pathlib import Path
import subprocess,json,time,signal
ROOT=Path('/Users/eros/.codex/worktrees/phase01-build-app/Dakhl_Restaurant');OUT=ROOT/'outputs/phase01-step4';ADB='/Users/eros/Library/Android/sdk/platform-tools/adb';STOP=OUT/'talkback-stop.request';BASE=OUT/'talkback-runtime-baseline.json';STATUS=OUT/'talkback-lifecycle.json'
assert not STOP.exists() and not BASE.exists(), 'Do not overwrite an existing talkback operation'
def adb(*args):
 p=subprocess.run([ADB,'-s','emulator-5554',*args],capture_output=True,text=True,timeout=20)
 if p.returncode:raise RuntimeError('ADB '+str(args[:3])+' failed')
 return p.stdout.strip()
keys=['enabled_accessibility_services','accessibility_enabled'];before={k:adb('shell','settings','get','secure',k) for k in keys};BASE.write_text(json.dumps(before,indent=2)+'\n');record={'authorizedByOwner':True,'target':'emulator-5554 development AVD','before':before,'state':'baseline captured; cleanup registered','maxSeconds':900};STATUS.write_text(json.dumps(record,indent=2)+'\n')
def save():STATUS.write_text(json.dumps(record,indent=2)+'\n')
def stop(sig,frame):raise KeyboardInterrupt()
signal.signal(signal.SIGTERM,stop);signal.signal(signal.SIGINT,stop)
try:
 services=[] if before[keys[0]] in ['null',''] else before[keys[0]].split(':');talkback='com.google.android.marvin.talkback/.TalkBackService'
 if talkback not in services:services.append(talkback)
 adb('shell','settings','put','secure',keys[0],':'.join(services));adb('shell','settings','put','secure',keys[1],'1');record['state']='TalkBack enabled; awaiting requested stop or bounded timeout';save();print('TalkBack enabled; failure-safe restore active',flush=True)
 deadline=time.monotonic()+900
 while not STOP.exists() and time.monotonic()<deadline:time.sleep(.25)
 record['stopReason']='explicit completed test' if STOP.exists() else 'bounded timeout'
finally:
 errors=[]
 for k,v in before.items():
  try:
   if v=='null':adb('shell','settings','delete','secure',k)
   else:adb('shell','settings','put','secure',k,v)
  except BaseException:errors.append(k)
 after={k:adb('shell','settings','get','secure',k) for k in keys};record.update(state='restored' if before==after and not errors else 'restore failed',after=after,restoreErrors=errors,settingsMatchBefore=before==after);save();print('TalkBack cleanup',record['state'],flush=True)
