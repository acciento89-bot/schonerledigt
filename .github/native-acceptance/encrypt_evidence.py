#!/usr/bin/env python3
"""Encrypt one owned diagnostic directory; upload callers must use only the CMS."""
import hashlib
import os
from pathlib import Path
import shutil
import stat
import subprocess
import sys
import tarfile
import tempfile

PINNED_CERT_SHA256 = '705b5ac64316a5704a3270ced486d4a2292cc882e3837fd1adb3c644f6612329'
os.umask(0o077)
raw = Path(sys.argv[1])
output = Path(sys.argv[2])
certificate = Path(sys.argv[3]) if len(sys.argv)>3 else Path(__file__).with_name('shk-ci-diagnostics.public.pem')
if not raw.exists() and not raw.is_symlink():
    sys.exit(0)  # A successful capture has no failure evidence to upload.
if hashlib.sha256(certificate.read_bytes()).hexdigest() != PINNED_CERT_SHA256:
    sys.exit('Diagnostic certificate SHA mismatch; no archive created')
runtime = os.environ.get('RUNNER_TEMP')
if not runtime:
    sys.exit('Missing owned diagnostic scope; RUNNER_TEMP is required')
runtime = Path(runtime).resolve()
raw_base, encrypted_base = runtime/'schon-native-acceptance', runtime/'schon-native-encrypted'
flavors = {'schon'}
if (raw.name not in flavors or raw_base.is_symlink() or
        raw.parent.resolve() != raw_base.resolve() or encrypted_base.is_symlink() or
        output.parent.is_symlink() or
        output.resolve() != (encrypted_base/raw.name/'acceptance.cms').resolve()):
    sys.exit('Refusing path outside the owned diagnostic scope')
if raw.is_symlink() or not raw.is_dir() or raw.stat().st_uid != os.getuid():
    sys.exit('Diagnostic directory must be an owned regular directory')
if output.exists() or output.is_symlink() or raw.resolve() in output.resolve().parents:
    sys.exit('Diagnostic ciphertext must use a fresh path outside raw evidence')
import json
from run_acceptance import GENERIC_FILES,NATIVE_FILES
allowed=GENERIC_FILES | NATIVE_FILES
files = sorted(raw.iterdir())
total = 0
for file in files:
    if file.name not in allowed:
        sys.exit('unexpected diagnostic entry; refusing expanded archive scope')
    info = file.lstat()
    if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid() or info.st_nlink != 1:
        sys.exit('Diagnostic entry must be an owned regular file without links')
    total += info.st_size
if total > 96 * 1024 * 1024:
    sys.exit('Diagnostic archive exceeds its bounded evidence limit')
output.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
with tempfile.TemporaryDirectory(prefix='shk-native-encryption-',dir=output.parent) as temporary:
    archive = Path(temporary)/'raw.tar.gz'
    encrypted = Path(temporary)/'failure.cms'
    with tarfile.open(archive,'w:gz') as tar:
        for file in files:
            tar.add(file,arcname=file.name,recursive=False)
    commands = [
        ['openssl','cms','-encrypt','-aes-256-cbc','-binary','-outform','DER',
         '-in',str(archive),'-out',str(encrypted),'-recip',str(certificate)],
        ['openssl','cms','-cmsout','-inform','DER','-in',str(encrypted),'-noout'],
    ]
    for command in commands:
        try:
            result = subprocess.run(command,capture_output=True,timeout=15)
        except (OSError,subprocess.TimeoutExpired):
            sys.exit('Diagnostic encryption unavailable; raw evidence retained locally')
        if result.returncode:
            sys.exit('Diagnostic encryption failed; raw evidence retained locally')
    if not encrypted.is_file() or encrypted.stat().st_size == 0:
        sys.exit('Diagnostic encryption produced no ciphertext; raw evidence retained locally')
    # Atomic no-overwrite publication: a failed command never exposes a partial CMS.
    os.link(encrypted,output)
shutil.rmtree(raw)  # Only after successful nonempty CMS validation/publication.
