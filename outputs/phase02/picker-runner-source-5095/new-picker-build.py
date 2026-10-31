#!/usr/bin/env python3
"""Compile one exact-head Android picker fixture; never calls a device/installer."""
import argparse
import base64
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import time
import uuid

ROOT = Path('/Users/eros/.codex/worktrees/phase02-publish-app/Dakhl_Restaurant')
BASE = Path(__file__).resolve().parent
SOURCE = '5095e5cbbad496a5c5e203af4a8a31559bcf26ee'
RUNTIME = 'a6a8ebdd8f68f5d603d56dc3f3d0f13cc3e38294'
PACKAGE = 'com.eros.dakhlrestaurant.phase02.verify.p4dd01bf2591c'
WRAPPER = Path('/Users/eros/.codex/worktrees/phase02-build-app/Dakhl_Restaurant/android/gradlew')
WRAPPER_HASHES = {WRAPPER: 'ec56c02543666d92d9ac5ae7fcc48f88ce4de0deb8b7f9b39928ca46f68c1b2b',
                  WRAPPER.parent/'gradle/wrapper/gradle-wrapper.jar': '16caeaf66d57a0d1d2087fef6a97efa62de8da69afa5b908f40db35afc4342da',
                  WRAPPER.parent/'gradle/wrapper/gradle-wrapper.properties': 'b690d26223576fe4e63889fad9a00df81945cb870b9476cc5a563152a1a88a74'}
HASHES = {'integration_test/phase02_file_picker_test.dart': 'c9354e76a57fd5f4b71f60884fa95d8894531fca334786d245608f8bc0fb64f5',
          'integration_test/support/native_picker_wait.dart': '9c908488fee0ed27e398dfd293251eddf60b33ca44c92887f845ca441459f7f1',
          'scripts/android_install_guard.py': 'f4c9a44a8efeec88c6d107dfabd7e0327bb191133230b43e51be16e45cbd219b'}


def digest(p):
    h = hashlib.sha256()
    with p.open('rb') as f:
        for b in iter(lambda:f.read(1024*1024), b''): h.update(b)
    return h.hexdigest()


def require(value, code):
    if not value: raise RuntimeError(code)


def check():
    def call(argv):
        return subprocess.run(argv,cwd=ROOT,capture_output=True,text=True,timeout=60,check=True).stdout.strip()
    require(call(['git','rev-parse','HEAD']) == SOURCE,'source-head-mismatch')
    require(call(['git','-C',str(ROOT.parent/'Madar_Engine'),'rev-parse','HEAD']) == RUNTIME,'runtime-head-mismatch')
    require(not call(['git','status','--porcelain','--','lib','test','integration_test','android','ios','pubspec.yaml','pubspec.lock','engine-dependency.json']),'dirty-scoped-source')
    for name, expected in HASHES.items():require(digest(ROOT/name)==expected,'source-hash-mismatch')
    call(['python3','scripts/check-engine.py'])


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('stage',choices=['cancel-open','cancel-save','import-file'])
    parser.add_argument('--compile',action='store_true')
    parser.add_argument('--attempt',default='build01')
    args=parser.parse_args()
    if not args.compile:
        print(json.dumps({'execute':False,'source':SOURCE,'runtime':RUNTIME,'hashes':HASHES,'stage':args.stage,'device_commands':False}))
        return 0
    check()
    require(args.attempt.isalnum() and len(args.attempt)<=32,'unsafe-attempt-name')
    for path, expected in WRAPPER_HASHES.items():require(path.is_file() and digest(path)==expected,'wrapper-source-mismatch')
    require(digest(ROOT/'android/gradle/wrapper/gradle-wrapper.properties')==WRAPPER_HASHES[WRAPPER.parent/'gradle/wrapper/gradle-wrapper.properties'],'wrapper-configuration-mismatch')
    require(Path('/Library/Java/JavaVirtualMachines/jdk-24.jdk/Contents/Home/bin/java').is_file(),'java24-missing')
    lock=BASE/'new-picker-build.lock'
    fd=os.open(lock,os.O_CREAT|os.O_EXCL|os.O_WRONLY,0o600);inode=os.fstat(fd).st_ino;os.close(fd)
    folder=BASE/'new-picker-android-stages'/(args.stage+'-'+args.attempt)
    try:folder.mkdir(parents=True)
    except BaseException:
        if lock.stat().st_ino==inode:lock.unlink()
        raise
    nonce=str(uuid.uuid4())
    record={'sourceRevision':SOURCE,'runtimeRevision':RUNTIME,'stage':args.stage,'nonce':nonce,'sourceHashes':HASHES,
            'package':PACKAGE,'startedAt':datetime.now(timezone.utc).isoformat(),'buildSucceeded':False,'deviceCommands':False}
    record['wrapperHashes']={str(p):h for p,h in WRAPPER_HASHES.items()}
    started=time.monotonic()
    try:
        init=folder/'fixture.init.gradle'
        init.write_text("// Task-only existing marked fixture namespace; no product configuration edit.\n"+
            "gradle.beforeProject { project -> project.plugins.withId('com.android.application') { project.extensions.getByName('androidComponents').finalizeDsl { android -> android.defaultConfig.applicationId = '"+PACKAGE+"' } } }\n")
        defines=','.join(base64.b64encode(x.encode()).decode() for x in ['PHASE02_PICKER_STAGE='+args.stage,'PHASE02_RUN_NONCE='+nonce])
        argv=[str(WRAPPER),'-p',str(ROOT/'android'),'--no-daemon','--console=plain','--init-script',str(init),
              '-Ptarget='+str(ROOT/'integration_test/phase02_file_picker_test.dart'),'-Ptarget-platform=android-arm64','-Pdart-defines='+defines,
              '-Pdart-obfuscation=false','-Ptrack-widget-creation=true','-Ptree-shake-icons=false','assembleDebug']
        record['buildArgv']=argv;record['initSha256']=digest(init)
        (folder/'build-intent.json').write_text(json.dumps(record,indent=2)+'\n')
        env=os.environ.copy();env['JAVA_HOME']='/Library/Java/JavaVirtualMachines/jdk-24.jdk/Contents/Home'
        fresh=time.time_ns()
        with (folder/'build.log').open('x') as log:
            result=subprocess.run(argv,cwd=ROOT/'android',env=env,stdout=log,stderr=subprocess.STDOUT,timeout=1200)
        record['buildExitCode']=result.returncode
        require(result.returncode==0,'gradle-build-failed')
        check()
        built=ROOT/'build/app/outputs/apk/debug/app-debug.apk'
        require(built.is_file() and not built.is_symlink() and built.stat().st_mtime_ns>=fresh,'fresh-apk-unverified')
        apk=folder/'fixture.apk'
        with built.open('rb') as source,apk.open('xb') as target:shutil.copyfileobj(source,target)
        record.update({'buildSucceeded':True,'apkPath':str(apk),'apkSha256':digest(apk),'builderSha256':digest(Path(__file__))})
    except Exception as error:
        record['errorType']=type(error).__name__
        record['error']=str(error) if isinstance(error,RuntimeError) else 'build-operation-failed; see bounded task log'
    finally:
        record['finishedAt']=datetime.now(timezone.utc).isoformat();record['elapsedSeconds']=time.monotonic()-started
        (folder/'build-result.json').write_text(json.dumps(record,indent=2)+'\n')
        if lock.exists() and lock.stat().st_ino==inode:lock.unlink()
    print(json.dumps(record),flush=True)
    return 0 if record['buildSucceeded'] else 2


if __name__=='__main__':raise SystemExit(main())
