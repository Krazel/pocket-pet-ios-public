# Pocket Pet 0.2 — iPhone smoke

Use `PocketPet-0.2-build-1-iOS16-unsigned.ipa` and let Sideloadly sign it
locally. This is a short
owner test, not a request to explore every screen. Keep the same Apple ID and
bundle ID when reinstalling so the local app container can be updated in place.
Do not delete the app while progress matters.

Record before starting:

- iPhone model and iOS version;
- Pocket Pet version `0.2 (1)`;
- minimum supported system iOS `16.4`;
- IPA SHA-256
  `8bc5090112330387a8a3bd8dcd96ff6882396fc294755708e0f1e3483c8ac927`;
- test date and whether Reduce Motion or VoiceOver was already enabled.

## Five-minute core pass

1. Launch Pocket Pet. Confirm the Welcome screen is English, the egg art is
   complete, the name field accepts `Pip`, and Hatch stays disabled for an
   empty or invalid name.
2. Tap **Hatch My Pet**. Force-close the app on the hatching screen before
   tapping **Continue**, then reopen it. The same hatching milestone must
   return. Tap **Continue** and confirm `Pip's Habitat` opens.
3. Exercise **Feed**, **Play**, **Rest**, **Wake** and **Clean**. Each tap must
   produce one matching response, update the appropriate need/state and leave
   every other action reachable. Rest must change to Wake and Wake back to
   Rest.
4. Tap a care action and immediately send the app to the background. Reopen it.
   The saved result must remain and no second care action may have appeared.
5. Open Settings. Toggle **Sound** and **Reduce Motion**, return Home and confirm
   the app remains responsive. With Reduce Motion on, the creature may change
   expression but must not use decorative travel, hopping or particles.
6. From Home, swipe left to open **Pantry Nook**. Select **Dewberry**, **Seed
   Biscuit**, and **Moss Melon** in turn, then offer one item. Confirm the hand
   animation and creature response occur once, the selected quantity drops by
   one, and the new state survives a force-close and reopen.
7. Use the room ribbon to return to **Home**, then open **Pantry** again. Home
   care remains free and available; Pantry inventory and Sun Seeds remain
   unchanged except for the single item offered.

## Reminder and system pass

1. Complete at least three care actions, close the app and open it again so
   Pocket Pet has two foreground visits. Settings should then expose
   **Reminders**; no notification permission prompt may appear before this.
2. Open Reminders and choose **Not Now**. Confirm the sheet closes without an
   iOS permission prompt and focus/interaction returns to the Reminders row.
3. Open Reminders again, choose **Allow Reminders**, then answer the real iOS
   prompt. If allowed, change the local reminder time and confirm Settings
   shows reminders on. If denied, confirm Pocket Pet shows an explicit
   **Open iOS Settings** action and still works normally.
4. Revoke or enable Notifications in iOS Settings, return to Pocket Pet and
   confirm its Reminders screen reconciles with the real system state.

Notification delivery, timezone and DST boundaries are longer-running checks;
record them separately rather than blocking the five-minute core pass.

## Accessibility pass

1. Set iOS text size to its largest accessibility size. Reopen Pocket Pet and
   scroll through Welcome, Habitat and Settings. Complete labels such as
   Hunger, Happiness, Energy and Cleanliness must remain readable and all
   actions must remain reachable.
2. Turn on VoiceOver. On Home, verify the order is title, stage, four needs with
   numeric/status values, one creature summary, care actions and Settings.
3. Trigger all five care actions with VoiceOver. Each response should be
   announced once. Dismiss a Settings sheet and confirm focus returns to the
   row that opened it.

## Pass record

| Check | Result | Evidence or exact problem |
|---|---|---|
| Install and first launch | Pending | |
| Interrupted hatching recovery | Pending | |
| Five care actions | Pending | |
| Background/persistence | Pending | |
| Pantry selection, offer and persistence | Pending | |
| Home–Pantry navigation | Pending | |
| Local Reduce Motion | Pending | |
| Reminder permission and reconciliation | Pending | |
| Largest text size | Pending | |
| VoiceOver order and announcements | Pending | |

For any failure, keep the app installed and record only three things: the exact
last button pressed, a screenshot or short screen recording, and the visible
message. Do not include an Apple ID, password or signing log containing personal
data.
