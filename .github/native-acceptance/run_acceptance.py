"""One owned API35 device, actual free-user Compose UI and a process-cold second invocation."""
import hashlib,io,json,os,pathlib,re,subprocess,tarfile,datetime
PACKAGE='com.kamilunavo.schonerledigt'
METHODS=['createOrderedRoundHandoverAndArchiveThroughRealUi','coldReopenRetainsRoundHandoverAndOriginalCards']
NATIVE_FILES={f'{i:02d}-{name}.png' for i,name in enumerate(['legacy-cards','partial-handover','complete-round','next-round','cold-reopened'],1)}
GENERIC_FILES={'result.json','source-commit.txt','build.log','preflight-anr.txt','installed-identity.txt','scenario.txt','cold-reopen.txt','actual-archive.json','before-cold-archive.json','final-screen.png','window.txt','logcat.txt','final-ui.xml','emulator-stop.txt','avd-delete.txt','remaining-avds.txt','remaining-devices.txt','cleanup.json','cleanup-failed.txt'}
def preflight(call,serial):
 if serial!='emulator-5554':raise RuntimeError('Only the single workflow-owned emulator is permitted')
 if call(['shell','getprop','ro.build.version.sdk']).strip()!=b'35':raise RuntimeError('Expected API35')
 if call(['shell','getprop','ro.kernel.qemu']).strip()!=b'1':raise RuntimeError('Physical devices prohibited')
 anr=call(['shell','dumpsys','activity','lastanr'])
 if b'com.android.systemui' in anr.lower():raise RuntimeError('SystemUI ANR; no dialog dismissal')
 call(['shell','settings','put','secure','show_ime_with_hard_keyboard','1'])
 if call(['shell','settings','get','secure','show_ime_with_hard_keyboard']).strip()!=b'1':raise RuntimeError('Keyboard preference not established')
 return anr

def run(execute=subprocess.run):
 runtime=pathlib.Path(os.environ['RUNNER_TEMP']).resolve();proof=runtime/'schon-native-acceptance'/'schon'
 assert not proof.is_symlink() and not proof.parent.is_symlink();proof.mkdir(parents=True,exist_ok=True,mode=0o700)
 result={'status':'STARTED','package':PACKAGE,'version':'1.1.0(6)','transactions':False,'fixtureRecordsInjected':False,'testMethods':METHODS};validated=False
 def call(args,timeout=15):
  p=execute(['adb','-s','emulator-5554',*args],stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=timeout)
  if p.returncode:raise RuntimeError('Owned adb command failed: '+args[0])
  return p.stdout
 def capture(name,args):
  try:(proof/name).write_bytes(call(args,15))
  except BaseException as e:result.setdefault('diagnostics',{})[name]=type(e).__name__
 try:
  (proof/'preflight-anr.txt').write_bytes(preflight(call,'emulator-5554'));validated=True
  apks=[pathlib.Path('android/app/build/outputs/apk/debug/app-debug.apk'),pathlib.Path('android/app/build/outputs/apk/androidTest/debug/app-debug-androidTest.apk')]
  result['apkSha256']={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in apks}
  for p in apks:call(['install','-r',str(p)],90)
  identity=call(['shell','dumpsys','package',PACKAGE]);(proof/'installed-identity.txt').write_bytes(identity)
  assert re.search(rb'\bversionCode=6(?=\s|$)',identity) and re.search(rb'\bversionName=1\.1\.0(?=\s|$)',identity),'Installed identity mismatch'
  previous=None
  for method,filename in zip(METHODS,['scenario.txt','cold-reopen.txt']):
   if previous is not None:call(['shell','am','force-stop',PACKAGE])
   command=['adb','-s','emulator-5554','shell','am','instrument','-w','-r','-e','class',PACKAGE+'.HouseholdSequenceNativeTest#'+method,PACKAGE+'.test/androidx.test.runner.AndroidJUnitRunner']
   p=execute(command,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=360);text=p.stdout or b'';(proof/filename).write_bytes(text+(p.stderr or b''))
   assert p.returncode==0 and b'OK (1 test)' in text and not any(x in text for x in [b'FAILURES',b'INSTRUMENTATION_FAILED',b'Process crashed']),'Actual native scenario failed: '+method
   actual=call(['exec-out','run-as',PACKAGE,'cat','files/SchonErledigt/sequences.json'])
   document=json.loads(actual);assert document['schemaVersion']==1 and len(document['sequences'])==1
   value=document['sequences'][0];assert len(value['rounds'])==1 and len(value['rounds'][0]['completedIDs'])==3 and len(value['rounds'][0]['handovers'][0]['pendingIDs'])==2
   if previous is None:(proof/'before-cold-archive.json').write_bytes(actual);previous=actual
   else:assert previous==actual,'Cold reopen changed immutable archive';(proof/'actual-archive.json').write_bytes(actual)
  result['archiveSha256']=hashlib.sha256(previous).hexdigest()
  result['status']='PASSED'
 except BaseException as e:result['status']='FAILED';result['error']=str(e)
 finally:
  if validated:
   capture('final-screen.png',['exec-out','screencap','-p']);capture('window.txt',['shell','dumpsys','window','windows']);capture('logcat.txt',['logcat','-d','-t','1500'])
   try:
    call(['shell','uiautomator','dump','/sdcard/schon-native.xml'],15);capture('final-ui.xml',['exec-out','cat','/sdcard/schon-native.xml'])
   except BaseException:pass
   try:
    packed=call(['exec-out','run-as',PACKAGE,'tar','-cf','-','-C','files','native-proof'],20);assert len(packed)<32*1024*1024
    found=set()
    with tarfile.open(fileobj=io.BytesIO(packed)) as t:
     for m in t.getmembers():
      if m.isdir():continue
      p=pathlib.PurePosixPath(m.name);assert m.isfile() and p.parent==pathlib.PurePosixPath('native-proof') and p.name in NATIVE_FILES and p.name not in found and m.size<8*1024*1024
      found.add(p.name);(proof/p.name).write_bytes(t.extractfile(m).read())
    if result['status']=='PASSED':assert found==NATIVE_FILES,'Incomplete actual native screenshot evidence'
   except BaseException as e:
    result.setdefault('diagnostics',{})['nativeEvidence']=str(e)
    if result['status']=='PASSED':result.update(status='FAILED',error='Native evidence incomplete')
   try:call(['shell','am','force-stop',PACKAGE])
   except BaseException:pass
  result['finishedUTC']=datetime.datetime.now(datetime.timezone.utc).isoformat();(proof/'result.json').write_text(json.dumps(result,indent=2)+'\n')
 return result
if __name__=='__main__':
 os.umask(0o077);r=run();print(json.dumps({'status':r['status'],'evidence':'encrypted artifact only'}));raise SystemExit(0 if r['status']=='PASSED' else 1)
