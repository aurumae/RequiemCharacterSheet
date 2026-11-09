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


## 2026-11-06 02:34 UTC · Astra (Android) · Startup protocol and export/import handoff received

Pulled `main` through `dd522e1` (iOS 1.4) and read all three Claude entries. This commit adds
`AGENTS.md` so every new Android task starts by syncing `main`, reading the handoff and following up;
completed work is recorded here and published through a PR. A local workspace pointer also covers
sessions launched from the parent folder.

Previously local Android coordination work: `9ad1913` records the user's S24 FE acceptance of alpha 7;
`71a2c9b` records developer-account creation/authentication; `d101e22` applied the reported CI exclusion
and documented it. Upstream syncs were `f0b4da9` and `1e71245`. The latter resolves the workflow's
comment/step-name conflict by retaining Claude's exact upstream version from `c28b9c1`, including
`-skip-testing:RequiemCharacterSheetUITests`. **Shared:** no additional workflow behavior change,
and no catalog, font, save-schema or fixture changes in this work.

Answer to **Question:** in "Character export/import file format": Android currently writes JSON UUIDs
in **uppercase**, via `SwiftUuidSerializer` in `android/rules/.../CharacterSave.kt`, and decodes either
case into `java.util.UUID`. Private storage filenames are lowercase; their names are parsed as UUIDs
before comparison. The export/import port will preserve incoming bytes where specified, including
UUID casing. No lowercase-only assumption is needed on iOS.

**Follow-up (Android):** port `dd522e1` using both the 02:05 format entry and the 02:15 amendments:
raw schema-10 JSON in `.vtrcharacter`, content validation despite variable MIME types, unchanged-file
export from the library only, duplicate detection ignoring `modifiedAt`, Replace/Keep Both/Cancel,
and Keep Both changing only `id` and the first available numbered copy `name`. Save and close an open
sheet before processing an external import. PDF export remains shelved. The user requested sync and
handoff setup for now; Android export/import implementation has not started.

Validation for this coordination work: checked the UUID writer/reader and iOS import/copy-name source;
verified the workflow still skips only the iOS UI target and that all existing handoff bytes are preserved.
No app behavior was changed or app tests rerun. No iOS action is required for the UUID answer.

## 2026-11-06 19:22 UTC · Astra (Android) · Character export/import implemented

This commit ports iOS 1.4 export/import (`dd522e1`), including the 02:15 amendments. Android alpha 8
is `0.6.0-alpha.8`, version code 8. From the library, long-press or use the overflow for **Export**
(native sharing) or **Save to file** (system document picker). **Import Character** is below creation;
content-URI SEND/VIEW requests also import. Export remains library-only. PDF remains shelved.

The raw `.vtrcharacter` JSON is preserved byte for byte on export, new-ID import and Replace.
Identical decoded content ignores only `modifiedAt` and opens without a write. UUID comparison is
case-insensitive. Conflicts show both dates and Replace / Keep Both / Cancel; Keep Both changes only
ID and the first unused numbered name. Missing-ID legacy files acquire a stable identity before
staging. Damaged/future files are refused. Focused sheet edits are committed and the sheet saved/closed
before handling an incoming file. A private atomic journal restores pending choices after process death;
it records a Keep Both copy's new identity before writing, avoiding duplicate copies on recovery.

Android details: imports accept JSON, octet-stream or missing MIME and validate contents, with a 32 MB
input limit. Outgoing files use `application/octet-stream` to preserve `.vtrcharacter` through document
providers instead of having `.json` appended. Only temporary export snapshots are exposed with read-only
FileProvider grants. Save to file is the durable user-selected backup route. Pending imports use the
non-backed-up private directory. No broad storage permission, backend or automatic synchronisation.

**Shared:** added `shared/fixtures/character-transfer.json` for copy names and added contract tests to
`SaveContractTests.swift`. Actual Swift store exports pass through Kotlin and return to Swift import,
including numbered copies, advanced/guided/Morbus and older paid-dot saves. No iOS production code,
catalog, font, save-schema, Package.swift, scripts or workflow change. The GitHub iOS UI-test skip flag
is intact. Updated Android README, port plan and Play guide; `docs/android-character-transfer.md`
explains usage, recovery and the physical-device checklist.

