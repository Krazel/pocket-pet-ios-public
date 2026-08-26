#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repository_root"

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
output_root="$repository_root/.verification-output/$timestamp"
work_root="$repository_root/.verification-work/$timestamp"
mkdir -p "$output_root" "$work_root"

metadata="$output_root/environment.txt"
{
  printf 'Pocket Pet candidate verification\n'
  printf 'UTC: %s\n' "$timestamp"
  printf 'Commit: %s\n' "$(git rev-parse HEAD)"
  printf 'Repository: %s\n\n' "$repository_root"
  swift --version
  printf '\n'
  xcodebuild -version
} | tee "$metadata"

printf '\nRunning Foundation package tests...\n'
set +e
swift test \
  --scratch-path "$work_root/SwiftPM" \
  2>&1 | tee "$output_root/swift-test.log"
swift_status=${PIPESTATUS[0]}

printf '\nBuilding the unsigned iPhone simulator target...\n'
NSUnbufferedIO=YES xcodebuild \
  -project PocketPetApp/PocketPetApp.xcodeproj \
  -scheme PocketPetApp \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$work_root/DerivedData" \
  -resultBundlePath "$output_root/PocketPetBuild.xcresult" \
  CODE_SIGNING_ALLOWED=NO \
  build \
  2>&1 | tee "$output_root/xcodebuild.log"
xcode_status=${PIPESTATUS[0]}

printf '\nAnalyzing the unsigned Release device target...\n'
NSUnbufferedIO=YES xcodebuild \
  -project PocketPetApp/PocketPetApp.xcodeproj \
  -scheme PocketPetApp \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$work_root/ReleaseDerivedData" \
  -resultBundlePath "$output_root/PocketPetReleaseAnalyze.xcresult" \
  CODE_SIGNING_ALLOWED=NO \
  VALIDATE_PRODUCT=YES \
  analyze \
  2>&1 | tee "$output_root/xcodebuild-release-analyze.log"
release_analyze_status=${PIPESTATUS[0]}
set -e

{
  printf 'swift test: %s\n' "$swift_status"
  printf 'xcodebuild: %s\n' "$xcode_status"
  printf 'release analyze: %s\n' "$release_analyze_status"
} | tee "$output_root/summary.txt"

if (( swift_status != 0 || xcode_status != 0 || release_analyze_status != 0 )); then
  printf '\nVerification failed. Evidence: %s\n' "$output_root" >&2
  exit 1
fi

printf '\nVerification passed. Evidence: %s\n' "$output_root"
