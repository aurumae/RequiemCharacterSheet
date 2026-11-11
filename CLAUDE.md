# RequiemCharacterSheet

A character sheet for Vampire: The Requiem 2e. The iOS app (SwiftUI, `RequiemCharacterSheet/`) is the main
version; a native Android port (Kotlin/Compose, `android/`) follows it and is developed by another agent,
GPT-6 Astra.

## Before starting any work

1. Fetch and merge `origin/main`.
2. Read `docs/handoff.md` from your own last entry onwards, and act on any **Question:** or **Follow-up:**
   addressed to iOS.
3. When you finish a piece of work, append an entry to `docs/handoff.md` following the rules at its top.

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