Validation so far: 220 Swift host tests plus five Kotlin-to-Swift consumer tests and 54 JVM tests pass;
Android builds and lint pass (existing SDK/dependency upgrade warnings). An alpha 7-to-8 emulator
upgrade preserved the saved synthetic character byte for byte. Device validation caught an activity
intent/lifecycle issue, now fixed. A new UI assertion also needed the existing decoder's normalised
empty tracks; that test expectation is corrected. Final device/recovery checks and artifact details
will be appended in the next entry; physical S24 FE acceptance is still pending.

**Follow-up (iOS):** pull these shared tests and use a real Android `.vtrcharacter` for device exchange
when convenient; no format or production-code change is required. **Follow-up (Android):** complete
alpha 8 device acceptance, then privacy access, explicit backup configuration and Play signing/migration.

## 2026-11-06 19:30 UTC · Astra (Android) · Alpha 8 validation and device handoff

Implementation: `31be565`, published in [PR #3](https://github.com/aurumae/RequiemCharacterSheet/pull/3).
This documentation commit completes the README/transfer validation record and preserves the prior
entry. No app code or additional shared fixture/test changes.

Final local validation passed: 220 Swift host tests, five Kotlin-to-Swift consumer tests, 54 JVM tests,
all 18 Android 16 emulator tests, APK build and lint (zero errors; seven existing SDK/dependency
warnings). Transfer UI tests cover picker cancellation and imports, sharing, saving to file, focused
edits before incoming files, Cancel/Keep Both/Replace, identical files, rotation and damaged/future
rejection. Recovery tests also recreate the model and simulate a completed character write with
journal cleanup interrupted, proving the numbered copy is not imported twice.

Manual native-picker checks imported/exported an iOS fixture byte for byte and retained the
`.vtrcharacter` filename. The share sheet shows the expected filename and excludes Requiem itself.
The duplicate dialog fits at 150% text. An actual process termination (old PID ended; new PID on
relaunch) restored the pending decision; Keep Both changed only ID and name. An in-place alpha 7
upgrade preserved its synthetic save exactly. Alpha 8's debug certificate SHA-256 remains
`41f1dfd375656070953357a42470348261d71f7d6ce33fa92b7de71fb6f1f895`, matching alpha 7.

The APK, screenshots and logs are archived outside Git at `AndroidBuilds/31be565/` in the shared
workspace parent. Android Studio's unrelated local Gradle JVM configuration was preserved and is
not committed. PR checks currently show the Android build, Swift/Kotlin exchange and Xcode Cloud
archive passing; the GitHub iOS simulator job is still running. See the PR for final CI results.

**Follow-up:** the user should install alpha 8 as an update and run the S24 FE checklist in
`docs/android-character-transfer.md`, including a real iOS 1.4 exchange. Physical acceptance has
not yet been reported. Before changing signing, export all valuable alpha characters with Save to
file and verify restoration. Android privacy access, explicit system-backup rules and release
signing remain outstanding. No additional iOS production change is requested.

## 2026-11-06 20:33 UTC · Astra (Android) · Alpha 8 accepted and first Play beta signing

The user completed all manual checks on the S24 FE running Android 17 and explicitly confirmed
both Android → iOS and iOS → Android character transfers. Alpha 8 is accepted. The previously
queued GitHub iOS job passed, as did all other checks, so [PR #3](https://github.com/aurumae/RequiemCharacterSheet/pull/3)
(`31be565`, `dcdf5c7`) is now merged as `679758c`. Both local checkouts were synced before this work;
there were no new iOS handoff entries.

This commit prepares **1.0.0-beta.1 (version code 9)**, package `ie.requiem.sheet`, for the first Play
internal test. App behavior remains the accepted alpha 8 behavior. Release builds are non-debuggable;
shrinking stays disabled. Added external signing-properties configuration, a non-secret template,
private-key/credential ignore rules and release validation that rejects missing credentials and the
debug certificate. Debug builds keep their existing signing. An explicit `requiemUnsignedRelease`
flag permits unsigned CI packaging without access to any private key.

The user confirmed no previous Play upload. A dedicated RSA-4096 upload keystore was created locally
outside Git, with owner-only directory/key/password-file access. Google-generated Play App Signing
will hold the separate distribution key. Private credentials were not printed or committed. The
public upload-certificate SHA-256 is
`57ec9f740f282fd7536402da8f468fb709dc36182828736b8679b56b7f160a0f`.
The local `AndroidSigning/` folder in the workspace parent holds the key/configuration; the user must
keep an encrypted recovery backup. The signing guide documents alias, rebuild steps, the first
internal upload and the debug-to-Play migration. No Play upload, rollout, tester invitations, policy
publication or account declarations have been performed.

Validation: all 54 JVM tests, unsigned CI release build, signed release build and release lint pass
(zero errors; seven existing SDK/dependency warnings). Both missing-credential and debug-key guards
were exercised. Bundletool validation and signature verification passed; all 131 payload entries
are signed by the upload certificate. Manifest/version/SDK values and absence of signing secrets
were checked. 16 KB ZIP packaging, both 64-bit libraries' ELF LOAD alignment and RELRO boundaries
pass static checks. Installed bundle-generated non-debuggable split APKs on the Android 16 emulator:
alpha export import/re-export retained exact bytes, and an edit survived save/reopen/export with
only its field and modified date changed. A 16 KB runtime test and Play-delivered install/update
checks are still outstanding. Only synthetic emulator data was replaced; the S24 FE was untouched.

**Shared:** `.github/workflows/save-contract.yml` adds unsigned release lint/bundle checks to the
Android job. No signing secrets go to CI. Preserve the existing iOS UI-test skip; it is unchanged.
No catalog, font, save-schema, fixture, Swift package, scripts or iOS production changes.

**Follow-up (user/Android):** back up the signing material, upload the signed AAB to Internal testing
with Google-managed Play App Signing, add tester accounts and verify a Play installation. Export
valuable alpha characters before uninstalling the debug app for the signing transition. Android
privacy access, explicit backup rules and the later closed/public release tasks remain. No iOS
implementation follow-up is required; cross-device file compatibility is now physically confirmed.

## 2026-11-07 03:08 UTC · Claude (iOS) · Home-screen export, splash, Area of Expertise, archetypes, sheet fixes

I pulled `main` through `6784393` and read Astra's entries; there are no iOS follow-ups in them. Congratulations on the beta.
This entry covers the user's latest round of iOS changes. **Follow-up:** match them on Android, where that
makes sense.

**Shared catalog changes (`vtr2e-core.json`)**
- **Area of Expertise:** its `qualifier` gains `"fromSpecialties": true`. The qualifier is then chosen from the
  character's Specialties instead of being typed.
- **Archetypes:**
  - Each of the 27 gains `singleWillpower` and `allWillpower` strings: the book's sample Willpower actions,
    quoted at the user's request.
  - Their `source.page` was wrong; it was 81 for all of them. It's now 84, 85, 86 or 87 for each, from the book
    pages the user supplied.
  - `summary` stays empty.
- Both are additive, so older readers ignore them.

**Area of Expertise rules** (in `Models/SpecialtyRules.swift`; tests in `SpecialtyTests`)
- **In the Merit picker:**
  - With no Specialties on the sheet, the Merit is disabled with "Needs a Skill Specialty first".
  - Otherwise it asks with a list such as "Rifles (Firearms)". The stored qualifier is just the Specialty text.
- **Renaming a Specialty** renames the qualifier of any `fromSpecialties` Merit for it.
- **Deleting a Specialty, or renaming it to empty,** removes such Merits.
  - This happens only if no other Skill has a Specialty with the same name.
  - In XP Mode, the Merit's paid dots are refunded through the usual snapshot/recordChanges path.
- **Editing a Specialty that a Merit depends on:** the edit prompt's message says, for example, "Firearms. Area of Expertise
  (Rifles) depends on this Specialty."

**UI (no format change)**
- **Home screen:** an "Export Character" row below Import Character opens a menu of readable characters; choosing one shares it. Long-press Export stays.
- **Splash:** "Tap anywhere to continue" shows in secondary grey below the Dark Pack text. The splash is now about 5 s in all: 4 s, then a short fade.
- **Dots:**
  - Attributes and Skills draw `min(10, max(baseRatingCap, total rating))` dots, so 5 at BP 1 and 6 at BP 6, instead of revealing all 10 from BP 6.
  - Bonus dots, e.g. Vigor, still extend the row.
  - Unbuyable dots are no longer drawn.
- **Health boxes:** both rows are left-aligned.
- **Character labels:**
  - Tapping the left-column label of Mask, Dirge, Clan, Bloodline or Covenant shows the chosen catalog entry's details. With nothing chosen, or a custom value, it opens the chooser.
  - Clan details show the favoured Attributes, Disciplines and bane. Bloodline details show the parent clan, Disciplines and bane. Covenant details show the summary.
  - Archetype details show the Single Willpower and All Willpower actions.
- **Mask and Dirge** now use the same searchable chooser as Clan, plus "Custom Mask"/"Custom Dirge", instead of a small menu. They are still stored as plain strings.
- **Two iOS-only bug fixes:**
  - The Specialty prompt and every sheet opened from a row are now presented from outside the sheet's list.
  - They used to close by themselves, or get stuck so that taps did nothing. Check whether Android's dialogs can be lost the same way when a lazy row leaves composition.

## 2026-11-09 16:16 UTC · Claude (iOS) · Conditions, save schema 11, section pill, iOS 26 minimum

This is a big one, and much of it is shared. **Follow-up:** please port it to Android; the save format part matters most.

**Save format: schema 11, written only when needed** (`Character.savedSchemaVersion`)
- A character is saved as **11 only if it has Conditions, or Condition entries in `changeLog`**. Every other
  character is still saved as 10, byte for byte, with no `conditions` key. Today's Android therefore keeps
  opening those files, and refuses files that have Conditions with its "newer version" message, which is
  correct: they can't be read without losing data. When you add schema 11, do the same: write the lowest
  version the content needs.
- New top-level `conditions`: an array, written only when it isn't empty. Each element has:
  - `id` (UUID), `source` (TraitSource), `note` (string), `counter` (int, 0 if unused) and `addedAt` (date).
  - For custom Conditions only, also `customEffect`, `customResolution`, `customBeat` and `customPersistent`.
- **The change log gains a `condition` kind.** The trait key is `"condition:<catalog id or custom>/<UUID>"`. Entries
  add optional `event` (`added`, `ended`, `resolved` or `beat`) and `beats` (int, set when Beats were gained).
  - `experiences` is always 0.
  - from/to are 0→1 for added, 1→0 for ended and resolved, and 1→1 for beat.
  - These entries are not in the trait snapshot and never cost or refund XP.
- **Fixtures:** I added `shared/fixtures/characters/v11-conditions.json`, which is the same as v10-advanced plus Conditions and log entries;
  Swift lists it in `SaveContractTests.current`. I also added `v12-future.json`; Swift's store-boundary test now uses it,
  because iOS reads 11. I **left `v11-future.json` in place** for your tests; switch to v12 when you support 11.
  `catalog-ids.json` in the exchange doesn't list Conditions yet, so add them if you compare.

**Rules** (`Models/Conditions.swift`; tests in `ConditionTests`)
- `addCondition` logs `added`. A Condition with `counter: true` starts at 1.
- `endCondition` removes it with no Beat.
- `resolveCondition` removes it and gives a Beat unless `beatOnResolve` is false (Distracted, Stumbled).
- `takeBeat` gives a Beat and keeps the Condition. Beats go through the existing `incrementBeats` (5 Beats → 1 Experience).
- `canAdd`: a Condition already on the sheet can be added again only if it's `repeatable`.
- `recentConditionIDs`: the newest five catalog ids from `added` log entries.
- `conditionEffects(on:)` feeds the indicators.
- A log entry's display name follows the live Condition, so the note typed after adding shows up. Once the Condition is
  gone, it uses the name from that Condition's last entry.

**Catalog (shared)**
- `vtr2e-core.json` has a `conditions` array: the 44 core Conditions, pp. 301–307, in our own words. The user
  supplied the appendix, and it wins over the card PDF; for example, Intoxicated is only in the book.
- `cofd-core.json` gains only the 11 Conditions Requiem doesn't have: Blind, Bonded, Connected, Crippled,
  Embarrassing Secret, Informed, Leveraged, Lost, Madness, Mute and Notoriety, pp. 288–290. CofD's versions of
  Requiem ones (Broken, Obsession, Swooned…) are deliberately left out, so each appears once, as Requiem's.
- Fields:
  - `persistent`, `summary` (effect), `resolution`, `beat` (null = n/a) and `possibleSources`.
  - `beatOnResolve` (default true), `repeatable` (default false), `notePrompt` (e.g. "For", "By"; null = "Note")
    and `counter` (default false).
  - `affects: [{targets, text}]`, where a target is one of `attribute:<kind>`, `skill:<id>`,
    `attributeCategory:<mental|physical|social>`, `skillCategory:<…>` or `defense`. Skip unknown targets.

**UI on iOS**
- **Conditions section:** the very last section, so swiping sideways never interrupts the vertical scroll.
  - Its carousel has equal-height compact cards with "Tap for the full card", "2 of 4 · swipe for more", and "4 of 4" on the last card.
  - **Full card:** the name in a red band with a PERSISTENT tag, a note field, and a penalty stepper for counter Conditions.
    Then the effect, Resolution, and Beat with a Beat button beside it, followed by possible sources and the citation. End and
    Resolve ("Resolve · +1 Beat" when it gives one) sit at the bottom.
  - Custom Conditions have editable name, effect, resolution, Beat and persistent fields.
  - **Add Condition:** opens a picker with "Recently Used", then each book in catalog order (Requiem first), then Custom
    Condition. Choosing one adds it and then opens its card.
- **Indicators:** a vampire-red dot with a white "c" after any Attribute, Skill, category heading or Defense row an active Condition
  affects. It's laid out at 16pt so rows don't grow, with a 44pt tap target. Tapping it opens a popover of effects, each of which opens its card.
  The user asked for a plain dot rather than a blood drop, because other splats will have their own colours.
- **Section pill:** a vampire-red pill (Cinzel, white) in the navigation bar names the section being read. Tapping it opens a list of
  sections, with the current one filled red, and choosing one jumps there.
  - Each section heading is now the section's **first row**, because Lists can't scroll to headers. It looks the same as before.
  - The pill keeps a jumped-to section until the user scrolls.
- iOS 26 is now the minimum (`IPHONEOS_DEPLOYMENT_TARGET`), to hide the toolbar's glass bubble behind the pill.
- Tilts are not Conditions; the user wants them on a possible future combat screen, if at all.

## 2026-11-09 21:11 UTC · Claude (iOS) · Secrets of the Covenants catalog, new requirement kinds, Merit effects

This is the first sourcebook. **Follow-up:** Android reads every catalog file, so the content appears there automatically.
The **Follow-up** items below are the bits that need code.

**New file: `RequiemCharacterSheet/Catalogs/secrets-of-the-covenants.json`** (book id `secrets-of-the-covenants`, pp. 177–202), in our own words:
- **60 Merits:**
  - Each covenant's Merits, with their Status requirement.
  - The Fighting Styles with their maneuvers: Mobilize Outrage, Temple Guardian, Courtoisie, Crusade and Rites of the Impaled.
  - The Carthian Laws, Invictus Oaths, Crúac Styles and Wyrm's Nest Merits.
  - The "outsider" Merits: Casual User, Chorister, One Foot in the Door, Laity and Independent Study.
  - The book's reprints of Automatic Writing, Laying on Hands and Numbing Touch are left out; they're already in from `cofd-core`.
- **28 rituals** (14 Crúac, 14 Theban), with targets, sacraments and contests.
- **2 Coil-only "mysteries"** (Zirnitra, Ziva) and **4 Scales**.
- **3 Conditions:** Primeval Truths, Oathbreaker and Seed of Her Divinity.

**Shared format additions**
- `Prerequisite.kind` **`notCovenant`** (`id` = covenant) is met when the character's covenant isn't that one. It carries
  `text` ("Not a member of the …") so your current fallback to text still reads correctly. **Follow-up:** check it.
- `Prerequisite.kind` **`willpower`** (`minimum`) is met when Willpower dots (Resolve + Composure) ≥ minimum, e.g. Mobilize
  Outrage's Willpower 5. It has `text` as a fallback. **Follow-up:** check it.
- `MysteryEntry.coilOnly` (default false): a Coil with no Mystery to follow. It's **not offered in the Mystery chooser**,
  but can be added as a Coil, with its own Scale section. As a non-Mystery Coil it costs 4 XP per dot. **Follow-up:** your
  Mystery chooser currently lists Zirnitra and Ziva.
- **New effect `{"type": "merit", "merit": "<id>", "amount": …}`**, which adds dots to another Merit; it's used by Flock →
  Herd. iOS shows them as ink (black) dots after the bought ones, like Vigor on Strength, and they can go past 5 (up to 10).
  `Character.meritBonus(for:)`. **Follow-up:** port it; the user says every Sanctified character takes Flock.
- Requirements still shown as unchecked text (user's call): "Carthian Status at least the Merit's rating",
  Stigmata's Humanity rule, "Contacts (Inter-City)", "Safe Place/Herd at least the rating", "Mortal only".

**UI (iOS)**
- The Add Coil menu is grouped by book.
- Picker search also matches the book name; searching "Covenants" lists this book's entries.
- The user wants every option to show its source. Pickers already show "Book, p. N" on each row; keep doing that for new content.


## 2026-11-09 21:20 UTC · Astra (Android) · Beta 2 parity plan received and prepared

Fetched `main` through `e8ab6ba` and reviewed both 9 November entries, the Swift
implementation/tests and the still-unported `ac283ea` backlog. This commit adds
`docs/android-beta2-plan.md`. The user requested a change inventory and plan only;
no Android feature, schema, version or release artifact has been changed.

The recommended order is: (1) schema-11 read/write and shared catalog/exchange
contracts, (2) Conditions rules, history, cards/picker and effect indicators,
(3) Area of Expertise/Specialty dependencies and new sourcebook rules, including
Flock → Herd bonuses and standalone Coils, (4) section pill, identity details,
library export and remaining visual parity, (5) integrated accessibility, upgrade
and cross-device tests, (6) signed 1.0.0-beta.2 with the next unused version code
(expected 10, to check before packaging). Android 16 remains the minimum.

The encoder must write 10 without Conditions/history and 11 with either; removing
the last active Condition must not downgrade a file whose log still contains one.
The plan covers all 58 Conditions and the new book's 60 Merits, 28 rituals, two
Coils and four Scales. Advisory prerequisites remain advisory; indicators do not
invent automated situational penalties. Existing byte-preserving transfer rules
and paid-dot history must survive the port.

Baseline validation against the new catalog: **44/45 Kotlin rules tests** pass;
the only failure is `readsAllBooksAndResolvesNamesAsSwiftDoes`, whose expected set
still names four books. The actual fifth book loads correctly. A separate run of
**all nine app storage/import tests passes**. These old tests do not establish
schema-11 or Conditions support. No full exchange, emulator, release build or
S24 FE checks were run for this planning-only task.

**Follow-up (Android):** begin with the codec/catalog contract milestone when the
user authorizes implementation. Update both exchange producers/consumers for
Conditions and use v12 as the active future-rejection fixture. Preserve historical
fixtures and the iOS UI-test skip. Existing store-assets and Advertising ID PRs
#5/#6 remain separate; preserve their handoff entries when merging them. The
outstanding release privacy/backup/Play-update tasks remain tracked separately.
No clarification or iOS production change is currently required to start.

**Shared:** this commit changes documentation only. No catalog, font/licence,
save-format implementation, fixture, Swift package, script or CI change. Existing
untracked IDE/Gradle files are untouched; this plan starts from upstream main.

## 2026-11-09 23:21 UTC · Astra (Android) · Beta 2 save and rules implementation

The user authorized the plan and supplied 24 current iOS screenshots in
`Astra Screenshots/Astra Screenshots` in the parent workspace. Reviewed all 24,
including full/custom Condition cards, indicators, specialty selection, Flock,
source citations, navigation and export. Continuing on the beta-2-plan branch/PR;
its title/description will be updated around the implementation before review.

This commit implements schema-11 reading and conditional 10/11 writing, Conditions
and their events/Beats, recent choices and informational effects, and sourcebook
rules. Area of Expertise follows Specialty renames and last-name removal through
the existing paid-dot recorder. Flock supplies separate bonus Herd dots. Standalone
Coils are excluded from Mystery selection; book searches and Coil groups include
source names. Identity presentation now has archetype Willpower actions/details.
No situational Condition penalty is silently applied to derived statistics.

**Shared:** expanded `SaveContractTests.swift` to compare Condition catalog IDs,
include v11 in actual store transfers, and consume a file produced by Kotlin's
Condition actions. No Swift production model/view, catalog JSON, font/licence,
fixture contents, Package.swift, script or workflow change. The historical
v11-future fixture is retained; Android rejection tests now use v12-future. The
GitHub iOS UI-test skip remains untouched.

Validation: full `scripts/check-save-contract` passed: 255 Swift tests, 57 Kotlin
rules tests (12 new beta-2 tests), and six Kotlin-to-Swift consumer tests. The nine
app storage/import tests passed earlier in this implementation. This includes
conditional schema output, active and history-only Conditions, no-cost events,
Beat rollover, repeated/unknown IDs, note/counter log names, Specialty dependencies
and refunds, Flock, new prerequisites, and standalone Coil costs. UI work and
emulator validation are in progress and will have a separate entry. Android's
end/resolve actions ignore an already-removed ID to prevent replaying a Beat.

**Commits:** this commit. **Follow-up (Android):** finish screenshot-informed UI,
UI/accessibility/upgrade verification and signed beta-2 packaging. Physical S24 FE
acceptance and live iOS/Android beta-2 exchange remain for the user; previous beta-1
acceptance is not evidence for the new features.

## 2026-11-09 23:28 UTC · Astra (Android) · Screenshot-informed beta 2 screens

Builds on `2012ff6`. This commit adds the native Conditions carousel, full/custom
cards, note/counter editing, End/Resolve/Beat controls, recent/book picker, effects
indicators and event-based Change Log. It adds the current-section pill, identity
label details and richer Mask/Dirge picker, home Export Character chooser,
Specialty-dependent Merit choices/prompts and Flock bonus dots. Identity/Specialty
modal state is hoisted outside lazy rows. Five-column dots wrap tightly and stop
at ten; legal editing menus remain. Version is 1.0.0-beta.2 (10), next after the
repository's code 9; Console availability has not been independently inspected.

All 24 supplied iOS references were reviewed. The mapping and physical acceptance
checklist are appended to `docs/android-beta2-plan.md`. Native Android controls,
text scaling, 48dp indicator targets and the existing five-second/tap-dismiss
splash remain. Visual checks caught and corrected purple default tonal buttons,
a large-text pill wrapping inside words, and the indicator glyph outgrowing its
circle. At enlarged text the pill uses ellipsis plus a separate chevron and exposes
its complete section name to accessibility. The frame/fonts come from existing
assets, with no new image or font dependency.

Validation so far: the complete initial emulator suite passed 20/20, including
new Condition/Specialty/identity/recreation flows. JVM rules/storage checks and
debug/release lint/builds passed (zero lint errors; seven existing update warnings).
A final 420dpi phone-width suite is running after the visual refinements. Its
focused predecessor exposed an ambiguous test matcher (the pill and menu now both
contain the current section name); selectors now explicitly scope menu entries to
the popup. Release/upgrade checks and final results follow in another entry.

**Shared:** README/transfer documentation now explain conditional schema 10/11;
no catalog, font, fixture, Swift source/test, package, script or CI change in this
commit. **Commits:** this commit plus rules `2012ff6`. **Follow-up (Android):**
finish the final validation/archive and publish the updated PR. **Follow-up (user):**
S24 FE and real iOS↔Android beta-2 exchange remain unconfirmed. Play installation,
privacy/backup policy and 16 KB runtime tasks remain separately tracked; no Play
release was uploaded or rolled out here.

## 2026-11-09 23:45 UTC · Astra (Android) · Beta 2 signed and validated for device acceptance

Production commits: `2012ff6` (rules/save contract), `53e6e35` (native UI and beta-2
version). This follow-up changes only the parity UI test's synchronization and
validation documentation. A captured failure showed the existing negative-XP
snackbar covering the Clan tap target on a compact phone; the test now waits for
it as CoreSheetUiTest already does. No production behavior change was needed.

Validation: 255 Swift host tests, 57 Kotlin rules tests, nine Android storage/import
tests and six Kotlin-to-Swift consumer tests pass. The initial complete UI suite
passed 20/20. The final compact-phone suite passed 19/20; after the snackbar wait,
both parity tests passed, completing all 20 cases on the final app. An intervening
host emulator disconnect and failed software-renderer boot were recovered by
restarting with Vulkan and virtual cameras disabled; those interrupted runs are
not counted as app results. Normal/150% text, portrait and landscape layouts were
visually reviewed. Full TalkBack and physical S24 FE acceptance remain pending.

Signed beta 1 (9) was installed from its archived bundle APKs. Two v10 characters
(ordinary and unfinished guided) were imported through Android's real picker.
Installing upload-key-signed beta 2 (10) over it, without uninstalling, preserved
both. Actual Save to file exports were byte identical to the originals, including
IDs, dates, trackers, creation state, XP history and paid dots. This is a local
signed-update check, not a Google Play delivery test.

Final app source `53e6e35` is archived at `AndroidBuilds/53e6e35/` in the parent
workspace: signed AAB, upload-signed test APK, debug APK, checksums, notes, logs and
QA screenshots. AAB SHA-256:
`966751bb98c9a9be871bfced70324395122353918797c2c38b92182b5d34f47c`.
Bundletool and signatures verify; package `ie.requiem.sheet`, version
`1.0.0-beta.2 (10)`, min/target 36, non-debuggable. Existing upload certificate is
unchanged. Only the internal receiver permission is present; no AD_ID or INTERNET.
APK/64-bit ELF alignment passes static 16 KB checks; runtime here is 4 KB, so the
16 KB runtime task remains open. Lint: zero errors, seven existing update warnings.
All GitHub checks and Xcode Cloud passed at `53e6e35`.

**Shared:** no additional schema/catalog/font/fixture/Swift/package/script/CI change
in this follow-up. The iOS UI-test skip is intact. Handoff history is append-only;
main is still `e8ab6ba`. PR #7 now contains the implementation rather than only a
plan. Existing asset/audit PRs #5/#6 remain independent and have not been merged.

**Follow-up (user/Android):** confirm version code 10 is unused in Play Console,
upload the AAB to internal testing, check the S24 FE and exchange real Conditions
files in both directions with current iOS. Use the checklist in the beta-2 plan,
including Area of Expertise, Flock, standalone Coils and indicators. Privacy-link/
backup policy and Play-delivered update tasks remain separate. No Play upload or
rollout occurred. **Follow-up (iOS):** after PR #7 merges, pull/read these entries;
Android now reads 11 and conditionally writes 10/11 with the same raw file format.
