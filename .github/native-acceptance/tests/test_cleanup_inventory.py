import importlib.util, pathlib, unittest
p=pathlib.Path(__file__).resolve().parents[1]/'verify_cleanup.py'
s=importlib.util.spec_from_file_location('cleanup',p);m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
class InventoryTests(unittest.TestCase):
 def test_empty_adb_is_not_verified(self):self.assertFalse(m.verify_cleanup('','','Owned','emulator-5554',0,0))
 def test_malformed_adb_is_not_verified(self):
  for v in ['garbage\n','List of devices attached\nerror: daemon unavailable\n','List of devices attached\nemulator-5556 nonsense\n']:
   self.assertFalse(m.verify_cleanup('',v,'Owned','emulator-5554',0,0),v)
 def test_avd_diagnostics_are_not_inventory(self):self.assertFalse(m.verify_cleanup('ERROR: failed listing\n','List of devices attached\n','Owned','emulator-5554',0,0))
 def test_valid_absence(self):self.assertTrue(m.verify_cleanup('Other_AVD\n','List of devices attached\n\n','Owned','emulator-5554',0,0))
 def test_owned_presence_rejected(self):self.assertFalse(m.verify_cleanup('Owned\n','List of devices attached\n','Owned','emulator-5554',0,0))
 def test_valid_other_device(self):self.assertTrue(m.verify_cleanup('','List of devices attached\nemulator-5556\tdevice product:sdk model:Pixel transport_id:1\n','Owned','emulator-5554',0,0))
