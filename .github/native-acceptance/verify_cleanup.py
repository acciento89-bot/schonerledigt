"""Fail-closed receipt for exact cloud-owned AVD and serial, no device operations."""
import argparse,json,pathlib,re

def verify_cleanup(avds,devices,avd,serial,avd_rc,device_rc):
 if avd_rc != 0 or device_rc != 0: return False
 avd_rows=[line.strip() for line in avds.splitlines() if line.strip()]
 if any(not re.fullmatch(r'[A-Za-z0-9_.-]+', line) for line in avd_rows): return False
 rows=[line.strip() for line in devices.splitlines() if line.strip()]
 if not rows or rows[0] != 'List of devices attached': return False
 device_ids=[]
 for row in rows[1:]:
  fields=row.split()
  if len(fields)<2 or not re.fullmatch(r'[A-Za-z0-9_.:-]+',fields[0]): return False
  if fields[1] not in ('device','offline','unauthorized','recovery','sideload','bootloader','host'): return False
  if any(not re.fullmatch(r'[A-Za-z_]+:[^\s]+',field) for field in fields[2:]): return False
  device_ids.append(fields[0])
 return avd not in avd_rows and serial not in device_ids

def main():
 p=argparse.ArgumentParser();p.add_argument('--proof',type=pathlib.Path,required=True);p.add_argument('--avd',required=True);p.add_argument('--serial',required=True);p.add_argument('--avd-rc',type=int,required=True);p.add_argument('--device-rc',type=int,required=True);a=p.parse_args()
 avds=(a.proof/'remaining-avds.txt').read_text();devices=(a.proof/'remaining-devices.txt').read_text();ok=verify_cleanup(avds,devices,a.avd,a.serial,a.avd_rc,a.device_rc)
 (a.proof/'cleanup.json').write_text(json.dumps({'deviceDeletedVerified':ok,'ownedAvd':a.avd,'ownedSerial':a.serial,'avdInventoryExit':a.avd_rc,'deviceInventoryExit':a.device_rc},indent=2)+'\n');raise SystemExit(0 if ok else 1)
if __name__=='__main__':main()
