# Android Forsaken phase 2 viewer

Forsaken Preview is a separate Android 16/API 36 app with application ID
`com.omccolgan.ForsakenCharacterSheet`. Version `0.1.0-preview.1` uses code 1.
Install the debug APK beside Requiem. No Play listing, upload or release signing
has been configured.

## Try the preview

1. Export a `.wtfcharacter` from iOS, or copy either original JSON fixture from
   `ForsakenCharacterSheetTests/Fixtures/` to the phone. Import Character accepts
   either extension and verifies the payload's game and version.
2. Open it and use the section menu. Inspect saved base ratings, tracks, Gifts,
   totem advantages, creation choices, Conditions and history. Tap named catalog
   entries for rules, or use Browse catalog under Character to search by book.
3. Save file on the sheet writes the original import. The library's Export action
   shares it through the Android chooser. Check its `.wtfcharacter` name and reopen
   the result in iOS. Actual device exchange remains an acceptance task.
4. Import a different copy with the same identity. Cancel leaves the library alone,
   Replace adopts the incoming bytes, and Keep Both makes a separate identity/name
   while retaining the other fields. An identical file keeps the existing bytes.
5. Try opening a Requiem file in Forsaken and a Forsaken file in Requiem. Both apps
   refuse it before any library mutation. Try text at 150% and landscape as well.

The preview has no create/edit controls. Saved base dots are labelled as such.
Effective ratings, capacities, dice pools, current XP balance and creation legality
are not calculated. Pure characters have no effective Moon Gift section, matching
iOS. Unknown fields and currently inactive stored values survive raw export.
Missing identity in a partial file is the one import exception to byte preservation
and receives a UUID once for stable import recovery. This is not a canonical writer.

## Implementation and reference coverage

`:forsaken` depends on `:core`. `:forsakenApp` depends on `:forsaken` and `:sheet-ui`.
Neither depends on `:requiem`. The app has its own private library, pending-import
journal and FileProvider authority. Common UI supports an import-only library and
exporting an open sheet after pending writes finish. The Dark Pack splash is shared.

| iOS reference | Android evidence in this phase |
| --- | --- |
| `SaveFormatTests.theFixturesUseEveryKey` | `ForsakenReaderTest.submittedFixturesCoverEverySchemaOneFieldAndRawSnapshotRetainsThem` checks fixture keys against the Kotlin model and Swift CodingKeys. |
| `thePlayFixtureMeansWhatItSays` | Stored facts are asserted in `thePlayFixtureKeepsAllStoredFactsWithoutApplyingRules`. Effective form ratings, armor, budgets and XP assertions remain phase 3. |
| `theCreationFixtureMeansWhatItSays` | `theCreationFixtureIsReadWithoutGrantingOrCorrectingAnything` retains the saved Survival/Purity grants pending Claude's existing question. |
| `aSavedCharacterIsWrittenBackUnchanged` | `PreviewTransferTest.submittedFilesOpenRestartAndExportByteForByte` uses the production store. This proves raw transfer only. A canonical writer test remains phase 3. |
| Catalog load order/first ID wins | `ForsakenCatalogTest` checks all source files, filename-stem ordering, unofficial visibility, shared-core entry kinds, nested details, advisory text and heading coverage. |
| Library transfer and recovery | `PreviewTransferTest`, `PreviewUiTest` and Requiem's transfer/recovery tests cover real store/activity paths, duplicate choices, restart, invalid files, names, authorities and exact bytes. |

The Android job runs the new JVM and app storage tests, both apps' lint and debug
packaging, instrumentation compilation, and unsigned release packaging. Instrumented
tests run locally on the API 36.1 emulator. The shared Requiem exchange and manifest
are unchanged. A green contract summary therefore says nothing about Forsaken
numeric-rule parity. Full physical-phone TalkBack and real iOS/Android exchange
remain for acceptance.

## Artwork and licences

Builds copy the authoritative Comforter and Grechen Fuemen fonts and their full OFL
notices, plus the original logo, skull and icon. No Flat Earth Scribe or Trade Winds
font is bundled. About uses system text and includes the flattened-heading credit.

The supplied heading XML stays byte-identical. AAPT truncates the single `pathData`
strings in Character Creation (40,895 characters), Auspice Benefit (33,655) and
Kuruth Triggers (33,504) at its 32,767-byte string limit. Android therefore packages
all heading XML under raw resources and builds Compose vectors from those original
paths. It neither splits contours nor changes the shared files. The resource test
compares every packaged XML with the original and parses all 24 headings, including
the long ones. Width/height come from `headings.json`; headings scale with text and
have heading semantics. Brush strokes use Swift's FNV-1a/SplitMix64 algorithm/seeds.
The fixed sheet-only watermark uses the shared 7% multiply treatment.

Claude's coordinated contract/fixture/Xcode-exchange proposal remains open in
`android-forsaken-plan.md`. Phase 3 must agree and enroll the real writer and rule
capabilities before claiming Forsaken exchange parity.
