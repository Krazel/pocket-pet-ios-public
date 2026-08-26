# Pocket Pet

Pocket Pet is a small, native iPhone virtual-pet game built for brief, gentle care sessions.

## Product boundary

- iPhone-native and English-only for version 0.1.
- One original creature with egg, child, and adult stages.
- Fully local progress; no account, cloud, analytics, advertising, or tracking.
- No Android, accounts, online services, real in-app purchases, or third-party dependencies.
- Internal TestFlight distribution is supported; App Review and public App Store release are not authorized by this repository.

## Current state

The pure Swift/Foundation domain and persistence package, native app surfaces,
local reminders and complete approved visual state families are implemented.
The repository declares 83 unit tests, 17 deterministic visual captures, a
repeatable Windows static gate and public GitHub Actions gates on macOS 26.

`PocketPetApp/PocketPetApp.xcodeproj` contains the native iOS app target:
SwiftUI owns the accessible controls and SpriteKit owns the approved habitat
composition and creature response. `verify-ios.yml` performs the unsigned
compile/test/analysis gate and the opt-in F01-F17 visual comparison. The
separate protected TestFlight workflow signs and uploads only when explicitly
dispatched with its upload switch enabled.

The public repository is source-visible for verification and build purposes;
it is not open-source. Code and artwork remain separately protected under
`LICENSE-CODE.md` and `ARTWORK-RIGHTS.md`.

See `docs/RUNTIME_QA.md` for the executable evidence contract and
`design/APPROVALS.md` for the public canonical asset register.
