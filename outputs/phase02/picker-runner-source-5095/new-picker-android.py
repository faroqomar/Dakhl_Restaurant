#!/usr/bin/env python3
"""Exact5095 picker-only adapter over reviewed702; default inert plan, no install."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys
import time

ROOT=Path('/Users/eros/.codex/worktrees/phase02-publish-app/Dakhl_Restaurant')
BASE=Path(__file__).resolve().parent
SOURCE='5095e5cbbad496a5c5e203af4a8a31559bcf26ee'
RUNTIME='a6a8ebdd8f68f5d603d56dc3f3d0f13cc3e38294'
LEGACY=Path('/Users/eros/.codex/worktrees/phase02-build-app/Dakhl_Restaurant/outputs/phase02/native-resume/android_stage.py')
LEGACY_SHA='702b65b1fd57f6a1fbdf457a22364a5b3657938fcd1ff51886b729a1cd9597a8'
ENTRY_SHA='c9354e76a57fd5f4b71f60884fa95d8894531fca334786d245608f8bc0fb64f5'
SUPPORT_SHA='9c908488fee0ed27e398dfd293251eddf60b33ca44c92887f845ca441459f7f1'
DRIVER=LEGACY.parent/'integration_driver.dart'
DRIVER_SHA='b40e3f03ecbb888ba0e020b17db57bd6f9b68fb1deea09fb9877baa675c2c938'
IDENTITY={'fixtureId':'4dd01bf2591c43c18be723a3a6249fd8','package':'com.eros.dakhlrestaurant.phase02.verify.p4dd01bf2591c',
          'avdName':'Phase02_Verify36_4dd01bf2','serial':'emulator-5554','taskCreated':True,'avdCreated':True,
          'sourceRevision':SOURCE,'runtimeRevision':RUNTIME,'booted':True,
          'attestation':'Root verified embedded taskAVD name/serial; guard must independently verify live target'}


def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def require(value,code):
    if not value:raise RuntimeError(code)


def legacy(folder):
    require(digest(LEGACY)==LEGACY_SHA,'reviewed702-mismatch')
    spec=importlib.util.spec_from_file_location('new_picker_reviewed702',LEGACY)
    m=importlib.util.module_from_spec(spec);sys.modules[spec.name]=m;spec.loader.exec_module(m)
    original_call, original_stream=m.call,m.stream
    # Explicit reviewed context adaptation. Both functions otherwise retain an
    # original5a11 cwd in their Python default arguments; never silently use it.
    def call(args,timeout=30,binary=False,env=None,cwd=None):
        return original_call(args,timeout=timeout,binary=binary,env=env,cwd=ROOT if cwd is None else cwd)
    def stream(args,log,timeout,env=None,cwd=None):
        return original_stream(args,log,timeout,env=env,cwd=ROOT if cwd is None else cwd)
    m.call=call;m.stream=stream;m.ROOT=ROOT;m.ENGINE=ROOT.parent/'Madar_Engine';m.BASE=folder;m.SOURCE=SOURCE;m.RUNTIME=RUNTIME
    return m


def check(m):
    m.source_check()
    require(digest(ROOT/'integration_test/phase02_file_picker_test.dart')==ENTRY_SHA,'entry-hash-mismatch')
    require(digest(ROOT/'integration_test/support/native_picker_wait.dart')==SUPPORT_SHA,'support-hash-mismatch')
    require(not m.call(['git','status','--porcelain','--','ios']).strip(),'dirty-ios-source')


def validate_payload(data,nonce):
    require(len(data)<=2*1024*1024,'fixture-copy-too-large')
    value=json.loads(data)
    require(value.get('version')==1 and value['preferences']['restaurant']['name']=='selected-fixture-'+nonce,'not-owned-synthetic-fixture')


def fixture_path(path,nonce):
    package=re.escape(IDENTITY['package'])
    pattern=r'/data/(?:data/'+package+r'|user/0/'+package+r')/files/dakhl_restaurant_phase02_picker_conformance/'+re.escape(nonce)+r'-import-file-[A-Za-z0-9]+/accounts\.json'
    require(re.fullmatch(pattern,path) is not None,'foreign-fixture-path')
    return path


def copy_import(m,path,nonce,folder):
    fixture_path(path,nonce)
    marker=m.adb(IDENTITY,'exec-out','run-as',IDENTITY['package'],'cat','files/dakhl_restaurant_phase02_picker_conformance/.phase02-fixture-owner',timeout=10)
    require(marker=='dakhl_restaurant_phase02_picker_conformance_v1\n','fixture-owner-mismatch')
    data=m.adb(IDENTITY,'exec-out','run-as',IDENTITY['package'],'cat',path,timeout=10,binary=True)
    validate_payload(data,nonce)
    expected=hashlib.sha256(data).hexdigest()
    selected='/sdcard/Download/Phase02-'+nonce+'.json'
    # Android mksh noclobber gives exclusive creation. No adb push overwrite.
    command='set -C; test -d /sdcard/Download && cat > '+shlex.quote(selected)
    r=subprocess.run([str(m.ADB),'-s',IDENTITY['serial'],'shell',command],input=data,capture_output=True,timeout=15)
    require(r.returncode==0,'exclusive-download-copy-failed')
    copied=m.adb(IDENTITY,'exec-out','cat',selected,timeout=10,binary=True)
    require(hashlib.sha256(copied).hexdigest()==expected,'download-copy-sha-mismatch')
    receipt={'source':path,'selectedCopy':selected,'nonce':nonce,'sha256':expected,'exclusiveCopy':True,
             'scope':'one marked synthetic fixture only; no UI input'}
    m.write_json(folder/'import-copy.json',receipt)
    print('PHASE02_IMPORT_COPY_READY '+json.dumps(receipt),flush=True)
    return receipt


def plan(stage,receipt):
    return {'execute':False,'stage':stage,'source':SOURCE,'runtime':RUNTIME,'entrySha256':ENTRY_SHA,'supportSha256':SUPPORT_SHA,
            'identity':IDENTITY,'buildReceipt':str(receipt),'reviewedBaseHelperSha256':LEGACY_SHA,
            'installation':'guardf4 exact-prebuilt existing-fixture with owned backup; no fallback/uninstall',
            'driver':'direct Dart host driver; VM auth URL held only in memory/env and redacted logs',
            'ui':'Root CUA only;120s per manual wait','guardReadiness':'PENDING live guard checks',
            'automaticImportCopy':'own printed nonce fixture to exclusive Download filename, SHA verified once'}


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('stage',choices=['cancel-open','cancel-save','import-file'])
    p.add_argument('--build-receipt',type=Path,required=True);p.add_argument('--execute-prebuilt',action='store_true');args=p.parse_args()
    if not args.execute_prebuilt:print(json.dumps(plan(args.stage,args.build_receipt),indent=2));return 0
    receipt=args.build_receipt.resolve();require(receipt.name=='build-result.json' and receipt.parent.parent==BASE/'new-picker-android-stages','unowned-build-receipt')
    build=json.loads(receipt.read_text());folder=receipt.parent
    require(build.get('buildSucceeded') is True and build.get('sourceRevision')==SOURCE and build.get('runtimeRevision')==RUNTIME and build.get('stage')==args.stage,'build-provenance-mismatch')
    require(build.get('sourceHashes',{}).get('integration_test/support/native_picker_wait.dart')==SUPPORT_SHA and build['sourceHashes'].get('integration_test/phase02_file_picker_test.dart')==ENTRY_SHA,'build-harness-not-bound')
    apk=folder/'fixture.apk';require(build.get('apkPath')==str(apk) and digest(apk)==build.get('apkSha256'),'built-apk-mismatch')
    require(not (folder/'execution-result.json').exists(),'execution-already-recorded')
    m=legacy(folder);check(m);require(digest(DRIVER)==DRIVER_SHA,'driver-source-mismatch')
    driver=folder/'integration_driver.dart'
    with driver.open('xb') as f:f.write(DRIVER.read_bytes())
    lock=folder/'execution.lock';fd=os.open(lock,os.O_CREAT|os.O_EXCL|os.O_WRONLY,0o600);inode=os.fstat(fd).st_ino;os.close(fd)
    record={**plan(args.stage,receipt),'execute':True,'startedAt':m.now(),'nonce':build['nonce'],'expectedOutcomeVerified':False,
            'adapterSha256':digest(Path(__file__)),'builderSha256':build.get('builderSha256'),'buildReceiptSha256':digest(receipt)}
    start=time.monotonic();copied={};copy_errors=[];old_clean=m.clean
    def observe(raw):
        match=re.search(r'PHASE02_PICKER_FIXTURE (.+)',raw)
        if args.stage=='import-file' and match and not copied and not copy_errors:
            try:copied.update(copy_import(m,match[1].strip(),build['nonce'],folder))
            except Exception as error:
                copy_errors.append(type(error).__name__)
                print('PHASE02_IMPORT_COPY_FAILED '+type(error).__name__,flush=True)
        return old_clean(raw)
    m.clean=observe
    try:
        aapt,signer=m.tools();info=m.package_info(apk,aapt,signer,IDENTITY['package'])
        require(info['apkSha256']==build['apkSha256'],'apk-changed-after-build-binding')
        record['apk']=info
        record['installationMode']=m.install(IDENTITY,apk,info,folder,aapt,signer,record)
        m.run_fixture(IDENTITY,'picker',args.stage,args.stage,build['nonce'],folder,record)
        if args.stage=='import-file':require(bool(copied) and not copy_errors,'owned-import-copy-unverified')
        check(m)
    except BaseException as error:
        record.update({'expectedOutcomeVerified':False,'errorType':type(error).__name__,'error':old_clean(str(error))[:300]})
    finally:
        if record.get('targetPreflightVerified') and record.get('installAttempted'):
            try:m.force_stop(IDENTITY);record['finalOwnedAppStopped']=True
            except Exception:record['finalOwnedAppStopped']=False;record['expectedOutcomeVerified']=False
        record.update({'finishedAt':m.now(),'elapsedSeconds':time.monotonic()-start,'importCopy':copied or None,'copyErrors':copy_errors})
        m.write_json(folder/'execution-result.json',record)
        if lock.exists() and lock.stat().st_ino==inode:lock.unlink()
    print('PHASE02_NEW_PICKER_RESULT '+json.dumps({k:record.get(k) for k in ['stage','expectedOutcomeVerified','elapsedSeconds','error']}),flush=True)
    return 0 if record['expectedOutcomeVerified'] else 2


if __name__=='__main__':raise SystemExit(main())
