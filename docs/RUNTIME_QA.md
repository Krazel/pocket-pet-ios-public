# Pocket Pet 0.1 runtime QA contract

Status: automated macOS/Xcode portion passed. Public run `32979582655` passed
the shared build/test/analyze gate plus D01-D10, V01-V08 semantic preflight,
R01-R04 and N01-N03 at sanitized commit
`1dcb87f986bef435a04eda1dae4b2bfa8c541ff7`. The matching private app-source
commit is `95209ff`. The 24 AX5 screenshots and 18 reduced-motion screenshots
were inspected after execution; the adaptive Home needs and Settings controls
are readable and all required top/bottom content remains reachable. F01-F17
composition review from run `32919057391` remains accepted because normal-size
approved surfaces were not changed. Real VoiceOver speech/focus,
Accessibility Inspector, Voice Control/Switch Control and the operating-system,
durability and physical-device smoke remain open.

This is the executable completion contract for the approved visual family. It
does not turn source review, a generated reference or a Debug fixture into
runtime evidence. Every item below must come from the real app target built at
the recorded candidate commit.

## Reference setup

- Use one iPhone Simulator model and iOS runtime for the complete F-series.
- Record device model, iOS version, native screenshot dimensions, display
  scale, locale, appearance, content size and candidate commit in `run.md`.
- Use English, light appearance, portrait orientation, 12/24-hour settings that
  visibly render `7:00 PM`, and the pet name `Pip`.
- Select the simulator after the first build by the closest safe-area and
  viewport match to the approved 853 × 1844 canvas; do not change it mid-run.
- Preserve each native screenshot. Create the comparable 853 × 1844 copy with
  one documented uniform scale plus centered crop. Never stretch either axis.
- For every F-series frame, save a 50% overlay, a visual/pixel difference image
  and a short closed difference record. An unresolved visible difference means
  the visual gate remains open.

Recommended evidence layout (all files are absent until actually captured):

```text
design/runtime-captures/<candidate>/
  run.md
  raw/F01-welcome-ready.png
  normalized/F01-welcome-ready.png
  overlays/F01-welcome-ready.png
  diffs/F01-welcome-ready.png
  differences.md
  accessibility/
  motion/
```

## Deterministic Debug fixtures

The Debug app target accepts one isolated launch argument:

```text
--visual-state <scenario>
```

Supported scenarios are `welcome-empty`, `welcome-ready`, `hatching`, `child-comfortable`,
`child-needs-care`, `child-sleeping`, `adult-evolution`, `adult-comfortable`,
`adult-needs-care`, `adult-sleeping`, `settings-off`, `settings-on` and
`settings-denied`.

The UI screenshot suite also passes `--visual-static`. In Debug fixtures this
forces only the rendered Home/milestone motion input to its approved static
equivalent while leaving the persisted Reduce Motion preference—and therefore
the visible Settings toggle—off. This prevents the repeating SpriteKit idle
cycle from changing pixels between otherwise identical F-series runs. Motion
timings are still validated separately without this argument in R01–R04.

Each launch recreates only
`FileManager.default.temporaryDirectory/PocketPetVisualHarness/<scenario>`,
uses a fixed clock, valid PetState/Preferences input, the real coordinator and
routing, and a fake local-reminder adapter. It cannot read or write the ordinary
Application Support save. Release excludes the parser, fixtures, fake scheduler
and fixed clock with `#if DEBUG`; launch arguments have no product behavior.

The separate opt-in runtime QA suite uses three additional Debug-only controls:
`--runtime-qa-system-reduce-motion` forces the app's effective reduced-motion
input while leaving its local preference off,
`--runtime-qa-local-reduce-motion` persists the app's own preference in the
isolated fixture, and
`--runtime-qa-extended-reactions` keeps response copy observable for UI
assertions. None exists in Release. The effective-input fixture verifies app
response to reduced motion but does not replace the real system-toggle smoke
below.

F01–F05 and F07–F10 start directly from the matching scenario. For F06, start
`child-comfortable` and tap the real Feed control. For F11–F17, start from the
appropriate Settings scenario and use the real rows/sheets: `settings-off`
covers main/pre-permission/information sheets, while `settings-on` and
`settings-denied` cover their reminder branches. The harness does not replace
testing the real system notification prompt, settings, scheduling, relaunch,
care timing or accessibility configuration.

After the native UI-test target compiles, run the fixed reference device with:

```bash
POCKET_PET_UI_DESTINATION='platform=iOS Simulator,name=iPhone 16 Pro,OS=latest' \
  bash scripts/run-visual-captures.sh
```

