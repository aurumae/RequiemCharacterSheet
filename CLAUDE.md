# RequiemCharacterSheet

A character sheet for Vampire: The Requiem 2e. The iOS app (SwiftUI, `RequiemCharacterSheet/`) is the main
version; a native Android port (Kotlin/Compose, `android/`) follows it and is developed by another agent,
GPT-6 Astra.

## Before starting any work

1. Fetch and merge `origin/main`.
2. Check that CI passed on it: `gh run list --branch main --limit 1`. If it failed, that comes first: fix it if
   iOS work caused it, and tell the user if it's Android's.
3. Read `docs/handoff.md` from your own last entry onwards, and act on any **Question:** or **Follow-up:**
   addressed to iOS.
4. When you finish a piece of work, append an entry to `docs/handoff.md` following the rules at its top.
5. After each push, watch the run (`gh run watch`) until `CI result` passes. Don't start the next piece of work on
   a red `main`.

## iOS goes first

New work is done on iOS and ported to Android afterwards, so iOS is often ahead. The Android port of Forsaken
doesn't start until the iOS app has been submitted to the App Store. CI must stay green all that time: a red
`main` should mean something is broken, never that Android hasn't caught up.

- `swift test` runs `scripts/check-policy`, the contract check CI runs before anything else. If it fails, fix the
  contract in the same commit as the change that broke it.
- `shared/fixtures/contracts.json` names tests in `RequiemCharacterSheetTests/`. If you rename or remove one,
  change the name there too.
- A new Requiem save field, schema version, fixture, catalog field or catalog rule value has to be declared:
  supported on iOS, and pending on Android with a link to the handoff entry. Follow "Adding an iOS feature before
  its Android port" in `docs/ci-contract-policy.md`. Never mark Android as supporting something it hasn't ported.
- Adding catalog entries is safe for Android; changing an existing one may not be, because Kotlin tests assert
  rules outcomes from the live catalogs. Before changing an entry, search `android/*/src/test` for its id and the
  ids it lists. Update any expectation the change makes wrong in the same commit, and say so in the handoff.
- Forsaken is outside the contract until Android has a `:forsaken` module. Keep Forsaken fixtures out of
  `shared/fixtures/` until then.
- This Mac has no Java, so the Android tests run only on GitHub. That run is the only check that a catalog change
  hasn't broken Android.

## Shared with Android

Catalogs (`RequiemCharacterSheet/Catalogs/`), fonts (`RequiemCharacterSheet/Fonts/`), the character save
format with `shared/fixtures/`, `Package.swift`, `scripts/` and `.github/workflows/` are used by both apps.
Changes to them need a handoff entry saying what Android must follow up.

`swift test` builds `Models/`, `Persistence/`, `Utilities/` and the unit tests on macOS, so keep UIKit and
SwiftUI out of those. Run it as well as the Xcode tests.

## Design decisions

`docs/design-decisions.md` records product decisions that both apps follow. One example is that official options are
always grouped by book, with no way to turn books off. Read it before adding content or lists, and add new
decisions there when the user makes them.
