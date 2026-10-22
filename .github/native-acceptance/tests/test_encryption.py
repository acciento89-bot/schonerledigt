import pathlib,tempfile,unittest,subprocess,os,json,sys
ROOT=pathlib.Path(__file__).resolve().parents[1]
class EncryptionTests(unittest.TestCase):
 def setUp(self):
  self.t=tempfile.TemporaryDirectory();self.addCleanup(self.t.cleanup);self.base=pathlib.Path(self.t.name);self.raw=self.base/'schon-native-acceptance/schon';self.raw.mkdir(parents=True);(self.raw/'result.json').write_text('{"status":"FAILED","synthetic":true}');self.out=self.base/'schon-native-encrypted/schon/acceptance.cms';self.cert=ROOT/'shk-ci-diagnostics.public.pem'
 def run_encrypt(self,raw=None,cert=None):
  return subprocess.run([sys.executable,str(ROOT/'encrypt_evidence.py'),str(raw or self.raw),str(self.out),str(cert or self.cert)],env={**os.environ,'RUNNER_TEMP':str(self.base)},capture_output=True,timeout=20)
 def test_real_public_certificate_cms_valid_and_raw_removed(self):
  result=self.run_encrypt();self.assertEqual(result.returncode,0,result.stderr);self.assertFalse(self.raw.exists());self.assertTrue(self.out.is_file());self.assertGreater(self.out.stat().st_size,100);check=subprocess.run(['openssl','cms','-cmsout','-inform','DER','-in',str(self.out),'-noout'],capture_output=True);self.assertEqual(check.returncode,0)
 def test_unexpected_file_fails_without_ciphertext_or_raw_deletion(self):
  (self.raw/'customer-database.dump').write_text('not allowed');self.assertNotEqual(self.run_encrypt().returncode,0);self.assertTrue(self.raw.exists());self.assertFalse(self.out.exists())
 def test_symlink_and_hardlink_fail_closed(self):
  target=self.base/'elsewhere';target.write_text('fixture');(self.raw/'window.txt').symlink_to(target);self.assertNotEqual(self.run_encrypt().returncode,0);(self.raw/'window.txt').unlink();os.link(target,self.raw/'window.txt');self.assertNotEqual(self.run_encrypt().returncode,0);self.assertFalse(self.out.exists())
 def test_wrong_scope_and_cert_rejected(self):
  other=self.base/'wrong/schon';other.mkdir(parents=True);(other/'result.json').write_text('{}');self.assertNotEqual(self.run_encrypt(raw=other).returncode,0);cert=self.base/'wrong.pem';cert.write_text('not certificate');self.assertNotEqual(self.run_encrypt(cert=cert).returncode,0)
 def test_existing_output_never_overwritten(self):
  self.out.parent.mkdir(parents=True);self.out.write_bytes(b'existing');self.assertNotEqual(self.run_encrypt().returncode,0);self.assertEqual(self.out.read_bytes(),b'existing');self.assertTrue(self.raw.exists())
 def test_unknown_flavor_native_capture_rejected(self):
  (self.raw/'pipe-report.txt').write_text('wrong method');self.assertNotEqual(self.run_encrypt().returncode,0);self.assertTrue(self.raw.exists())
if __name__=='__main__':unittest.main()
