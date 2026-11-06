# Android character export/import

Implemented in alpha 8, `0.6.0-alpha.8` (version code 8), following Claude's iOS 1.4 implementation at `dd522e1` and both export/import handoff entries of 6 November 2026. Schema 10 is unchanged. The user accepted all alpha 8 manual checks on the S24 FE running Android 17 on 6 November 2026 and confirmed real iOS → Android and Android → iOS transfers.

## Using it

- From the library, long-press a character or use its three-dot menu. **Export** opens the Android share sheet. **Save to file** opens the system document picker with the character's suggested `.vtrcharacter` filename.
- **Import Character**, below the creation choices, opens the system file picker. Choose a `.vtrcharacter` or `.json` file. The picker also allows other extensions because providers can omit the MIME type; the contents must decode as a character.
- Requiem also accepts character files shared or opened by another app using a content URI, including JSON, octet-stream and untyped files. No storage permission prompt is needed.
- A new identity imports and opens. An identical decoded character, ignoring its edited date, opens the existing sheet without rewriting it. A different character with the same identity asks **Replace**, **Keep Both**, or **Cancel**, showing both dates.
- Keep Both changes only the identity and numbered name. It fills numbering gaps and strips an existing trailing number. Replace retains the received bytes; Cancel makes no import write.
- Return to the library before exporting. An external import saves and closes any open sheet first, including focused text edits.

The format is the raw UTF-8 saved JSON, with no envelope. Exports preserve the stored bytes. Imports with an identity retain their original bytes and modified date; legacy files without an ID acquire one before being staged. UUID identity checks ignore casing. Existing filenames may use either case. New private filenames use lowercase, while newly encoded JSON UUIDs are uppercase.

Android limits imported files to 32 MB. Share-sheet snapshots are held temporarily in the app cache and exposed with a read-only URI grant. **Save to file** is the backup route: it writes to the location the user selects. These files contain the sheet and history as readable JSON. Sharing and storage destinations are chosen by the user; this feature does not synchronise devices.

## Recovery and compatibility

A validated pending import is stored atomically in the app's private, non-backed-up directory. Rotation keeps the pending choice; after process death, the app rechecks the stored file before resuming it. Keep Both journals its new ID before writing, so interrupted completion cannot create another numbered copy. The existing character file is checked again before replacement to prevent overwriting a file changed since the question appeared. Incoming requests are queued while another transfer is awaiting a decision.

Only export snapshots are exposed through FileProvider. App-private character storage and the pending journal remain inaccessible through that provider. The activity reuses its existing instance for incoming files, avoiding two independent sheet writers. The GitHub iOS UI-test skip flag is unchanged.

Shared coverage lives in `shared/fixtures/character-transfer.json`, `CharacterDocumentTest.kt` and `SaveContractTests.swift`. The exchange test uses the actual iOS store export/import APIs, covering advanced, unfinished guided, Morbus and older paid-dot saves. It checks unchanged bytes and copies whose only altered fields are ID and name. No iOS production code, catalog, fonts, schema, Swift package definition or workflow was changed.

## S24 FE acceptance checklist

1. Install alpha 8 over alpha 7 without uninstalling. Open existing ordinary and guided characters and check their state.
2. From the library, use both Export and Save to file. Check the suggested name and that Downloads contains the saved file. Cancel each picker once.
3. Reimport an unchanged export: it should open without a duplicate question. Test a real file exported from iOS 1.4, then export it back to iOS.
4. Edit a character after exporting it. Reimport the older file and try Cancel, then Keep Both. Check the dates, numbered name, original sheet, creation state and XP history. Test Replace using a disposable character.
5. Share a file from Samsung My Files into Requiem while another sheet has a focused, edited text field. Confirm the edit was saved and the incoming sheet opens correctly.
6. Rotate with a duplicate question open. Background and resume the app. Check the dialog and its buttons at a large text size and with TalkBack.
7. Try damaged JSON and a future-schema file; both should show an error and leave existing sheets unchanged.
8. Save all valuable characters outside the app and verify a restore before the later signing transition. Do not uninstall alpha 7/8 merely to test this feature.

PDF export remains shelved. Explicit system-backup rules, Android privacy access, release signing and Play-delivered migration tests remain separate release tasks.

## Validation record, 6 November 2026

Implementation commit: `31be565`. The final local checks passed: 220 Swift host tests, five
Kotlin-to-Swift consumer tests, 54 JVM rules/storage tests and all 18 Android 16 emulator tests.
Build and lint passed with no errors and seven existing SDK/dependency update warnings.
The new interaction tests cover picker cancellation, import, library long-press export, URI grants,
Save to file, focused edits before external import, duplicate choices, rotation, identical files,
invalid/future files, journal recovery and a save-picker result after model recreation.

Manual emulator checks used the real Android document picker and share sheet. An iOS fixture
imported and exported byte for byte with the `.vtrcharacter` extension intact. The duplicate dialog
remained readable at 150% text. Terminating the background process and launching a new process
restored its pending decision; Keep Both then changed only ID and name. Installing alpha 8 over
alpha 7 retained the existing synthetic character bytes. The APK uses the same debug signing
certificate as alpha 7. Screenshots and build logs are archived with the local alpha 8 APK.

The [implementation PR](https://github.com/aurumae/RequiemCharacterSheet/pull/3) records CI results.
The user subsequently completed the S24 FE checklist and confirmed a real iOS-to-Samsung exchange in both directions. The later Play-delivered beta still needs its own install/update check.
