#!/usr/bin/env python3
"""Current picker integration entrypoint on the attested disposable iOS27 target only."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import time
import uuid

BASE=Path(__file__).resolve().parent
if hashlib.sha256((BASE/'new-picker-android.py').read_bytes()).hexdigest()!='0ae68fd3aba04d70180ed015848d7d3cd42d2c72d28923d0c4b0010463b8f31b':
    raise RuntimeError('reviewed-android-context-adapter-changed')
spec=importlib.util.spec_from_file_location('new_picker_android_context',BASE/'new-picker-android.py')
a=importlib.util.module_from_spec(spec);spec.loader.exec_module(a)
ROOT=a.ROOT;SOURCE=a.SOURCE;RUNTIME=a.RUNTIME
TARGET=Path('/Users/eros/.codex/worktrees/phase02-build-app/Dakhl_Restaurant/outputs/phase02/native-resume/ios-target.json')
COPY_RECEIPT=TARGET.parent/'ios-import-source-copy.json'
UDID='333B4F90-579C-4D2C-A472-2B3E0CF8F980'
APP_ID='com.eros.dakhlrestaurant.phase00'


def target():
    value=json.loads(TARGET.read_text())
    a.require(value.get('taskCreated') is True and value.get('udid')==UDID and value.get('runtime')=='iOS27.0'
              and value.get('name')=='Phase02 Verification 34c7a192' and value.get('appId')==APP_ID,'disposable-ios-target-attestation-mismatch')
    return value


def plan(stage):
    return {'execute':False,'stage':stage,'sourceRevision':SOURCE,'runtimeRevision':RUNTIME,
            'entrySha256':a.ENTRY_SHA,'supportSha256':a.SUPPORT_SHA,'target':target(),
            'normalTargetsOrAccounts':'FORBIDDEN; only synthetic integration entrypoint on exact task-created simulator',
            'installerScope':'Root explicitly permits flutter test --no-uninstall only on this disposable simulator; flag does not promise preservation/fallback protection',
            'automaticImportCopy':'printed owned source once to unique task-simulator local Files provider filename, SHA verified; no UI input',
            'deviceLifecycle':'Root must boot/revalidate target and announce CUA readiness before --execute; this helper never boots/resets/deletes'}


def copy_import(m,path,nonce,folder):
    container=Path(m.call(['xcrun','simctl','get_app_container',UDID,APP_ID,'data'],timeout=15).strip()).resolve(strict=True)
    source=Path(path)
    a.require(source.is_absolute() and source.resolve(strict=True)==source,'unsafe-ios-fixture-source')
    validate_source_path(source,container,nonce)
    marker=source.parents[1]/'.phase02-fixture-owner'
    a.require(marker.read_text()=='dakhl_restaurant_phase02_picker_conformance_v1\n','ios-fixture-owner-mismatch')
    data=source.read_bytes();a.validate_payload(data,nonce);sha=hashlib.sha256(data).hexdigest()
    provider=Path(json.loads(COPY_RECEIPT.read_text())['selectedCopy']).parent
    expected=Path('/Users/eros/Library/Developer/CoreSimulator/Devices')/UDID/'data/Containers/Shared/AppGroup'
    relative_provider=provider.relative_to(expected)
    a.require(len(relative_provider.parts)==2 and re.fullmatch(r'[A-F0-9-]{36}',relative_provider.parts[0]) and relative_provider.parts[1]=='File Provider Storage'
              and provider.is_dir() and provider.resolve(strict=True)==provider,'unowned-ios-provider')
    selected=provider/('Phase02-'+nonce+'.json')
    with selected.open('xb') as f:f.write(data)
    a.require(a.digest(selected)==sha and a.digest(source)==sha,'ios-copy-sha-mismatch')
    receipt={'source':str(source),'selectedCopy':str(selected),'nonce':nonce,'sha256':sha,'exclusiveCopy':True,
             'scope':'one synthetic fixture in exact task-created simulator; no UI input'}
    m.write_json(folder/'import-copy.json',receipt)
    print('PHASE02_IMPORT_COPY_READY '+json.dumps(receipt),flush=True)
    return receipt


def validate_source_path(source,container,nonce):
    relative=source.relative_to(container).as_posix()
    a.require(re.fullmatch(r'Library/Application Support/dakhl_restaurant_phase02_picker_conformance/'+re.escape(nonce)+r'-import-file-[A-Za-z0-9]+/accounts\.json',relative) is not None,'foreign-ios-fixture-path')


def cleanup_ios(m,folder,record,lock,inode):
    try:
        result=m.subprocess.run(['xcrun','simctl','terminate',UDID,APP_ID],cwd=ROOT,capture_output=True,text=True,timeout=20)
        absent=result.returncode==0 or (result.returncode==3 and bool(re.search(r'found nothing to terminate|not running',result.stderr,re.I)))
        record['terminationExit']=result.returncode;record['ownedAppStoppedOrAlreadyAbsent']=absent
        if not absent:record['expectedOutcomeVerified']=False
    except Exception as error:
        record['terminationErrorType']=type(error).__name__;record['ownedAppStoppedOrAlreadyAbsent']=False;record['expectedOutcomeVerified']=False
    finally:
        try:m.write_json(folder/'result.json',record)
        finally:
            if lock.exists() and lock.stat().st_ino==inode:lock.unlink()


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('stage',choices=['cancel-open','cancel-save','import-file']);p.add_argument('--execute',action='store_true');args=p.parse_args()
    if not args.execute:print(json.dumps(plan(args.stage),indent=2));return 0
    target();folder=BASE/'new-picker-ios-stages'/args.stage
    m=a.legacy(folder);a.check(m)
    booted=json.loads(m.call(['xcrun','simctl','list','devices','booted','-j'],timeout=15))
    devices=[d for rows in booted.get('devices',{}).values() for d in rows if d.get('state')=='Booted']
    a.require(len(devices)==1 and devices[0].get('udid')==UDID and devices[0].get('name')=='Phase02 Verification 34c7a192','exact-disposable-ios-target-not-sole-booted')
    lock=BASE/'new-picker-build.lock';fd=os.open(lock,os.O_CREAT|os.O_EXCL|os.O_WRONLY,0o600);inode=os.fstat(fd).st_ino;os.close(fd)
    try:folder.mkdir(parents=True)
    except BaseException:
        if lock.exists() and lock.stat().st_ino==inode:lock.unlink()
        raise
    nonce=str(uuid.uuid4());record={**plan(args.stage),'execute':True,'startedAt':m.now(),'nonce':nonce,'expectedOutcomeVerified':False,
            'targetDescriptorSha256':a.digest(TARGET),'adapterSha256':a.digest(Path(__file__)),'contextAdapterSha256':a.digest(BASE/'new-picker-android.py')}
    old_clean=m.clean;copied={};copy_errors=[];start=time.monotonic()
    def observe(raw):
        match=re.search(r'PHASE02_PICKER_FIXTURE (.+)',raw)
        if args.stage=='import-file' and match and not copied and not copy_errors:
            try:copied.update(copy_import(m,match[1].strip(),nonce,folder))
            except Exception as error:
                copy_errors.append(type(error).__name__);print('PHASE02_IMPORT_COPY_FAILED '+type(error).__name__,flush=True)
        return old_clean(raw)
    m.clean=observe
    argv=['/Users/eros/Dev/flutter/bin/flutter','test','--no-pub','--no-uninstall',str(ROOT/'integration_test/phase02_file_picker_test.dart'),'-d',UDID,
          '--dart-define=PHASE02_PICKER_STAGE='+args.stage,'--dart-define=PHASE02_RUN_NONCE='+nonce,'-r','expanded']
    record['argv']=argv
    try:
        code=m.stream(argv,folder/'native-runtime.log',timeout=600,cwd=ROOT)
        text=(folder/'native-runtime.log').read_text()
        record['exitCode']=code
        record['expectedOutcomeVerified']=code==0 and 'All tests passed!' in text and f'PHASE02_PICKER_COMPLETE {args.stage} {nonce}' in text
        if args.stage=='import-file':a.require(bool(copied) and not copy_errors,'owned-ios-import-copy-unverified')
        a.require(record['expectedOutcomeVerified'],'ios-picker-outcome-unverified');a.check(m)
    except BaseException as error:
        record.update({'expectedOutcomeVerified':False,'errorType':type(error).__name__,'error':old_clean(str(error))[:300]})
    finally:
        # Exact disposable target/bundle only. No uninstall or target reset.
        record.update({'finishedAt':m.now(),'elapsedSeconds':time.monotonic()-start,'importCopy':copied or None,'copyErrors':copy_errors})
        cleanup_ios(m,folder,record,lock,inode)
    print('PHASE02_NEW_IOS_PICKER_RESULT '+json.dumps({k:record.get(k) for k in ['stage','expectedOutcomeVerified','elapsedSeconds','error']}),flush=True)
    return 0 if record['expectedOutcomeVerified'] else 2


if __name__=='__main__':raise SystemExit(main())
