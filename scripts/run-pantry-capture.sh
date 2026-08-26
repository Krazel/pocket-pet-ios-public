#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repository_root"

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
output_root="$repository_root/.verification-output/$timestamp/pantry-capture"
work_root="$repository_root/.verification-work/$timestamp/pantry-capture"
result_bundle="$output_root/PocketPetPantryCapture.xcresult"
attachments="$output_root/attachments"
destination="${POCKET_PET_UI_DESTINATION:-platform=iOS Simulator,name=iPhone 16 Pro,OS=latest}"
mkdir -p "$output_root" "$work_root"

set +e
NSUnbufferedIO=YES xcodebuild \
  -project PocketPetApp/PocketPetApp.xcodeproj \
  -scheme PocketPetApp \
  -configuration Debug \
  -destination "$destination" \
  -derivedDataPath "$work_root/DerivedData" \
  -resultBundlePath "$result_bundle" \
  -only-testing:PocketPetUITests/PocketPetPantryCaptureTests \
  -parallel-testing-enabled NO \
  test \
  2>&1 | tee "$output_root/xcodebuild-pantry-capture.log"
test_status=${PIPESTATUS[0]}

export_status=1
if [[ -d "$result_bundle" ]]; then
  mkdir -p "$attachments"
  xcrun xcresulttool export attachments \
    --path "$result_bundle" \
    --output-path "$attachments" \
    2>&1 | tee "$output_root/attachment-export.log"
  export_status=${PIPESTATUS[0]}
  find "$attachments" -type f -print | sort \
    | tee "$output_root/attachment-inventory.txt"
else
  printf 'No Pantry result bundle was created.\n' \
    | tee "$output_root/attachment-export.log"
fi
set -e

{
  printf 'xcodebuild Pantry UI test: %s\n' "$test_status"
  printf 'xcresult attachment export: %s\n' "$export_status"
} | tee "$output_root/summary.txt"

if (( test_status != 0 || export_status != 0 )); then
  printf 'Pantry capture failed. Evidence: %s\n' "$output_root" >&2
  exit 1
fi

printf 'Pantry attachments exported to: %s\n' "$attachments"
