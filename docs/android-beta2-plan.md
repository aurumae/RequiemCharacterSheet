# Android beta 2: iOS parity plan

Planning baseline: `origin/main` at **`e8ab6ba`**, fetched 9 November 2026.
Android remains the accepted **1.0.0-beta.1 (9)** from `f0bd5a7`; no Android
production source changed in the intervening iOS commits. This document plans the
port. No feature implementation or new release build is part of this planning task.

## Changes to bring across

The scope includes the still-unported 7 November changes as well as both new
9 November handoff entries. The shared JSON is authoritative; keep both native
apps in the same repository and do not duplicate catalog content into Kotlin.

| iOS commit | Change | Android work |
| --- | --- | --- |
| `ac283ea` | Home-screen Export Character, keeping long-press export | Add a readable-character chooser that reuses the existing Android share/export implementation. |
| `ac283ea` | Area of Expertise chooses an existing Skill Specialty; dependent Merits follow renames and are removed/refunded when their last matching Specialty goes away | Implement the rules, dependent-Merit explanation and qualifier chooser. Preserve a Merit while another Skill has the same Specialty name. |
| `ac283ea` | Archetype Willpower actions and corrected citations for all 27 archetypes | Display the shared `singleWillpower` and `allWillpower` text and existing book/page references. |
| `ac283ea` | Mask/Dirge use the richer searchable identity chooser; tapping identity labels opens the chosen entry's details | Extend Android's existing search with explicit Custom choices and details for Mask, Dirge, Clan, Bloodline and Covenant. Mask/Dirge remain plain strings in saves. |
| `ac283ea` | Dot-count, Health alignment, splash and modal-presentation refinements | Verify the portions Android already implements; address remaining visual and modal-lifetime differences. |
| `21499fa` | Conditions model, actions, history, cards, picker, effect indicators and schema 11 | Implement end to end, starting with the file contract. |
| `21499fa` | Current-section navigation pill | Replace the static Sections label with a pill showing the current section and a picker highlighting that section. |
| `21499fa` | iOS minimum raised to 26; SwiftUI presentation fixes | No Android minimum-version change. Keep Android 16/API 36 minimum; use Compose lifecycle/accessibility behavior. |
| `e8ab6ba` | Secrets of the Covenants | The fifth book adds 60 Merits, 28 rituals (14 Crúac, 14 Theban), 2 standalone Coils, 4 Scales and 3 Conditions. Verify content presentation and implement the new rules below. |
| `e8ab6ba` | `notCovenant`/`willpower` prerequisites, `coilOnly`, Merit-to-Merit bonuses, book-name search and book-grouped Coils | Add the missing rule checks, Flock → Herd bonus dots, Mystery filtering and picker refinements. |

The Condition catalog totals **58**: 44 from Requiem, 11 additional CofD Conditions
and 3 from Secrets of the Covenants. Preserve Requiem-first ordering and the
deliberate omission of duplicate/reprinted entries. Tilts and a combat screen are
outside this release scope; PDF export remains shelved.

## Findings from the Android comparison

- `CURRENT_SCHEMA` is 10, and both the codec and import boundary reject 11.
  That currently protects Conditions from being discarded. Merely raising the
  number is insufficient: the model, log, encoder and exchange tests must agree.
- Kotlin's catalog loader already reads every JSON file and tolerates additive
  fields. The new book's existing categories load, but `CatalogKind` has no
  Conditions, unknown prerequisite kinds are advisory text, and Merit bonus
  effects are ignored. `coilOnly` is not filtered from the Mystery chooser.
- Android already provides compact legal-value menus, five-second/tap-dismiss
  splash with a grey hint, searchable Mask/Dirge names and left-aligned wrapping
  Health boxes. Attribute/Skill dots already follow Blood Potency rather than
  automatically jumping to ten. Verify the ten-dot display ceiling, bonus dots,
  unbuyable-dot presentation and the iOS splash fade; preserve working controls.
- Many sheet dialogs are already hosted outside the lazy list, but identity and
  Specialty presentation still has row-local state. Audit that lifetime while
  adding Conditions and identity details; the SwiftUI fix itself is not portable.
- The current header is a static Sections button. Section keys already exist,
  including separate lazy items for the three Skill categories, which must all
  map back to Skills when tracking the visible section.
