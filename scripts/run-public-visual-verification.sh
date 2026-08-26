#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repository_root"

device_type="com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro"
simulator_name="Pocket Pet Visual iPhone 16 Pro"

runtime_id="$(
  xcrun simctl list runtimes --json |
    python3 -c '
import json, sys
runtimes = [
    runtime for runtime in json.load(sys.stdin)["runtimes"]
    if runtime.get("isAvailable")
    and ".SimRuntime.iOS-" in runtime.get("identifier", "")
]
if not runtimes:
    raise SystemExit("No available iOS Simulator runtime was found.")
def version(runtime):
    return tuple(int(part) for part in runtime["version"].split("."))
print(max(runtimes, key=version)["identifier"])
'
)"

if ! xcrun simctl list devicetypes --json |
  python3 -c '
import json, sys
identifier = sys.argv[1]
available = {
    item["identifier"] for item in json.load(sys.stdin)["devicetypes"]
}
raise SystemExit(0 if identifier in available else 1)
' "$device_type"; then
  printf 'Required simulator device type is unavailable: %s\n' "$device_type" >&2
  exit 1
fi

simulator_udid="$(xcrun simctl create "$simulator_name" "$device_type" "$runtime_id")"
cleanup_simulator() {
  xcrun simctl status_bar "$simulator_udid" clear >/dev/null 2>&1 || true
  xcrun simctl shutdown "$simulator_udid" >/dev/null 2>&1 || true
  xcrun simctl delete "$simulator_udid" >/dev/null 2>&1 || true
}
trap cleanup_simulator EXIT

xcrun simctl boot "$simulator_udid"
xcrun simctl bootstatus "$simulator_udid" -b
xcrun simctl ui "$simulator_udid" appearance light
xcrun simctl status_bar "$simulator_udid" override \
  --time '9:41' \
  --batteryState charged \
  --batteryLevel 100 \
  --cellularMode active \
  --cellularBars 4 \
  --wifiBars 3

export POCKET_PET_UI_DESTINATION="platform=iOS Simulator,id=${simulator_udid}"
bash scripts/run-visual-captures.sh
