#!/usr/bin/env bash
set -euo pipefail
[[ "${GITHUB_ACTIONS:-}" == true ]] || { echo 'Disposable hosted runner required'; exit 2; }
cd "$GITHUB_WORKSPACE"
proof="$RUNNER_TEMP/schon-native-acceptance/schon"
mkdir -p "$proof"
serial=emulator-5554
avd="SchonNativeAcceptance-35"
cleanup() {
  rc=$?; trap - EXIT; set +e
  timeout 10s adb -s "$serial" emu kill > "$proof/emulator-stop.txt" 2>&1
  for attempt in {1..15}; do
    if ! timeout 3s adb devices | grep -Fq "$serial"; then break; fi
    sleep 1
  done
  timeout 15s "$ANDROID_HOME/cmdline-tools/latest/bin/avdmanager" delete avd -n "$avd" > "$proof/avd-delete.txt" 2>&1
  timeout 10s "${ANDROID_SDK_ROOT:?}/emulator/emulator" -list-avds > "$proof/remaining-avds.txt" 2>&1
  avd_rc=$?
  timeout 5s adb devices > "$proof/remaining-devices.txt" 2>&1
  device_rc=$?
  python3 .github/native-acceptance/verify_cleanup.py --proof "$proof" --avd "$avd" --serial "$serial" --avd-rc "$avd_rc" --device-rc "$device_rc"
  if [[ $? != 0 ]]; then echo 'Exact owned cloud device cleanup not verified' > "$proof/cleanup-failed.txt"; rc=1; fi
  exit "$rc"
}
trap cleanup EXIT
sleep 20
python3 .github/native-acceptance/run_acceptance.py