- After the catalog update, **44/45 rules tests** and **9/9 app storage/import
  unit tests** pass. The one failure is the old four-book expectation in
  `SaveContractTest.readsAllBooksAndResolvesNamesAsSwiftDoes`. This is baseline
  evidence, not validation of the unimplemented features. No emulator, complete
  cross-platform exchange, release build or physical-device tests ran for this plan.

## 1. Restore the shared save and catalog contract

Implement this before exposing Conditions in the UI.

- Read schemas 1–11. Use separate concepts for the highest readable version and
  the version a particular character needs when written: **11 if active
  Conditions or Condition history exist, otherwise 10**. A resolved last Condition
  still leaves schema-11 history. Never write an empty `conditions` key.
- Model each Condition's UUID, catalog/custom source, note, counter and Foundation
  date. Write the custom effect, resolution, Beat and persistent fields only for
  custom Conditions. Follow Swift's defaults and preserve date precision and IDs.
- Extend history with the `condition` trait kind, optional event and Beat amount.
  Preserve the `condition:<catalog-id-or-custom>/<UUID>` keys and the four event
  names. Keep ordinary history JSON unchanged when those optional fields are absent.
- Preserve the existing transfer guarantees: byte-for-byte export/new-ID import/
  Replace, Keep Both changing only ID/name, unchanged files retaining dates and
  bytes, and conflict comparison including all meaningful Condition state/history.
  Unsupported schema 12 must be refused without writing anything.
- Add Conditions to catalog indexing and shared catalog-ID comparisons on both
  sides. Parse defaults and skip unknown effect targets as Swift does. Update the
  expected book set to five without weakening equality/order comparisons.
- Add `v11-conditions` to Kotlin's current-file and bidirectional exchange cases;
  change the active future-rejection tests to `v12-future`. Retain historical
  fixtures, including `v11-future`, and update their documentation rather than
  deleting them. Cover both normal schema-10 output and schema-11 history-only output.

Primary files: `CharacterSave.kt`, `CharacterCodec.kt`, `CharacterDocument.kt`,
`Catalog.kt`, `BookEntries.kt`, Kotlin save/storage/transfer tests and
`RequiemCharacterSheetTests/SaveContractTests.swift`. Shared fixtures should use
the existing Swift definitions, not an Android-specific schema.

**Done when:** v10 and v11 files round-trip in both directions with all state
preserved; old unchanged saves are untouched; schema 12 is safely rejected;
catalog IDs agree and the existing contract checks are green.

## 2. Implement Conditions as a complete feature

Keep Condition mutations in the rules/edit layer so UI callbacks cannot separately
change Beats, history and the active list. Use the Swift `ConditionTests` as the
behavioral reference and add equivalent meaningful Kotlin cases.

- Add logs `added`; counter Conditions start at 1. Prevent duplicate catalog
  Conditions unless `repeatable` permits them; custom Conditions remain supported.
- End removes a Condition without a Beat. Resolve removes it and normally grants
  one Beat, with the catalog exceptions such as Distracted and Stumbled. Take Beat
  keeps it. Reuse the existing five-Beats-to-one-Experience rollover.
- These events always cost zero XP and never enter paid-dot purchases/refunds or
  the ordinary trait snapshot. Show Added/Ended/Resolved/Beat and the earned Beats
  in Change Log rather than misleading numeric dot changes or XP costs.
- History names follow the active Condition's current note/counter, then its last
  recorded name after removal. Recently Used is the newest five distinct known
  catalog IDs from added events; exclude custom and unknown entries.
- Add Conditions as the **last sheet section**. Use a native horizontal pager of
  equal-height compact cards, clear page/count cues and a tap-to-open full card.
  Keep vertical sheet scrolling comfortable around horizontal gestures.
- Full cards show the red title band, Persistent tag, note, optional penalty
  counter, effect, resolution, Beat action, possible sources and citation, with
  End and Resolve actions. Custom cards expose editable name/effect/resolution/
  Beat/persistent fields. Honor catalog flags when showing controls.
- The add picker groups Recently Used, then books in catalog order, then Custom;
  selecting a Condition adds it once and opens its full card.