The script records the candidate, Xcode version, requested destination and
available devices, runs the visual XCTest serially, preserves the `.xcresult`
and exports its named screenshot and per-frame metadata attachments. Each
metadata record includes scenario/arguments, candidate, simulator identity,
locale/orientation/appearance, fixed fixture time and native PNG dimensions.
After export it runs `scripts/compare-visual-captures.swift` through the active
Xcode toolchain. The comparator requires all 17 named PNG and metadata pairs,
the exact candidate, one shared simulator/runtime, deterministic arguments and
the locked SHA-256/dimensions of every approved reference. It preserves raw
captures, applies one recorded uniform aspect-fill scale plus centered crop,
and writes normalized 853 × 1844 images, 50% overlays, exact absolute diffs,
separate 4× heatmaps, per-frame JSON metrics, `run.md` and an open
`differences.md` ledger. Reference and runtime pixels are composited over
opaque sRGB white by one documented policy before comparison.
It uses no masks, stretch, manual crop, automatic alignment or third-party
dependency.

The machine status is deliberately zero-tolerance: `PIXEL_IDENTICAL` requires
zero RGB delta; every nonzero delta is `REVIEW_REQUIRED`. Metrics such as
different-pixel percentage, MAE, RMSE, maximum/95th-percentile channel delta
and the difference bounding box are diagnostic only. They can never close a
visible difference or replace the human review and D/V/R/operating-system
gates.
Override the destination only
before beginning a complete F-series, then keep it identical for all 17 frames.
The public GitHub workflow exposes this as the explicit
`run_visual_captures` input, default `false`, so ordinary pushes run the faster
compile/test/analysis gate while a deliberate dispatch runs the complete
simulator comparison suite.

The same workflow exposes a separate `run_runtime_qa` input, also default
`false`. It creates an iPhone SE (3rd generation), runs D01-D10 at AX5, returns
to the default content size for V01-V08 semantic preflight, then records the
simulator while exercising R01-R04 and N01-N03 normal-motion timing. The job
preserves three `.xcresult` bundles, screenshots, accessibility hierarchy
attachments, logs and `runtime-motion.mp4`. This automated semantic preflight
cannot claim VoiceOver speech/focus order, Voice Control, Switch Control or
Accessibility Inspector evidence; those remain part of the real-device smoke.

## Executed automated runtime gate

Run `32979582655` on the public sanitized mirror recorded zero for every gate:

```text
swift test: 0
xcodebuild: 0
release analyze: 0
D01-D10 Dynamic Type UI tests: 0
V01-V08 semantic UI preflight: 0
R01-R04 and normal-motion UI tests: 0
xcresult attachment export: 0
attachment inventory: 0
simulator motion recording: 0
```

The retained runtime artifact contains 10 Dynamic Type tests with 24 PNGs,
eight semantic tests with eight hierarchy attachments, four reduced-motion
tests with 18 PNGs, three normal-motion sequences and a 49,149,504-byte
`runtime-motion.mp4`. Every manifest entry records the same iPhone SE simulator
and `isAssociatedWithFailure: false`. Evidence is downloaded under
`.verification-work/public-runs/32979582655/`; generated contact sheets used
for human review are in its `review/` directory.

The earlier green run `32976386411` proved the harness but its AX5 screenshots
revealed overly narrow Home cards. That visual evidence was rejected, the
accessibility-only layout was corrected without changing normal-size approved
surfaces, and the stricter D04 frame-width assertion now prevents regression.

## Canonical 1:1 frames

These 17 frames correspond exactly to the 17 approved full-screen references.
The two isolated creature studies remain source assets rather than extra app
screens; their hashes are verified statically and their actual rendering is
covered by F02/F03 and F07/F08.

| ID | Runtime state | Approved reference |
|---|---|---|
| F01 | Welcome, valid `Pip`, ready to hatch | `design/approved/welcome-egg-seed-nest-v1.png` |
| F02 | Hatching, settled reveal frame | `design/approved/hatching-seed-nest-v1.png` |
| F03 | Child, awake and comfortable | `design/approved/habitat-home-sunny-patio-v1.png` |
| F04 | Child, awake and needs care | `design/approved/habitat-child-needs-care-v1.png` |
| F05 | Child sleeping | `design/approved/habitat-child-sleeping-v1.png` |
| F06 | Child Feed response, captured after the real Feed control | `design/approved/habitat-care-response-family-v1.png` |
| F07 | Adult evolution, settled reveal frame | `design/approved/adult-evolution-b-v1.png` |
| F08 | Adult, awake and comfortable | `design/approved/habitat-adult-comfortable-b-v1.png` |
| F09 | Adult, awake and needs care | `design/approved/habitat-adult-needs-care-b-v1.png` |
| F10 | Adult sleeping | `design/approved/habitat-adult-sleeping-b-v1.png` |
| F11 | Settings main, reminders off | `design/approved/settings-main-garden-cards-v1.png` |
| F12 | Reminder pre-permission explanation | `design/approved/reminder-pre-permission-garden-cards-v1.png` |
| F13 | Reminders enabled at 7:00 PM | `design/approved/reminders-enabled-garden-cards-v1.png` |
| F14 | Notification permission denied | `design/approved/reminders-denied-garden-cards-v1.png` |
| F15 | Support development information | `design/approved/support-development-info-garden-cards-v1.png` |
| F16 | Privacy information | `design/approved/privacy-info-garden-cards-v1.png` |
| F17 | Support unavailable | `design/approved/support-unavailable-garden-cards-v1.png` |

