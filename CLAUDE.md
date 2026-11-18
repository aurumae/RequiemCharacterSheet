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
- Forsaken is outside the contract until it is enrolled with Android (phase 3 of `docs/android-forsaken-plan.md`).
  Keep Forsaken fixtures out of `shared/fixtures/` until then: they are in `ForsakenCharacterSheetTests/Fixtures/`,
  where Android's tests read them too, so never change an existing one. `swift test` and CI's `ios` job run
  Forsaken's tests. A new key in Forsaken's save goes into a new fixture and `docs/forsaken-save-format.md`; once
  the app has shipped, it also needs the next schema version.
- The Android tests run on this Mac too. `scripts/check-save-contract` does everything CI's exchange job does: the
  policy check, `swift test`, Android's unit tests (`:core`, `:requiem`, `:app`) and the save exchange both ways.
  Run it before pushing a change to anything shared or to `android/`. To run only Android's tests:
  `android/gradlew -p android :core:test :requiem:test :app:testDebugUnitTest`. Lint, the APK build and the
  emulator UI tests still run only on GitHub or on Astra's machine.

## Shared with Android

Catalogs (`RequiemCharacterSheet/Catalogs/`), fonts (`RequiemCharacterSheet/Fonts/`), the character save
format with `shared/fixtures/`, `Package.swift`, `scripts/` and `.github/workflows/` are used by both apps. So are
Forsaken's: `ForsakenCharacterSheet/Catalogs/` and `Fonts/`, its save format and fixtures, and
`shared/forsaken-headings/`.
Changes to them need a handoff entry saying what Android must follow up.

`swift test` builds both apps' `Models/`, Requiem's `Persistence/`, `Chronicles/Core/` and the unit tests on macOS, so
keep UIKit and SwiftUI out of those. Forsaken tests that need the app's views or artwork go in
`ForsakenCharacterSheetTests/SheetSectionTests.swift`, which the package leaves out and only Xcode runs. Run
`swift test` as well as the Xcode tests.

## Design decisions

`docs/design-decisions.md` records product decisions that both apps follow. One example is that official options are
always grouped by book, with no way to turn books off. Read it before adding content or lists, and add new
decisions there when the user makes them.