- Add the small red `c` indicator to affected Attributes, Skills, category headings
  and Defense. Tapping shows the relevant effects and opens their cards. These are
  **informational effects, matching iOS**, not invented automatic changes to base
  ratings or situational dice pools. Ignore unknown targets gracefully.

Primary files: new `Conditions.kt` rules and Condition UI components, plus
`SheetEdits.kt`, `SheetModel.kt`, `SheetEditor.kt`, `ChangeLogSheet.kt`,
`SkillsEditor.kt`, `CreationEditor.kt`, `TrackerEditors.kt` and shared row controls.
Host card/picker state above disposable lazy rows, keyed by stable Condition IDs.

**Done when:** add/edit/end/resolve/Beat flows survive save, reopen, rotation and
process recreation without lost edits or duplicated awards. Counters, repeatable
Conditions, custom cards, recents, effect links and history match Swift. Small
indicators have proper Android-sized touch targets and useful TalkBack labels.

## 3. Implement the new Merit and sourcebook rules

Treat bonus dots and Specialty dependencies as domain behavior, not just drawing.

- Area of Expertise uses a deduplicated, trimmed list of existing Specialties in
  Skill order, labelled with their Skills. Disable adding it with no Specialty.
  Save only the Specialty text as its qualifier. Leave ordinary/free-text qualifier
  behavior intact for other Merits.
- Renaming the last Specialty of a given name updates its dependent Merit
  qualifier. Deleting it or renaming it to empty removes dependent Merits. A
  same-name Specialty on another Skill keeps the original dependency valid.
  Refund purchased dots through the existing XP snapshot/paid-dot flow when
  appropriate; show dependencies in the edit prompt.
- Evaluate `notCovenant` and `willpower` using the current covenant and Resolve +
  Composure. Feed the existing prerequisite display/creation checks; do not turn
  every advisory requirement into a new blanket prohibition.
- Implement the generic `merit` effect. For Flock, each purchased Flock dot adds
  a Herd bonus dot. Display bonuses in black after purchased dots, up to ten
  visible dots, and include the effect in details. Do not store bonuses as bought
  Herd dots or charge/refund XP when a derived bonus changes.
- Exclude Zirnitra/Ziva (`coilOnly`) from choosing a Mystery, while offering them
  as Coils and retaining their Scale groups. Their ordinary non-Mystery price is
  4 XP per dot. Keep existing Mystery pricing, Status warnings and paid-dot history.
- Group Add Coil by book. Let picker searches match book names as well as entry
  names/descriptions; show source citations on every option. Check the sourcebook's
  fighting-style maneuvers and ritual targets, sacraments and contests in details.
- Preserve the user's deliberately advisory text requirements: rating-relative
  Carthian Status, Stigmata's Humanity rule, Inter-City Contacts, rating-relative
  Safe Place/Herd and Mortal only. Do not invent enforcement not present on iOS.

Primary files: `Prerequisites.kt`, `CharacterVitals.kt`, `SorceryRules.kt`,
`ExperienceRules.kt`, `SheetEntries.kt`, `SheetEdits.kt`, `BookEntries.kt`,
`BookDetails.kt`, `SheetDialogs.kt`, `EntryRows.kt` and `CatalogScreens.kt`, with
focused Specialty/Merit/sorcery tests and shared examples where they improve parity.

**Done when:** Flock/Herd bonuses are correct without extra XP transactions; paid
Area of Expertise is refunded once when its last dependency is removed; duplicate
Specialties behave correctly; both new prerequisite kinds work; standalone Coils
are selectable only in the appropriate chooser and have the correct price.

## 4. Complete navigation, identity and library parity

- Implement the red Cinzel current-section pill and highlighted section chooser.
  Derive the active section from visible lazy-list items; retain a chosen section
  until actual user scrolling resumes. Map all Skills groups consistently, handle
  optional Creation/Ritual/Coil sections, and include Conditions last.
- Ensure section jumps land on their headings. Use stable keys/section-start
  items where needed rather than relying on an oversized item's internal offset.
  The pill must accommodate long names and enlarged text without hiding Save/Back.
- Add the home-screen Export Character chooser and route it through the already
  validated library export flow. Retain long-press/overflow export and Save to file;
  handle no readable characters and cancellation without opening or changing a save.