The Feed frame is the approved visual anchor for the care-response family.
Play, Rest, Wake and Clean still require behavioral/accessible verification of
their real controls, persisted outcomes and exact response copy; they do not
invent four additional visual specifications.

## Dynamic Type

Run at an accessibility content size (AX5) on the smallest supported iPhone.
Scrollable views need top and bottom captures or a clip; a top screenshot alone
does not prove that content remains reachable.

| ID | Required coverage |
|---|---|
| D01 | Welcome with keyboard, 12-character valid name and invalid-name message |
| D02 | Hatching, including immediately available Continue |
| D03 | Adult evolution, including immediately available Continue |
| D04 | Home plus Feed, Play, Rest, Wake and Clean response copy/reflow |
| D05 | Settings main |
| D06 | Reminder pre-permission sheet |
| D07 | Reminders enabled and native time picker |
| D08 | Permission denied |
| D09 | Support development |
| D10 | Privacy |

Assert Support unavailable content, scrolling and dismissal as part of F17; it
shares the simpler information-sheet shell.

## VoiceOver

Static screenshots cannot prove focus, order or announcements. Store a screen
recording plus an Accessibility Inspector hierarchy/log for each sequence.

| ID | Required sequence |
|---|---|
| V01 | Welcome empty → validation → valid; persistent label, error and enabled state |
| V02 | Hatching title/copy/result, immediate Continue and one announcement |
| V03 | Adult evolution title/copy/result, immediate Continue and one announcement |
| V04 | Home order: title, stage, four numeric needs/statuses, one scene summary, five actions, Settings |
| V05 | Settings off → pre-permission → dismissal, with focus returned to Reminders |
| V06 | Reminders enabled and 7:00 PM time control |
| V07 | Permission denied and explicit iOS Settings action |
| V08 | Support development, Privacy and Support unavailable; Done and row focus return |

V04 must exercise all care controls and hear the exact responses: `Tasty,
thank you!`, `That was fun!`, `Cozy time.`, `Good morning!` and `Fresh and
comfy!`. The visual speech bubble is not a second accessibility element.

## Reduce Motion and timing

Use recordings or frame analysis rather than a single screenshot.

| ID | Required sequence |
|---|---|
| R01 | System Reduce Motion on/local off: Hatching uses only its bounded static/fade equivalent |
| R02 | System Reduce Motion on/local off: Adult evolution uses only its bounded static/fade equivalent |
| R03 | System off/local on: Home ambience remains static and all five care cues avoid travel, hop, bob or particles |
| R04 | Effective Reduce Motion: Settings navigation and sheets have no decorative transition |

Also retain normal-motion clips for Hatching, Adult evolution and the five Home
care actions so approved timing and return-to-rest can be checked. Continue must
never wait for decorative motion.

## Real operating-system and durability smoke

Debug fixtures do not prove Apple framework behavior. On a clean simulator and
at least one physical iPhone when available:

- obtain value before the reminder invitation appears;
- test Not Now, first permission, denial, later revocation and re-enabling;
- inspect pending and delivered notifications, one-per-24-hour enforcement,
  delayed/cleared delivery, timezone change and a DST boundary;
- relaunch during onboarding and each milestone;
- background during a care response and confirm the saved outcome;
- verify primary-state corruption recovers from the last-known-good copy;
- repeat common flows with Voice Control/Switch Control where iOS provides it;
- confirm no account, network, analytics, ads, tracking or purchase path occurs.

## Acceptance and traceability

The runtime gate passes only when:

1. the shared macOS gate has a zero result for `swift test`, the Debug
   simulator build and the Release device analysis at the exact candidate
   commit;
2. F01–F17 have validated metadata plus raw, normalized, overlay, exact diff,
   heatmap and machine-readable metric evidence;
3. every visible difference is corrected or explicitly accepted without
   changing the approved promise;
4. D01-D10, the automated V01-V08 semantic preflight and R01-R04 are recorded
   and pass, followed by the manual assistive-technology sequences this runner
   cannot prove;
5. the operating-system/durability smoke is recorded;
6. every approved entry in `design/APPROVALS.md` links its current runtime
   evidence, and `docs/CANDIDATE_VERIFICATION.md` records the final result.

Until all six conditions are true, Pocket Pet remains a compile-and-visual
pre-candidate rather than the fully verified iOS candidate.
