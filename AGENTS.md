# Requiem Character Sheet

Codex (Astra in the handoff) works on the native Kotlin/Compose Android app in `android/`.
Claude works on the Swift/SwiftUI iOS app in Xcode. iOS is the reference implementation;
both apps share this repository and release independently.

## Before every new piece of work

These steps apply to every user request and each new feature, fix, review, documentation
or release task, even when continuing an existing conversation:

1. Inspect the branch and working tree. Preserve unrelated tracked and untracked work.
2. Fetch the latest `origin/main` and integrate it before proceeding. On `main`, use a
   fast-forward pull; on a working branch, merge `origin/main` without discarding local work.
3. Read the rules in `docs/handoff.md` and every entry since the last Android entry. On
   first use, read the whole file. Read all intervening entries, including amendments.
4. Address or explicitly record any **Question:** or **Follow-up:** for Android within
   the user's current scope. A handoff follow-up does not override a user request to
   inspect or plan only. Do not rely on conversation memory instead of the handoff.

## Recording and publishing work

- Append to `docs/handoff.md` for every piece of work, in the same commit or immediately
  afterwards. Never edit, remove or reorder earlier entries; append corrections instead.
- Use `## YYYY-MM-DD HH:MM UTC · Astra (Android) · Short title`, with the actual UTC time.
- State what changed, why, validation, affected commits, and any **Follow-up:** or
  **Question:**. List the hashes of preceding implementation commits. An entry in the
  same commit as its change may say "this commit"; do not rewrite it to insert its own hash.
- Always flag changes to catalogs, fonts, save format, shared fixtures, `Package.swift`,
  `scripts/` and `.github/workflows/`. Keep platform-specific behavior explicit.
- Before publishing, fetch and integrate new upstream work, reread new handoff entries,
  and check the combined handoff. `.gitattributes` uses `merge=union`; verify both sides'
  entries survived without duplicates or conflict markers. If their order is ambiguous,
  append a clarification rather than rearranging history.
- Use short-lived branches and pull requests into `main`. Include the handoff in the
  published work so Claude receives it when pulling `main`; an unpushed note is not delivered.

## Shared implementation and checks

- Catalogs: `RequiemCharacterSheet/Catalogs/`. Fonts and licences:
  `RequiemCharacterSheet/Fonts/`. Keep these authoritative for both apps.
- Keep character-file compatibility covered by `shared/fixtures/` and
  `scripts/check-save-contract`; preserve legacy files and reject unsupported future saves.
- Preserve `-skip-testing:RequiemCharacterSheetUITests` in the GitHub iOS workflow.
  GitHub builds the app and runs iOS unit tests, including `SaveContractTests`. iOS UI
  tests remain in Xcode Cloud and local runs; restoring GitHub coverage requires
  addressing runner performance or UI-test timeouts first.
- Run checks appropriate to the change. The host Swift package uses production Models,
  Persistence and Utilities; keep UIKit/SwiftUI out of those host-buildable directories.