- Make the left labels for Mask, Dirge, Clan, Bloodline and Covenant show the chosen
  known entry's details, falling back to the chooser for custom/empty values.
  Include archetype Single/All Willpower actions, clan/bloodline Disciplines and
  banes, favored Attributes, parent clans and covenant summaries where applicable.
- Extend the existing Mask/Dirge search to explicit Custom choices and source-aware
  presentation. Preserve their string save representation and existing custom text.
- Verify compact dot counts at BP 1, 5, 6 and 10, bonus extensions, legal menus,
  Health alignment and splash behavior. Match the short fade within roughly five
  seconds if needed, preserving early dismissal and the rotation-safe deadline.
- Audit identity/Specialty dialogs when their originating row leaves composition;
  hoist state if needed. Do not port SwiftUI hosting workarounds or iOS glass effects.

Primary files: `MainActivity.kt`, `SheetEditor.kt`, `SheetControls.kt`,
`IdentityPicker.kt`, `CharacterDetails.kt`, `SkillsEditor.kt`, `DarkPackSplash.kt`
and the presentation models in `Bloodlines.kt`/`BookDetails.kt`.

**Done when:** section tracking/jumping remains stable during scrolling, editing,
keyboard display and rotation; new export and details flows use native Android
controls and keep the previously accepted editing behavior.

## 5. Validate the integrated beta on both platforms

Run checks appropriate to each milestone, then one complete integration pass:

1. Swift host tests and `scripts/check-save-contract`, including catalog IDs and
   real Swift → Kotlin → Swift v10/v11 exports and Condition histories.
2. Kotlin rules/storage/import tests, debug/release lint and builds; preserve the
   existing unsigned CI release option and GitHub iOS UI-test exclusion.
3. Android 16 emulator interaction tests for cards/pickers, event actions, menu
   navigation, dependent-Merit refunds, import conflicts and state restoration.
4. Check portrait/landscape, enlarged text, keyboard visibility, long notes/names,
   card-height consistency, horizontal/vertical gesture coexistence and TalkBack.
5. Upgrade beta 1 in place using the matching distribution signature; preserve
   existing v10 characters, creation progress, trackers, XP and paid dots. Verify
   both directions of file exchange with the new iOS build on actual devices.
6. User acceptance on the **Samsung S24 FE running Android 17**, especially
   Conditions, Flock, Area of Expertise, section jumps and import/export.

Schema-11 characters require the newer app. A beta-1 reader should continue to
refuse them safely; ordinary v10 characters should remain usable there. Backups
before upgrade remain useful, but no destructive migration is planned.

## 6. Package and distribute beta 2

Target version name **1.0.0-beta.2**, with the next unused version code above 9
(expected **10**, verify against Play Console before packaging). Keep package
`ie.requiem.sheet`, Android 16 minimum, the current upload key and Play App Signing.

Produce the signed AAB only after the integration checks pass. Verify signature,
version/SDK values and merged permissions, archive checksums and release notes,
and exercise an actual Play-delivered update. Refresh the affected beta-1 store
screenshots after the UI is accepted. No new fonts or generated illustration are
needed for the port itself.

The previously tracked privacy-link/policy, explicit backup rules, 16 KB runtime
validation and Play-delivered install/update tasks remain release-preparation work;
the iOS changes do not resolve them. Revisit declarations if dependencies or data
flows change. The current Advertising ID finding remains No for beta 1; verify the
final beta-2 artifact rather than assuming an older audit covers a new build.

## Source control and handoff

This plan is a documentation-only branch/PR from `e8ab6ba`. Existing PR #5 (store
assets) and PR #6 (Advertising ID audit) remain separate; neither is a prerequisite
for the schema/rules work. Preserve their handoff entries when those PRs merge.

Implement the milestones on short-lived Android branches into `main`, recording
each implementation commit and validation in the append-only handoff. Keep early
model/codec changes together with their matching tests so intermediate PRs have
green contracts. Resync and read Claude's new entries before each milestone;
shared schemas/catalogs may keep moving while iOS work continues.

No clarification is currently required to begin milestone 1. The code and handoff
define the expected behavior; flag any later discrepancy against the Swift tests
before making an incompatible Android-only rule.
