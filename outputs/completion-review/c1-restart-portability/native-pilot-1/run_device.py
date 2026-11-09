import subprocess,sys,json,time,datetime
from pathlib import Path
base=Path(__file__).resolve().parent
name=sys.argv[1]; args=sys.argv[2:]
command=["/Users/eros/.t3/userdata/device/targets/t3-b91493306db60c230eefae24/agent-device",*args]
t=time.monotonic(); start=datetime.datetime.now(datetime.timezone.utc).isoformat()
p=subprocess.run(command,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
(base/(name+".log")).write_text(p.stdout)
(base/(name+".json")).write_text(json.dumps(dict(argv=command,startUtc=start,endUtc=datetime.datetime.now(datetime.timezone.utc).isoformat(),elapsedSeconds=time.monotonic()-t,exitCode=p.returncode,log=name+".log"),indent=2))
print(p.stdout[:22000]); print("EXIT",p.returncode)
