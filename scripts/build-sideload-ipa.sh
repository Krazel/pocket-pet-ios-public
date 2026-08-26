#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repository_root"

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
work_root="$repository_root/.verification-work/$timestamp/sideload"
output_root="$repository_root/.verification-output/$timestamp/sideload"
derived_data="$work_root/DerivedData"
payload_root="$work_root/package"
mkdir -p "$derived_data" "$payload_root/Payload" "$output_root"

printf 'Building unsigned Pocket Pet device app for local sideload signing...\n'
NSUnbufferedIO=YES xcodebuild \
  -project PocketPetApp/PocketPetApp.xcodeproj \
  -scheme PocketPetApp \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$derived_data" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  AD_HOC_CODE_SIGNING_ALLOWED=NO \
  VALIDATE_PRODUCT=YES \
  build \
  2>&1 | tee "$output_root/xcodebuild-device.log"

app_path="$derived_data/Build/Products/Release-iphoneos/PocketPetApp.app"
if [[ ! -d "$app_path" ]]; then
  printf 'Expected device app was not produced at %s\n' "$app_path" >&2
  exit 1
fi

ditto "$app_path" "$payload_root/Payload/PocketPet.app"
ipa_path="$output_root/PocketPet-0.1-build-1-unsigned.ipa"
ditto -c -k --sequesterRsrc --keepParent "$payload_root/Payload" "$ipa_path"

{
  printf 'Pocket Pet sideload build\n'
  printf 'Commit: %s\n' "$(git rev-parse HEAD)"
  printf 'Bundle: com.krazel.pocketpet\n'
  printf 'Version: 0.1 (1)\n'
  printf 'Signing: unsigned; sign locally with Sideloadly or equivalent\n'
  printf 'IPA SHA-256: %s\n' "$(shasum -a 256 "$ipa_path" | awk '{print $1}')"
} | tee "$output_root/BUILD-INFO.txt"

printf 'Unsigned IPA ready at %s\n' "$ipa_path"
