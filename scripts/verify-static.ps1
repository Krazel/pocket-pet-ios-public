param(
    [switch]$RequireClean
)

$ErrorActionPreference = 'Stop'

function Fail([string]$Message) {
    throw "Static verification failed: $Message"
}

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Push-Location $repositoryRoot
try {
    $gitRoot = (git rev-parse --show-toplevel).Trim()
    if ((Resolve-Path $gitRoot).Path -ne $repositoryRoot) {
        Fail "PocketPetNative is not the active repository root."
    }

    git diff --check
    if ($LASTEXITCODE -ne 0) { Fail 'git diff --check reported an error.' }

    if ($RequireClean) {
        $status = @(git status --short)
        if ($status.Count -ne 0) { Fail 'the worktree is not clean.' }
    }

    $testCount = (
        Select-String -Path 'Tests\**\*.swift' -Pattern 'func test' |
            Measure-Object
    ).Count
    if ($testCount -lt 83) {
        Fail "only $testCount XCTest methods were found; expected at least 83."
    }

    $forbiddenPattern =
        'import (StoreKit|Firebase|Alamofire)|URLSession|interruptionLevel|' +
        'criticalAlert|timeSensitive|setBadgeCount'
    $forbidden = @(
        rg -n $forbiddenPattern PocketPetApp Sources Tests -g '*.swift'
    )
    if ($LASTEXITCODE -notin @(0, 1)) { Fail 'scope search could not run.' }
    if ($forbidden.Count -ne 0) {
        Fail "forbidden product capability found:`n$($forbidden -join "`n")"
    }

    $coreImports = @(
        rg -n 'import (SwiftUI|SpriteKit|UIKit|UserNotifications|StoreKit)' `
            Sources\PocketPetCore -g '*.swift'
    )
    if ($LASTEXITCODE -notin @(0, 1)) { Fail 'core import search could not run.' }
    if ($coreImports.Count -ne 0) {
        Fail "PocketPetCore imports a UI or notification framework."
    }

    $macOSGate = Get-Content -Raw 'scripts\verify-macos.sh'
    foreach ($requiredMacOSCommand in @(
        'swift test',
        'xcodebuild',
        'PocketPetReleaseAnalyze.xcresult',
        'VALIDATE_PRODUCT=YES',
        '-resultBundlePath',
        'CODE_SIGNING_ALLOWED=NO'
    )) {
        if (-not $macOSGate.Contains($requiredMacOSCommand)) {
            Fail "macOS gate is missing $requiredMacOSCommand."
        }
    }
    $visualCaptureGate = Get-Content -Raw 'scripts\run-visual-captures.sh'
    foreach ($requiredCaptureToken in @(
        'PocketPetVisualCaptures.xcresult',
        'PocketPetUITests/PocketPetVisualCaptureTests',
        'xcresulttool export attachments',
        'compare-visual-captures.swift',
        'attachment inventory',
        'xcodebuild UI tests'
    )) {
        if (-not $visualCaptureGate.Contains($requiredCaptureToken)) {
            Fail "visual capture gate is missing $requiredCaptureToken."
        }
    }
    $publicVisualGate = Get-Content -Raw (
        'scripts\run-public-visual-verification.sh'
    )
    foreach ($requiredPublicVisualToken in @(
        'com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro',
        'simctl create',
        'simctl bootstatus',
        'simctl ui',
        'simctl status_bar',
        "--time '9:41'",
        '--batteryLevel 100',
        'POCKET_PET_UI_DESTINATION',
        'POCKET_PET_UI_UDID',
        'run-visual-captures.sh',
        'trap cleanup_simulator EXIT'
    )) {
        if (-not $publicVisualGate.Contains($requiredPublicVisualToken)) {
            Fail "public visual gate is missing $requiredPublicVisualToken."
        }
    }
    foreach ($captureEnvironmentToken in @(
        'launchctl setenv',
        'launchctl unsetenv',
        'POCKET_PET_CANDIDATE_COMMIT'
    )) {
        if (-not $visualCaptureGate.Contains($captureEnvironmentToken)) {
            Fail "visual capture gate is missing $captureEnvironmentToken."
        }
    }

    $runtimeQA = Get-Content -Raw 'docs\RUNTIME_QA.md'
    $visualComparator = Get-Content -Raw 'scripts\compare-visual-captures.swift'
    foreach ($manifestToken in @(
        'manifest.json',
        'exportedFileName',
        'suggestedHumanReadableName'
    )) {
        if (-not $visualComparator.Contains($manifestToken)) {
            Fail "visual comparator is missing Xcode attachment mapping token: $manifestToken."
        }
    }
    $comparatorMappings = [regex]::Matches(
        $visualComparator,
        'FrameSpec\(id: "(F\d{2})".*referencePath: "([^"]+)".*' +
            'referenceSHA256: "([0-9a-f]{64})"\)'
    )
    if ($comparatorMappings.Count -ne 17) {
        Fail (
            "visual comparator maps $($comparatorMappings.Count) frames; " +
            'expected 17.'
        )
    }
    $comparatorFrameIDs = @(
        $comparatorMappings |
            ForEach-Object { $_.Groups[1].Value }
    )
    if (@($comparatorFrameIDs | Sort-Object -Unique).Count -ne 17) {
        Fail 'visual comparator frame IDs are not unique.'
    }
    foreach ($mapping in $comparatorMappings) {
        $frameID = $mapping.Groups[1].Value
        $referencePath = $mapping.Groups[2].Value
        $expectedHash = $mapping.Groups[3].Value
        if (-not $runtimeQA.Contains("| $frameID |") -or
            -not $runtimeQA.Contains("``$referencePath``")) {
            Fail "$frameID comparator mapping is absent from runtime QA."
        }
        if (-not (Test-Path -LiteralPath $referencePath)) {
            Fail "$frameID comparator reference is missing: $referencePath."
        }
        $actualHash = (
            Get-FileHash -Algorithm SHA256 -LiteralPath $referencePath
        ).Hash.ToLowerInvariant()
        if ($actualHash -ne $expectedHash) {
            Fail "$frameID comparator reference hash does not match."
        }
    }
    foreach ($requiredComparatorToken in @(
        'CryptoKit',
        'CGColorSpace.sRGB',
        'uniform aspect-fill scale, centered crop',
        'composited over opaque sRGB white',
        'PIXEL_IDENTICAL',
        'REVIEW_REQUIRED',
        'heatmaps',
        'differentPixelPercentage',
        'rootMeanSquareErrorRGB',
        'differenceBounds',
        'fixtureClock',
        '--visual-static'
    )) {
        if (-not $visualComparator.Contains($requiredComparatorToken)) {
            Fail "visual comparator is missing $requiredComparatorToken."
        }
    }
    $workflow = Get-Content -Raw '.github\workflows\verify-ios.yml'
    foreach ($requiredTrigger in @('push:', 'pull_request:', 'workflow_dispatch:')) {
        if (-not $workflow.Contains($requiredTrigger)) {
            Fail "iOS verification workflow is missing $requiredTrigger."
        }
    }
    if (-not $workflow.Contains('bash scripts/verify-macos.sh')) {
        Fail 'iOS verification workflow does not use the shared macOS gate.'
    }
    if (-not $workflow.Contains('actions/upload-artifact@v6')) {
        Fail 'iOS verification workflow does not preserve evidence.'
    }
    if ([regex]::Matches(
            $workflow,
            'include-hidden-files: true'
        ).Count -ne 2) {
        Fail 'both public jobs must include hidden verification evidence.'
    }
    if (-not $workflow.Contains('actions/checkout@v5') -or
        -not $workflow.Contains('runs-on: macos-26')) {
        Fail 'iOS verification workflow does not use the approved public runner.'
    }
    if (-not $workflow.Contains('run_visual_captures:')) {
        Fail 'manual workflow does not expose the visual capture input.'
    }
    if (-not $workflow.Contains('default: false')) {
        Fail 'visual capture input must remain explicitly opt-in.'
    }
    if ($workflow -match '(?m)^\s+schedule:') {
        Fail 'iOS verification workflow gained a scheduled trigger.'
    }
    if ($workflow -match 'secrets\.' -or
        $workflow -match '(?m)^\s+environment:') {
        Fail 'public verification must remain isolated from deployment secrets.'
    }
    if (-not $workflow.Contains(
            'bash scripts/run-public-visual-verification.sh'
        )) {
        Fail 'public workflow does not provision its deterministic simulator.'
    }

    $testFlightWorkflow = Get-Content -Raw (
        '.github\workflows\build-ios-testflight.yml'
    )
    foreach ($requiredTestFlightToken in @(
        'workflow_dispatch:',
        'environment: app-store-production',
        'default: "false"',
        'runs-on: macos-26',
        'APP_BUNDLE_ID: com.krazel.pocketpet',
        'APP_VERSION: "0.1"',
        'APPLE_TEAM_ID: B2X6D3A9J9',
        'BUILD_CERTIFICATE_BASE64',
        'BUILD_PROVISION_PROFILE_BASE64',
        'APP_STORE_CONNECT_API_KEY_BASE64',
        'DEVELOPMENT_TEAM="${APPLE_TEAM_ID}"',
        'CODE_SIGN_STYLE=Manual',
        'CODE_SIGN_IDENTITY="Apple Distribution"',
        'PROVISIONING_PROFILE_SPECIFIER="${PROFILE_NAME}"',
        'testFlightInternalTestingOnly',
        'beta-reports-active',
        'ExpirationDate',
        'ProvisionedDevices',
        'ProvisionsAllDevices',
        'CFBundleIconName',
        'signed-entitlements.plist',
        'embedded-profile.plist',
        'required_resources=(',
        'pocket-pet-testflight-verification-',
        'include-hidden-files: true',
        'Upload the authorized build to internal TestFlight'
    )) {
        if (-not $testFlightWorkflow.Contains($requiredTestFlightToken)) {
            Fail "TestFlight workflow is missing $requiredTestFlightToken."
        }
    }
    if ($testFlightWorkflow -match '(?m)^\s+(push|pull_request|schedule):') {
        Fail 'TestFlight workflow must remain manual-only.'
    }
    if ($testFlightWorkflow -match (
            '(?s)uses:\s*actions/upload-artifact@v6\s+with:\s+.*?' +
            '(?m)^\s+path:\s*[^\r\n]*\.ipa'
        )) {
        Fail 'the public workflow must never publish the signed IPA as an artifact.'
    }
    $gitAttributes = Get-Content -Raw '.gitattributes'
    if (-not $gitAttributes.Contains('*.sh text eol=lf')) {
        Fail 'shell verification scripts are not pinned to LF line endings.'
    }

    $runtimeFrames = [regex]::Matches($runtimeQA, '(?m)^\| F\d{2} \|').Count
    if ($runtimeFrames -ne 17) {
        Fail "runtime QA defines $runtimeFrames canonical frames; expected 17."
    }

    $appModel = Get-Content -Raw 'PocketPetApp\App\PocketPetAppModel.swift'
    foreach ($requiredHarnessToken in @(
        '--visual-state',
        '--visual-static',
        'PocketPetVisualClock',
        'PocketPetVisualHarness',
        'temporaryDirectory'
    )) {
        if (-not $appModel.Contains($requiredHarnessToken)) {
            Fail "visual harness is missing $requiredHarnessToken."
        }
    }
    foreach ($unsafeLegacyArgument in @(
        '--seed-approved-home',
        '--open-settings'
    )) {
        if ($appModel.Contains($unsafeLegacyArgument)) {
            Fail "unsafe legacy visual argument remains: $unsafeLegacyArgument."
        }
    }

    $uiCaptureTests = Get-Content -Raw (
        'PocketPetApp\PocketPetUITests\PocketPetVisualCaptureTests.swift'
    )
    $uiFrameTests = [regex]::Matches(
        $uiCaptureTests,
        '(?m)^\s*func testF\d{2}'
    ).Count
    $rawCaptureNames = @(
        [regex]::Matches(
            $uiCaptureTests,
            'capture\("(F\d{2}-[^"\r\n]+-raw)"\)'
        ) | ForEach-Object { $_.Groups[1].Value }
    )
    if ($uiFrameTests -ne 17 -or $rawCaptureNames.Count -ne 17) {
        Fail (
            "UI capture suite has $uiFrameTests frame tests and " +
            "$($rawCaptureNames.Count) named raw captures; expected 17 each."
        )
    }
    if (@($rawCaptureNames | Sort-Object -Unique).Count -ne 17) {
        Fail 'UI capture attachment names are not unique.'
    }
    foreach ($exactPNGToken in @(
        'let png = screenshot.pngRepresentation',
        'data: png',
        'uniformTypeIdentifier: "public.png"'
    )) {
        if (-not $uiCaptureTests.Contains($exactPNGToken)) {
            Fail "UI capture suite is missing exact PNG token: $exactPNGToken."
        }
    }
    foreach ($requiredSelector in @(
        'capture.hatching.ready',
        'capture.adultEvolution.ready',
        'habitat.scene',
        'habitat.stage',
        'settings.reminderTime'
    )) {
        if (-not $uiCaptureTests.Contains($requiredSelector)) {
            Fail "UI capture suite does not wait for $requiredSelector."
        }
    }

    $pbxPath = 'PocketPetApp\PocketPetApp.xcodeproj\project.pbxproj'
    $pbx = Get-Content -Raw $pbxPath
    $ids = @(
        [regex]::Matches(
            $pbx,
            '(?m)^\s*([A-F0-9]{24}) /\*.*?\*/ = \{'
        ) | ForEach-Object { $_.Groups[1].Value }
    )
    $uniqueIDs = @($ids | Sort-Object -Unique)
    if ($ids.Count -ne $uniqueIDs.Count) {
        Fail 'duplicate PBX object identifiers were found.'
    }
    if (
        [regex]::Matches($pbx, '\{').Count -ne
        [regex]::Matches($pbx, '\}').Count
    ) {
        Fail 'PBX braces are unbalanced.'
    }
    $swiftLanguageModes = @(
        [regex]::Matches($pbx, 'SWIFT_VERSION = ([^;]+);') |
            ForEach-Object { $_.Groups[1].Value }
    )
    if (
        $swiftLanguageModes.Count -ne 2 -or
        @($swiftLanguageModes | Where-Object { $_ -ne '5.0' }).Count -ne 0
    ) {
        Fail 'Debug and Release must use the supported Swift 5 language mode.'
    }

    $projectFiles = @(Get-ChildItem 'PocketPetApp' -Recurse -File)
    $looseSwiftUIImages = @(
        Select-String -Path ($projectFiles | Where-Object Extension -eq '.swift').FullName `
            -Pattern 'Image\([^\r\n]+bundle: \.main\)'
    )
    if ($looseSwiftUIImages.Count -ne 0) {
        Fail 'loose PNG resources must use PocketPetArtwork for reliable bundle loading.'
    }
    $missingReferences = @()
    [regex]::Matches($pbx, 'path = ([^;]+\.(swift|png));') |
        ForEach-Object {
            $relative = $_.Groups[1].Value.Trim('"')
            $basename = [IO.Path]::GetFileName($relative)
            if (-not ($projectFiles | Where-Object Name -eq $basename)) {
                $missingReferences += $relative
            }
        }
    if ($missingReferences.Count -ne 0) {
        Fail "missing PBX files: $($missingReferences -join ', ')"
    }
    foreach ($requiredUITestProjectToken in @(
        'PocketPetUITests.xctest',
        'com.apple.product-type.bundle.ui-testing',
        'TEST_TARGET_NAME = PocketPetApp',
        'PocketPetVisualCaptureTests.swift in Sources'
    )) {
        if (-not $pbx.Contains($requiredUITestProjectToken)) {
            Fail "Xcode UI-test target is missing $requiredUITestProjectToken."
        }
    }
    try {
        [xml]$scheme = Get-Content -Raw (
            'PocketPetApp\PocketPetApp.xcodeproj\xcshareddata\xcschemes\' +
            'PocketPetApp.xcscheme'
        )
    } catch {
        Fail 'shared Xcode scheme is not valid XML.'
    }
    if (-not $scheme.Scheme.TestAction.Testables.TestableReference) {
        Fail 'shared Xcode scheme does not include the UI-test target.'
    }
    if ([regex]::Matches(
            $pbx,
            'ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;'
        ).Count -ne 2) {
        Fail 'Debug and Release do not both select the approved AppIcon set.'
    }
    if ([regex]::Matches(
            $pbx,
            'INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO;'
        ).Count -ne 2) {
        Fail 'Debug and Release do not both declare export compliance.'
    }

    $approvalRows = @(
        Get-Content 'design\APPROVALS.md' |
            Where-Object {
                $_ -match '^\|.*`(design/approved/[^`]+\.png)`.*' +
                    '`([0-9a-f]{64})`'
            }
    )
    if ($approvalRows.Count -lt 15) {
        Fail 'the canonical approval table is incomplete.'
    }
    foreach ($line in $approvalRows) {
        $match = [regex]::Match(
            $line,
            '`(design/approved/[^`]+\.png)`.*`([0-9a-f]{64})`'
        )
        $path = Join-Path $repositoryRoot (
            $match.Groups[1].Value -replace '/', '\'
        )
        if (-not (Test-Path -LiteralPath $path)) {
            Fail "missing approved reference $($match.Groups[1].Value)."
        }
        $actualHash = (
            Get-FileHash -Algorithm SHA256 -LiteralPath $path
        ).Hash.ToLowerInvariant()
        if ($actualHash -ne $match.Groups[2].Value) {
            Fail "hash mismatch for $($match.Groups[1].Value)."
        }
    }

    Add-Type -AssemblyName System.Drawing
    $approvedIconPath = 'design\approved\app-icon-spriglet-v1.png'
    $runtimeIconPath = (
        'PocketPetApp\Resources\Assets.xcassets\AppIcon.appiconset\' +
        'AppIcon-1024.png'
    )
    $approvedIconHash =
        '10afad059f74f582093fea5a9fa99d7a01b3512c8cceb7d6aa330655ccdbe423'
    foreach ($iconPath in @($approvedIconPath, $runtimeIconPath)) {
        if (-not (Test-Path -LiteralPath $iconPath)) {
            Fail "missing approved app icon $iconPath."
        }
        $actualHash = (
            Get-FileHash -Algorithm SHA256 -LiteralPath $iconPath
        ).Hash.ToLowerInvariant()
        if ($actualHash -ne $approvedIconHash) {
            Fail "hash mismatch for $iconPath."
        }
    }
    $appIconContents = Get-Content -Raw (
        'PocketPetApp\Resources\Assets.xcassets\AppIcon.appiconset\Contents.json'
    )
    if (-not $appIconContents.Contains('AppIcon-1024.png')) {
        Fail 'the AppIcon catalog does not reference the approved runtime icon.'
    }
    $stageAssets = @{
        'PocketPetApp\Resources\Artwork\UI\icon_stage_child.png' =
            '083a12eea38797392577c4e6fb66e17d63aff36582b6a1852004e845cb5518c9'
        'PocketPetApp\Resources\Artwork\UI\icon_stage_adult.png' =
            '37dc4427ce08c908b43854c02ab322ddcdaf235d44542b1223e37ccbf38e3b4f'
    }
    foreach ($entry in $stageAssets.GetEnumerator()) {
        if (-not (Test-Path -LiteralPath $entry.Key)) {
            Fail "missing stage asset $($entry.Key)."
        }
        $actualHash = (
            Get-FileHash -Algorithm SHA256 -LiteralPath $entry.Key
        ).Hash.ToLowerInvariant()
        if ($actualHash -ne $entry.Value) {
            Fail "hash mismatch for $($entry.Key)."
        }
    }

    $approvedPNGs = @(Get-ChildItem 'design\approved' -Filter '*.png')
    if ($approvedPNGs.Count -lt 20) {
        Fail "only $($approvedPNGs.Count) approved PNGs were found."
    }
    foreach ($file in $approvedPNGs) {
        $image = [System.Drawing.Image]::FromFile($file.FullName)
        try {
            $expected = if ($file.Name -like 'app-icon-*') {
                @(1024, 1024)
            } elseif ($file.Name -like 'creature-*') {
                @(1254, 1254)
            } else {
                @(853, 1844)
            }
            if (
                $image.Width -ne $expected[0] -or
                $image.Height -ne $expected[1]
            ) {
                Fail (
                    "$($file.Name) is $($image.Width)x$($image.Height); " +
                    "expected $($expected[0])x$($expected[1])."
                )
            }
        } finally {
            $image.Dispose()
        }
    }

    Write-Output "PASS: repository root $repositoryRoot"
    Write-Output "PASS: $testCount XCTest methods declared"
    Write-Output "PASS: $($ids.Count) unique PBX objects and no missing references"
    Write-Output "PASS: $($approvalRows.Count) canonical hashes verified"
    Write-Output "PASS: $($approvedPNGs.Count) approved image dimensions verified"
    Write-Output "PASS: $($stageAssets.Count) stage badge asset hashes verified"
    Write-Output 'PASS: shared manual macOS evidence gate is wired'
    Write-Output 'PASS: opt-in UI capture evidence gate is wired'
    Write-Output 'PASS: zero-tolerance visual comparison evidence is wired'
    Write-Output "PASS: $runtimeFrames canonical runtime frames are specified"
    Write-Output 'PASS: isolated DEBUG visual harness is present'
    Write-Output "PASS: $uiFrameTests deterministic UI capture tests are declared"
    Write-Output 'PASS: no prohibited product capability or core UI import found'
} finally {
    Pop-Location
}
