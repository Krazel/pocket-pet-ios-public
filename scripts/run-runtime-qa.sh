#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repository_root"

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
output_root="$repository_root/.verification-output/$timestamp/runtime-qa"
work_root="$repository_root/.verification-work/$timestamp/runtime-qa"
destination="${POCKET_PET_UI_DESTINATION:-platform=iOS Simulator,name=iPhone SE (3rd generation),OS=latest}"
candidate_commit="$(git rev-parse HEAD)"
accessibility_result="$output_root/PocketPetAccessibility.xcresult"
semantic_result="$output_root/PocketPetSemantics.xcresult"
motion_result="$output_root/PocketPetMotion.xcresult"
motion_video="$output_root/runtime-motion.mp4"
mkdir -p "$output_root" "$work_root"

simulator_environment_was_set=false
video_pid=""
cleanup_runtime_environment() {
  if [[ -n "$video_pid" ]]; then
    kill -INT "$video_pid" >/dev/null 2>&1 || true
    wait "$video_pid" >/dev/null 2>&1 || true
  fi
  if [[ "$simulator_environment_was_set" = true ]]; then
    xcrun simctl spawn "$POCKET_PET_UI_UDID" launchctl unsetenv \
      POCKET_PET_CANDIDATE_COMMIT >/dev/null 2>&1 || true
  fi
}
trap cleanup_runtime_environment EXIT

if [[ -n "${POCKET_PET_UI_UDID:-}" ]]; then
  xcrun simctl spawn "$POCKET_PET_UI_UDID" launchctl setenv \
    POCKET_PET_CANDIDATE_COMMIT "$candidate_commit"
  simulator_environment_was_set=true
fi

{
  printf 'Pocket Pet runtime QA run\n'
  printf 'UTC: %s\n' "$timestamp"
  printf 'Commit: %s\n' "$candidate_commit"
  printf 'Destination: %s\n\n' "$destination"
  xcodebuild -version
  printf '\nAvailable simulator devices:\n'
  xcrun simctl list devices available
} | tee "$output_root/environment.txt"

run_ui_suite() {
  local result_bundle="$1"
  local log_file="$2"
  shift 2
  NSUnbufferedIO=YES xcodebuild \
    -project PocketPetApp/PocketPetApp.xcodeproj \
    -scheme PocketPetApp \
    -configuration Debug \
    -destination "$destination" \
    -derivedDataPath "$work_root/DerivedData" \
    -resultBundlePath "$result_bundle" \
    -parallel-testing-enabled NO \
    "$@" \
    test \
    2>&1 | tee "$log_file"
  local suite_status="${PIPESTATUS[0]}"
  return "$suite_status"
}

if [[ -z "${POCKET_PET_UI_UDID:-}" ]]; then
  printf 'POCKET_PET_UI_UDID is required for deterministic runtime QA.\n' >&2
  exit 1
fi

xcrun simctl ui "$POCKET_PET_UI_UDID" content_size \
  accessibility-extra-extra-extra-large
set +e
run_ui_suite \
  "$accessibility_result" \
  "$output_root/xcodebuild-dynamic-type.log" \
  -only-testing:PocketPetUITests/PocketPetDynamicTypeTests
dynamic_type_status=$?
set -e

xcrun simctl ui "$POCKET_PET_UI_UDID" content_size large
set +e
run_ui_suite \
  "$semantic_result" \
  "$output_root/xcodebuild-semantics.log" \
  -only-testing:PocketPetUITests/PocketPetSemanticAccessibilityTests
semantic_status=$?
set -e

xcrun simctl io "$POCKET_PET_UI_UDID" recordVideo \
  --codec=h264 "$motion_video" \
  >"$output_root/motion-video.log" 2>&1 &
video_pid=$!
set +e
run_ui_suite \
  "$motion_result" \
  "$output_root/xcodebuild-motion.log" \
  -only-testing:PocketPetUITests/PocketPetReduceMotionTests \
  -only-testing:PocketPetUITests/PocketPetNormalMotionTimingTests
motion_status=$?
set -e
kill -INT "$video_pid" >/dev/null 2>&1 || true
wait "$video_pid" >/dev/null 2>&1 || true
video_pid=""

export_status=0
for bundle in "$accessibility_result" "$semantic_result" "$motion_result"; do
  bundle_name="$(basename "$bundle" .xcresult)"
  attachment_folder="$output_root/attachments/$bundle_name"
  if [[ ! -d "$bundle" ]]; then
    printf 'Missing result bundle: %s\n' "$bundle" \
      | tee -a "$output_root/attachment-export.log"
    export_status=1
    continue
  fi
  mkdir -p "$attachment_folder"
  set +e
  xcrun xcresulttool export attachments \
    --path "$bundle" \
    --output-path "$attachment_folder" \
    2>&1 | tee -a "$output_root/attachment-export.log"
  current_export_status=${PIPESTATUS[0]}
  set -e
  if (( current_export_status != 0 )); then
    export_status="$current_export_status"
  fi
done

find "$output_root/attachments" -type f -print | sort \
  | tee "$output_root/attachment-inventory.txt"
inventory_pipeline_statuses=("${PIPESTATUS[@]}")
inventory_status=0
for status in "${inventory_pipeline_statuses[@]}"; do
  if (( status != 0 )); then
    inventory_status="$status"
  fi
done

video_status=0
if [[ ! -s "$motion_video" ]]; then
  printf 'The runtime motion recording is missing or empty.\n' >&2
  video_status=1
fi

{
  printf 'D01-D10 Dynamic Type UI tests: %s\n' "$dynamic_type_status"
  printf 'V01-V08 semantic UI preflight: %s\n' "$semantic_status"
  printf 'R01-R04 and normal-motion UI tests: %s\n' "$motion_status"
  printf 'xcresult attachment export: %s\n' "$export_status"
  printf 'attachment inventory: %s\n' "$inventory_status"
  printf 'simulator motion recording: %s\n' "$video_status"
} | tee "$output_root/summary.txt"

if (( dynamic_type_status != 0 || semantic_status != 0 || motion_status != 0 \
      || export_status != 0 || inventory_status != 0 || video_status != 0 )); then
  printf '\nRuntime QA failed. Evidence: %s\n' "$output_root" >&2
  exit 1
fi

printf '\nRuntime QA evidence generated at: %s\n' "$output_root"
