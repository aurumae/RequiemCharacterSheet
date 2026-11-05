# Android parity with iOS 1.3

Updated 5 November 2026. **Android alpha 7 implements the iOS 1.3 changes at `611b295`.** The Kotlin/Compose app, Android 16 minimum and shared repository are retained. [Integration PR #1](https://github.com/aurumae/RequiemCharacterSheet/pull/1) brings both native apps together; the numbered sections below retain the scope and acceptance criteria used for the implementation.

**Alpha 7 (`0.5.0-alpha.7`, version code 7) was accepted on the Galaxy S24 FE running Android 17 on 5 November 2026.** The user reported that the app works as expected. The delivered source commit is `4c14885`, integrated into `main` by PR #1 as `8581eef`. This build incorporates all six upstream commits through `611b295` and retains the alpha 6 debug signing identity.

## Delivery status

- Implemented schema 10, all four catalogs, bloodline rules and pickers, replacement fonts and offline licences, and the Android readability/editing changes below. Shared fixtures cover Morbus, a custom bloodline and unfinished creation, plus historical migration.
- Local validation: 205 Swift host tests, 44 JVM rules/storage tests, all 13 Android emulator interaction tests, and bidirectional save exchange pass. The new shared bloodline scenario checks 12 actions, alongside the existing 37-action ordinary-play and 71-action creation scenarios. Android lint reports no errors (seven dependency/SDK warnings).
- GitHub CI builds/tests the real Xcode app and its test targets, the Kotlin app, and the cross-platform save exchange. All three final-commit jobs passed, as did the Xcode Cloud archive; PR #1 was merged as `8581eef`.
- An Android 16 emulator upgrade from alpha 6 preserved all bytes of three synthetic legacy save files through installation and first launch. The APK contains the exact tracked IM Fell English/Cinzel fonts and full notices, with no Caslon Antique or Mrs Eaves resources.
- Manual emulator checks covered the normal sheet, 150% text in the bloodline picker (portrait and landscape), readable licence text, and custom bloodline editing above the software keyboard. A background process-death check confirmed a new process, restored the open sheet and preserved the complete edited save byte for byte. These checks do not replace a full TalkBack session or physical-device testing.
- Physical S24 FE acceptance is complete based on the user’s report on 5 November 2026. A full TalkBack session has not been separately confirmed. Export/import, Android privacy, backup rules, release signing and Play-delivered build checks are still outstanding.

Opening an unchanged older file does not migrate it. The first real edit writes schema 10; alpha 6 cannot read that updated file, so retain a backup before testing.

## What changed

| iOS commit | Change | Android impact |
| --- | --- | --- |
| `60538d5` | Remove font-enumeration entitlement | iOS-only configuration; no Android permission is needed for bundled fonts. |
| `d8da597` | Version 1.2 interaction polish | Keep edited fields above the keyboard, improve scrolling near the page border and keep Touchstone rows compact. |
| `b93e8b4` | Bloodlines, Morbus, Cachexy and identity pickers | Update the save contract, catalog, rules and sheet together. |
| `8724e47` | VoiceOver, Dynamic Type and contrast fixes | Apply the equivalent TalkBack, font-scaling and readability improvements to Compose. |
| `7c1b589` | Replace the old fonts with IM Fell English and Cinzel Medium | Replace Android's font resources and typography, including the special treatment of numerals. |
| `611b295` | About screen, Dark Pack and font licences; version 1.3 | Expand Android's existing About this app with version information and readable licence pages. |

The most consequential change is **character schema 10**. Bloodline was a string; it is now a catalog/custom `TraitSource` object under the same JSON key. Android alpha 6 only accepts schemas 1–9 and correctly refuses a v10 file. Updating only the screens or copying the new catalog would leave this incompatibility unresolved.

The new fourth book, `dark-eras-companion.json`, adds the Morbus bloodline and its five-dot Cachexy Discipline. The bundled catalog now has four books, 14 Disciplines and one bloodline. The new bloodline changes in-clan Discipline selection, XP prices, guided-creation eligibility and Bane presentation.

Sources: [six-commit comparison](https://github.com/aurumae/RequiemCharacterSheet/compare/506ea78...611b295), [schema change](https://github.com/aurumae/RequiemCharacterSheet/blob/611b295/RequiemCharacterSheet/Models/Character.swift), [bloodline rules](https://github.com/aurumae/RequiemCharacterSheet/blob/611b295/RequiemCharacterSheet/Models/CatalogFormatting.swift), [new catalog](https://github.com/aurumae/RequiemCharacterSheet/blob/611b295/RequiemCharacterSheet/Catalogs/dark-eras-companion.json).

## 1 Integrate upstream and restore the shared save contract

Start an `android/ios-1.3-parity` branch from the accepted Android history, including these planning documents, in a separate worktree. Merge the fetched iOS history into it. This preserves both lines of development and keeps the original Xcode checkout available for ongoing Swift work.

A read-only three-way merge preview found one conflict in `RequiemCharacterSheet.xcodeproj/project.pbxproj`: the test group adds `BloodlineTests.swift` where our branch adds `SaveContractTests.swift` and `fixtures`. Retain all three entries and their target/resource registrations. Preserve the existing Swift host-package catalog loading when integrating `Catalog.swift`. An otherwise clean text merge does not establish build or save compatibility.

Update the Kotlin catalog and codec before exposing the new features:

- Add the `bloodlines` catalog kind and load the fourth JSON book through the existing shared catalog build. Keep one authoritative copy of book data in the iOS catalog directory.
- Represent a bloodline using `TraitSource`, as clan and covenant already do. Read schemas 1–10 and write schema 10. Link legacy typed names such as `morbus` to the catalog; preserve unfamiliar custom names, unknown catalog IDs and an empty/missing bloodline.
- Preserve UUIDs, timestamps, creation progress, ordered damage, paid-dot amounts and change history. Opening an unchanged legacy file must not rewrite it or update its edited date; the first real edit can migrate its serialized format.
- Add current Swift-written v10 fixtures for a Morbus, a custom bloodline and unfinished creation. Keep the existing v9 fixtures as historical migration cases. Replace the intentionally unsupported `v10-future.json` case with a genuinely future v11 case and update both test suites and fixture documentation.
- Add bloodline IDs to the cross-platform catalog comparison and update writer/reader expectations. Continue testing unsupported-file preservation and full bidirectional exchange, rather than checking only successful decoding.

Primary code: `CharacterSave.kt`, `CharacterCodec.kt`, `Catalog.kt`, `TraitDefinitions.kt`, `SheetEdits.kt`, `SaveContractTests.swift`, Kotlin save tests and `shared/fixtures/characters/`.

**Acceptance:** both platforms exchange v10 characters without losing any game state; historical fixtures migrate correctly; unchanged old files retain their bytes and dates; v11 files remain untouched. Existing creation and advancement exchange sequences still pass.

## 2 Implement bloodline rules and the new pickers

Use the shared catalog data for descriptions, parent clans, Discipline lists, Bane text and book/page references. Avoid a Morbus-specific branch in the rules engine so later bloodlines can use the same implementation.

- A known bloodline's Discipline list replaces its clan's list. Morbus uses Auspex, Celerity, Cachexy and Obfuscate. Show “In-clan for Morbus” in the picker and details, and use that same list for the three-dot creation budget and XP prices.
- Restrict adding the catalog Cachexy entry to Morbus members in ordinary play and guided creation. Explain the restriction in the picker and enforce it in the committed add operation. Preserve the existing custom-entry route and do not delete already saved Disciplines when the bloodline changes.
- Preserve historical paid-dot amounts when clan or bloodline changes: later purchases use the new classification, while refunds use the recorded purchase cost. Selecting a bloodline must not retrospectively charge XP or replay past purchases.
- Show the Morbus Bane alongside the clan Bane. It is a bloodline rule, separate from the three optional Banes and the clan-bane activation switch.
- Make tapping the Clan, Bloodline or Covenant value open a searchable catalog chooser with descriptions, references and selection state. Include Custom, No Bloodline and Unaligned as appropriate. Custom opens a field on the sheet and links a matching catalog name when editing finishes. Keep Mask and Dirge's existing choices available.
- Group matching-clan bloodlines first. Match iOS's current behaviour for other clans: show the parent-clan warning but permit selection. Changing clan does not silently clear a bloodline. A custom bloodline without a catalog definition continues to use the clan's Discipline list.
- Present the guided-creation favoured-Attribute prompt after the clan picker closes, with a clear Not Now action. Use Compose dismissal/focus state to coordinate this, rather than copying Swift's timed delays.

Primary code: `SorceryRules.kt`, `ExperienceRules.kt`, `CreationRules.kt`, `BookEntries.kt`, `BookDetails.kt`, `SheetEntries.kt`, `SheetEdits.kt`, `CharacterDetails.kt`, `CatalogScreens.kt`, `EntryRows.kt` and `CreationEditor.kt`.

**Acceptance:** a Morbus can select Cachexy and buy a dot for 3 XP; a non-Morbus sees why it is unavailable. Custom/empty bloodlines, mismatched parent clans, changing bloodline after purchases, both Bane displays and resumed guided creation behave like iOS. Cover these cases with shared action examples and focused Android interaction tests.

## 3 Replace the fonts and expand About this app

Use **IM Fell English Regular** for the display face and **Cinzel Medium** for subheadings and display numerals, matching the new Swift theme. iOS deliberately uses Cinzel's lining numerals rather than IM Fell's old-style digits. Compose needs explicit font selection for those digits; a fallback font alone will not override digits already present in IM Fell. Keep native body text and scalable text styles where iOS does.

The supplied asset folder is `VtrAppAssets/Cinzel,IM_Fell_English/`. These four files are byte-for-byte identical to their counterparts committed at `611b295`:

| Supplied file | Committed iOS file |
| --- | --- |
| `Cinzel/static/Cinzel-Medium.ttf` | `Fonts/Cinzel-Medium.ttf` |
| `Cinzel/OFL.txt` | `Fonts/Cinzel-OFL.txt` |
| `IM_Fell_English/IMFellEnglish-Regular.ttf` | `Fonts/IMFellEnglish-Regular.ttf` |
| `IM_Fell_English/OFL.txt` | `Fonts/IMFellEnglish-OFL.txt` |

Use those tracked files as the reproducible source for Android resources and notices. Only these two static font faces are required. Remove Caslon Antique and both Mrs Eaves resources from the Android package and remove their theme references. Check the built artifact for leftover old fonts; merging the iOS deletions alone does not remove Android's separate copies.

Both replacement families have supplied SIL Open Font License 1.1 notices. Bundling them with the app is permitted with the required copyright and licence information. Include the full supplied notices in the package and make them readable offline in About. No additional embedding licence purchase is needed for these fonts. [Official OFL guidance for mobile apps, question 1.20](https://openfontlicense.org/ofl-faq/)

Expand the existing **About this app** entry into a native, scrollable screen or sheet with:

- The Android app name, version name and build/version code from build metadata, rather than the iOS version number.
- The Dark Pack logo and complete existing notices.
- Separate IM Fell English and Cinzel entries with author attribution and the full respective licence, readable with TalkBack, selectable and reflowed at large text sizes.

Keep the existing five-second, tap-dismissible launch notice and reuse its legal text in About. A published Android privacy-policy link belongs here when release preparation supplies the policy; the new iOS About screen does not itself resolve that task.

Primary code: `SheetTheme.kt`, Android font/licence resources and the About/launch components currently in `MainActivity.kt`.

**Acceptance:** headings, accented names such as Crúac, mixed text/numbers and category labels match the new theme. Both full licences are present in the built app and accessible offline; old font resources are absent. The launch timer, early dismissal and rotation behaviour remain correct.

## 4 Carry over readability and interaction improvements

Android already supplies scalable `sp` text, semantic headings, rating actions and individual Health/Willpower announcements. Audit and extend those controls against the new iOS behaviour rather than replacing them wholesale.

- Announce symbolic prerequisites and history intelligibly: “Crúac 2 dots” and “1 to 3”. Keep the symbols visible while providing separate spoken text. Name fields by their purpose, announce values/selection and learned states, and hide decorative chevrons and repeated status icons from TalkBack.
- Ensure overflow ratings have an accessible choose-rating action and that launch/negative-XP notices expose dismissal. Keep the compact attribute/skill dots and full-sized legal-value menus requested earlier.
- Match the revised muted colour (`#6C6C70`) and caution colour (`#8C6408`), and keep unlearned powers readable instead of heavily fading them. Check actual foreground/background combinations, including warning text and buttons.
- Scale Health and Willpower marks with font size and wrap their tracks. Preserve the compact default appearance while preventing clipped symbols or overlapping controls at enlarged sizes.
- Keep the focused field above the keyboard, including growing Aspirations, custom traits and individual Touchstones. Use Android insets and Compose focus/scroll handling. Verify Done, Back, picker dismissal and process restoration retain edits and position.
- Add suitable scroll padding around the paper border and logo. Reproduce the subtle edge treatment only where it leaves content readable and reachable. Preserve Android's system gesture areas instead of copying iOS's bottom-gesture deferral.

**Acceptance:** inspect normal and enlarged text in portrait and landscape, with the keyboard and TalkBack enabled. Complete edits near the bottom of the sheet, reach the last library row and read both licences without clipping. Use the current iOS theme/source as the reference; the original 15 screenshots predate the font and picker changes.

## 5 Validate and deliver the next parity alpha

Run the existing Swift suite and bidirectional exchange script, Kotlin rules/storage tests, Android lint and Compose interaction tests after the affected changes. Add meaningful checks for migration, bloodline eligibility/pricing, picker flows and licence availability. Validate the Xcode project/test target on macOS as well as the host Swift package; the Linux host run cannot verify the iOS UI.

Build the next alpha with the next unused Android version code above 6 and the same debug signing certificate used by alpha 6. Test an in-place upgrade using synthetic existing characters, including a custom bloodline and unfinished creation. Compare IDs, timestamps on untouched files, XP history, paid dots and damage before and after. Reopen after process death and exchange v10 files in both directions. Back up valuable test data before installing a schema-changing build; an older alpha will not read a v10 file once a real edit saves it.

Use an Android 16 emulator for the minimum supported version and the Galaxy S24 FE on Android 17 for physical acceptance. The previous alpha's passing test counts remain historical evidence, not evidence for this new build.

**Acceptance:** the new parity alpha passes automated checks and device testing, with a recorded commit, version and save-format support. Then resume the [Play Store release guide](play-store-release-guide.md): export/import and alpha-data migration, Android privacy policy, backup rules, signing, updated screenshots, internal Play upgrades and the applicable closed-testing process. Account setup and tester recruitment can continue during this parity work.

## Release-guide implications

| Release concern | Status after reviewing iOS 1.3 |
| --- | --- |
| Font embedding permissions | Resolved. Android uses the tracked replacement fonts and full notices; both licences are available offline in About. |
| Dark Pack attribution | Android now has a permanent About page with version, Dark Pack and font pages, plus the existing launch notice. |
| Artwork and catalog provenance | Still a separate release review; a font licence does not cover the logo, border or book material. Include the newly added Dark Eras Companion material. |
| Save compatibility | Schema 10 and legacy migration are implemented and tested in both directions. User-facing export/import remains outstanding. |
| Privacy, backup and signing migration | Still outstanding. The fetched changes do not add Android policy text, export/import, backup rules or release signing. |
| Store screenshots | Capture the updated Android app after the new typography and pickers land. Existing screenshots describe the older appearance. |

Both apps remain native in one repository. With alpha 7 accepted on the S24 FE, resume release preparation with character export/import and signing migration, privacy access and explicit backup rules.
