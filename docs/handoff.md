# Handoff between the iOS and Android agents

Claude (Claude Code, in Xcode) works on the iOS app. GPT-6 Astra works on the Android port. The user is the
same person for both, and iOS is the main version: Android follows its behaviour. This file is how we tell
each other what we've done, so the user doesn't have to pass notes.

## Rules

- **Read before starting work.** Pull `main`, then read every entry after your own last one.
- **Append only.** Add new entries at the bottom; never edit or delete an earlier entry, even your own. To
  correct or answer something, write a new entry that refers to the earlier one by its heading.
- **One entry per piece of work**, written in the same commit as the work, or straight after it.
- **Heading:** `## YYYY-MM-DD HH:MM UTC · Author (platform) · Short title`.
- **Contents:** what changed and why, the commits, and what the other platform needs to do, if anything.
  Mark anything that needs an answer with **Question:** and anything the other side must do with
  **Follow-up:**. Keep it short and link to docs for detail.
- Always flag changes to the shared parts: `RequiemCharacterSheet/Catalogs/`, `RequiemCharacterSheet/Fonts/`,
  the save format and `shared/fixtures/`, `Package.swift`, `scripts/` and `.github/workflows/`.
- `.gitattributes` merges this file with `merge=union`, so if both of us append at once, Git keeps both
  entries instead of reporting a conflict. Check the order of the entries afterwards.

---

## 2026-11-06 01:50 UTC · Claude (iOS) · Handoff file, and iOS changes since PR #1

Hello Astra. The user asked us to communicate through this file from now on. I'm adding a pointer to it in
`CLAUDE.md`; please add the same to your `AGENTS.md`.

iOS commits on `main` since your PR #1 merged:

- `50bc532`: the keyboard reveal action in the SwiftUI environment is now an Equatable wrapper
  (`RevealEditingFieldAction`) instead of a bare closure. This is iOS UI only, with nothing to port.
- `5c32103`: Xcode's recommended project settings. `DEVELOPMENT_TEAM` is now set once at project level
  instead of per target, and String Catalog symbol generation is on. This touches the Xcode project only.
- `c28b9c1`: the `ios` job in `.github/workflows/save-contract.yml` now passes
  `-skip-testing:RequiemCharacterSheetUITests`. On the `macos-26` runner,
  `testCreatedCharacterIsSavedAndCanBeDeleted` timed out reading the sheet's accessibility tree ("Timed out
  while evaluating UI query"). The runner took 19 s to settle after one tap and about 30 s per query. The same
  test passes in Xcode Cloud and locally, so this is runner speed, not an app bug. The job still builds the app
  and runs all 204 unit tests, including `SaveContractTests`. **Follow-up:** please keep the flag when you edit
  the workflow.

Pushing from Xcode was refused for the workflow commit, probably because Xcode's GitHub sign-in lacks
permission to change workflows; `git push` from Terminal worked. Worth knowing if you change workflows from a
tool with a limited sign-in.

Next on iOS: character export and import, which the Android plan also lists as next. I'll write a separate entry
with the proposed file format once the user has agreed it, so both apps can read each other's exported files.

## 2026-11-06 02:05 UTC · Claude (iOS) · Character export/import file format

The user chose the format and the duplicate behaviour (2026-11-06). iOS implements it in
`CharacterStore` (`exportData`, `prepareImport`, `importCharacter`), `CharacterFile.swift` and
`CharacterListView`. The tests are in `CharacterStoreTests` ("Export and import"). **Follow-up:** please
implement the same on Android so files move both ways.

**File**
- The extension is `.vtrcharacter`. The contents are exactly the saved character JSON (UTF-8, schema 10
  today), with nothing wrapped around it. iOS exports the stored file byte for byte.
- The file name is the character's name with `/ \ : * ? " < > |` and control characters replaced by spaces,
  trimmed, then `.vtrcharacter`. An empty name gives `Unnamed Character.vtrcharacter`.
- iOS declares the UTType `com.omccolgan.RequiemCharacterSheet.character`, conforming to `public.json`. No
  MIME type is declared, so on Android expect `application/json`, `application/octet-stream` or nothing.
  Accept them and check the content instead.

**Import rules**
1. If `schemaVersion` is greater than the version the app supports, refuse: "This character was saved by a
   newer version of the app. Update the app to open it." Nothing is written.
2. If the file isn't a JSON object with a string `name`, or doesn't decode, refuse: "The file isn't a character
   file, or it's damaged." The `name` check matters because every field has a default, so any JSON object
   would otherwise import as a blank character.
3. Identity is `id`, compared as a UUID, not case-sensitively.
   - **No character here has that id:** store the file unchanged, keeping its `modifiedAt`, then open it.
   - **One does, and the content is equal apart from `modifiedAt`:** don't ask; just open it.
   - **One does, and the content differs:** ask. The title is "“Name” Is Already Here". The message is "The imported
     copy was edited <date>. The one on this device was edited <date>." The buttons are Replace (destructive),
     Keep Both and Cancel. Replace stores the file unchanged under the same id. Keep Both changes only `id`
     to a new UUID and leaves everything else, including the name and `modifiedAt`, as it was.
4. A file with no `id` (schema 1) gets one when it's decoded, and is stored re-encoded with that id.

**UI on iOS (for parity)**
- **Export:** each readable row in the character list has a long-press menu with "Export", which opens the share sheet.
- **Import:** an "Import Character" row below "New Character" opens a picker for `.vtrcharacter` and `.json` files.
- **From outside the app:** opening a `.vtrcharacter` from Files, Mail or AirDrop imports it. If a sheet is open, it's saved and closed first, so
  the import can't be overwritten by the open sheet.

**Question:** does Android write UUIDs in lowercase? iOS accepts either. A lowercase file is stored byte for byte
and keeps its id.

## 2026-11-06 02:15 UTC · Claude (iOS) · Export/import amendments, iOS 1.4

These amend "Character export/import file format" above, following the user's review:

- **Keep Both also renames the copy**, numbering it like copied files. The second copy becomes "Lucius Avelorn (1)",
  the third "Lucius Avelorn (2)", and so on.
  - It uses the first number no other character has.
  - A trailing " (n)" on the name is dropped before numbering, so a copy of "Lucius Avelorn (1)" is numbered from "Lucius Avelorn".
  - An empty name becomes "Unnamed Character (1)".
  - Only `id` and `name` change in the file.
  - See `CharacterStore.copyName(for:taken:)` and its tests. **Follow-up:** match this on Android.
- **Export is only from the character list,** not from inside an open sheet. The user wants it that way.
- **Opening a file from Files shows a preview first** (Share → app); the user is fine with that. There's no need to make a tap open the app.
- **PDF export of a character is shelved indefinitely** by the user. Don't start it on either platform.
- **iOS MARKETING_VERSION is now 1.4,** because Xcode Cloud refused more 1.3 builds. Android versions are independent.
