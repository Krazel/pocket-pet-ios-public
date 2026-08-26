#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repository_root"

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
output_root="$repository_root/.verification-output/$timestamp/visual-captures"
work_root="$repository_root/.verification-work/$timestamp/visual-captures"
result_bundle="$output_root/PocketPetVisualCaptures.xcresult"
attachments="$output_root/attachments"
comparison="$output_root/comparison"
destination="${POCKET_PET_UI_DESTINATION:-platform=iOS Simulator,name=iPhone 16 Pro,OS=latest}"
candidate_commit="$(git rev-parse HEAD)"
mkdir -p "$output_root" "$work_root"

{
  printf 'Pocket Pet visual capture run\n'
  printf 'UTC: %s\n' "$timestamp"
  printf 'Commit: %s\n' "$candidate_commit"
  printf 'Destination: %s\n\n' "$destination"
  xcodebuild -version
  printf '\nAvailable simulator devices:\n'
  xcrun simctl list devices available
} | tee "$output_root/environment.txt"

set +e
POCKET_PET_CANDIDATE_COMMIT="$candidate_commit" NSUnbufferedIO=YES xcodebuild \
  -project PocketPetApp/PocketPetApp.xcodeproj \
  -scheme PocketPetApp \
  -configuration Debug \
  -destination "$destination" \
  -derivedDataPath "$work_root/DerivedData" \
  -resultBundlePath "$result_bundle" \
  -only-testing:PocketPetUITests/PocketPetVisualCaptureTests \
  -parallel-testing-enabled NO \
  test \
  2>&1 | tee "$output_root/xcodebuild-ui-tests.log"
test_status=${PIPESTATUS[0]}

export_status=1
inventory_status=1
compare_status=1
if [[ -d "$result_bundle" ]]; then
  mkdir -p "$attachments"
  xcrun xcresulttool export attachments \
    --path "$result_bundle" \
    --output-path "$attachments" \
    2>&1 | tee "$output_root/attachment-export.log"
  export_status=${PIPESTATUS[0]}
  find "$attachments" -type f -print | sort \
    | tee "$output_root/attachment-inventory.txt"
  inventory_pipeline_statuses=("${PIPESTATUS[@]}")
  inventory_status=0
  for status in "${inventory_pipeline_statuses[@]}"; do
    if (( status != 0 )); then
      inventory_status="$status"
    fi
  done
else
  printf 'No result bundle was created; attachments cannot be exported.\n' \
    | tee "$output_root/attachment-export.log"
fi

if (( export_status == 0 )); then
  SWIFT_MODULECACHE_PATH="$work_root/SwiftModuleCache" xcrun swift \
    scripts/compare-visual-captures.swift \
    --attachments "$attachments" \
    --output "$comparison" \
    --repository-root "$repository_root" \
    --candidate "$candidate_commit" \
    2>&1 | tee "$output_root/visual-comparison.log"
  compare_status=${PIPESTATUS[0]}
else
  printf 'Attachments were not exported; comparison cannot run.\n' \
    | tee "$output_root/visual-comparison.log"
fi
set -e

{
  printf 'xcodebuild UI tests: %s\n' "$test_status"
  printf 'xcresult attachment export: %s\n' "$export_status"
  printf 'attachment inventory: %s\n' "$inventory_status"
  printf 'visual evidence generation: %s\n' "$compare_status"
} | tee "$output_root/summary.txt"

if (( test_status != 0 || export_status != 0 || inventory_status != 0 || compare_status != 0 )); then
  printf '\nVisual capture run failed. Evidence: %s\n' "$output_root" >&2
  exit 1
fi

printf '\nVisual attachments exported to: %s\n' "$attachments"
printf 'Comparable evidence generated at: %s\n' "$comparison"
