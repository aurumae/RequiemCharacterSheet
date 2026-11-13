# Android parity with current iOS

Status: proposed, 13 November 2026. This is a plan, not completed implementation.
The baseline is `origin/main` at `0bc7a66` (iOS 1.5), including iOS 1.4 at
`340b690`. Visual references are all ten PNGs in the user's local
`iOS App Screenshots/1.4 Screenshots/` directory. They were inspected individually.
The screenshots guide presentation; the handoff, design decisions and Swift code
define behavior that screenshots cannot establish.

## Starting point and scope

Android on main is behind Android's open [PR #7](https://github.com/aurumae/RequiemCharacterSheet/pull/7).
Reuse that work: `2012ff6` implements Conditions/schema 11 and sourcebook rules;
`53e6e35` implements the native screens; `b5fb3fb` records validation. The working
checkout has integrated current main as `beca2dd`. PR #7's published head is still
`b5fb3fb`, and its old passing checks do not validate the integrated tree.

Already implemented on that branch: Conditions and history, compact/full cards,
effect indicators, recent choices, section navigation, library Export Character,
identity details, Area of Expertise/Specialty dependencies, Flock/Herd bonuses,
standalone Coils, and conditional schema 10/11 writing. Verify and extend these;
do not implement them again. Preserve import/export, paid-dot history and custom
entries. Existing physical beta-2 acceptance remains unconfirmed in the handoff.

The functional target is all current Requiem behavior plus the two iOS 1.5
accessibility fixes. The shared-core extraction is a separate final milestone
with its own behavior-preservation checks. Forsaken screens/rules, Play rollout,
PDF export, Tilts and invented automation for text-only rules are outside this plan.
Android stays native Compose, with Android 16/API 36 minimum and 48dp touch targets.
See [design decisions](design-decisions.md) and [multi-game plan](multi-game-plan.md).

## 1. Establish the integration and test baseline

- Continue from the existing beta-2 implementation plus current main. Refresh PR #7
  and its description around the final scope, or use dependent feature PRs with an
  explicit base; do not merge stale beta-2 code just to acquire its earlier green checks.
- Correct the two catalog-test assumptions identified in the diagnostic handoff:
  derive the complete expected book inventory independently from the bundled source
  files, and select Morbus by ID before checking its warning. Keep exact inventory,
  ordering, core precedence and missing-resource checks. Small synthetic catalogs
  should test name resolution and precedence independently of the growing real catalog.
- Run the integrated rules/storage suites and save exchange, recording actual
  results. Classify each failure as a regression, an unported behavior, or a stale
  test. No new local test results were obtained during this planning task.
- Build the CI contract changes described in [the CI plan](ios-first-ci-plan.md)
  early, so staged ports can be reviewed without claiming complete parity.

Completion: a reproducible baseline and an explicit list of pending capabilities;
no test removed simply to make an existing supported feature pass.

## 2. Schema 12 and elder banes first

Relevant files: `CharacterSave.kt`, `CharacterCodec.kt`, `CharacterDocument.kt`,
`Catalog.kt`, `SorceryRules.kt`, `SheetEdits.kt`, `TrackerEditors.kt`, Kotlin
save/storage/import tests and Swift `SaveContractTests.swift`.

- Index `elderBanes` and implement the five clan-linked entries. Kotlin currently
  omits that catalog category entirely.
- Read schemas 1–12. Write 12 only while `elderBaneActive` is true; otherwise write
  11 for active Conditions or Condition history, and 10 otherwise. Omit the elder
  key when false. An absent key means false, even at low Humanity.
- Activate when Humanity crosses from above the threshold to at/below it; keep it
  active if Humanity rises; support the player's toggle. Changing clan resets the
  state according to the new clan's elder bane and threshold. Port the exact Swift
  edit/decoding distinctions, including unrelated clan/bloodline bane behavior.
- Show `Elder Bane: <name>` below the clan bane, with its In effect toggle, status
  explanation, summary and source citation. It does not consume a custom bane slot.
- Exchange `v12-elder-bane` through real stores in both directions; use v13 as the
  active future rejection case. Keep all historical fixtures. Test combinations of
  Conditions/history/elder state and turning an elder bane back off.
- Preserve byte-identical untouched imports/exports and Replace; Keep Both changes
  only ID/name. Unsupported future files must remain untouched and unavailable for
  editing. Test duplicate detection, timestamps, UUID casing, XP history and tracks.

Completion: complete, lossless v10/v11/v12 exchange and safe v13 rejection, plus
elder-bane transitions matching Swift. Merely increasing the schema constant is
insufficient.

## 3. Port the new sourcebook mechanics

All eight JSON catalogs already enter Android's generated resource index. Loading
the files is not proof that their new fields affect rules correctly. Current raw
inventory: 15 clans, 12 bloodlines, 16 covenants, 20 Disciplines, 83 Conditions and
5 elder banes. These are audit observations, not new fixed-count test assertions.

| Area | Necessary work and acceptance cases |
| --- | --- |
| Quintessence | Honor `partOfMystery`: it belongs to the Voivode for 3-XP Coil pricing and exemption from the outside-Mystery Status cap; otherwise it costs 4. Preserve old paid-dot refunds. |
| Covenant Status | Add `fromCovenants` choices from the full catalog, with the existing options as fallback. Match `statusCountsAs` everywhere Swift does, including Legion of the Green/Invictus and Circles of Mor/Circle of the Crone. Use the character's applicable covenant name in requirement text. |
| Covenant Merit access | Evaluate `meritGroups` by group or individual Merit ID, replacing only the specified covenant requirement. Gallows Post can take Carthian Laws, not every Carthian Merit; Fir'awn can meet the specified Altar requirement. |
| Clan/bloodline access | Honor `meritAccess` for Dukhan and Icelus, and evaluate `Prerequisite.kind == bloodline`. Keep unrelated prerequisites intact and the existing distinction between creation limits and play-time warnings. |
| Bloodline creation | Bron favored Attributes replace the clan's free-dot choices during guided creation. Changing/removing the bloodline removes a now-invalid bonus and prompts again; adopting it after creation never moves existing dots. Name the Bron in the panel, prompt and Attribute note. |
| Bloodline identity | Empty `parentClans` means any clan for grouping and details. Show required covenant and warn, without blocking selection; accept appropriate `statusCountsAs` membership. Show combined clan/bloodline favored Attributes with their sources. |
| Ritual teaching | Honor `teaches` and historical covenant aliases when evaluating and describing who teaches each Discipline. Cover Kimiya/Jaliniyya, Ahl al-Mumit/Theban, Fir'awn/Crúac and Tenth Choir/Therion. |
| Membership-only sorcery | A minimum Status of zero still requires the named covenant membership. Current Kotlin's numeric comparison lets everyone through this case. Cover Belial's Brood/Triadic Evolution, including guided-creation messages with the complete requirement. |
| Humanity rules | Generic JSON already accepts `none` and `breakingPointAtSixMinusDots`; implement the correct detail text and relevant Swift behavior. Kimiya adds no Humanity constraint; Therion describes its breaking-point rule. Do not invent automatic Humanity loss. |
| Scales | Implement `anyCoil` eligibility/cost and prerequisite wording; show the Any Mystery subgroup for Amara's Scales. Keep ordinary prerequisite-Coil behavior. |
| Free Devotions | Verify Infectious Bite and City Attunement cost zero and never generate a refund profit. Catalog XP costs already flow into the ledger as integers; audit before changing code. Custom Devotion costs currently have their own 1–20 policy and should follow Swift's separate behavior. |
| New data coverage | Check every book's names, citations, IDs, rules text and display. The source data already removes Al-Hamasoun in favor of Ahl al-Mumit; preserve unknown saved IDs rather than inventing a migration. Keep Leveraged and Leveraged (ghoul) distinct. |

Primary files: `SorceryRules.kt`, `Prerequisites.kt`, `CreationRules.kt`,
`ExperienceRules.kt`, `SheetEdits.kt`, `BookEntries.kt`, `BookDetails.kt`,
`Bloodlines.kt`, `SpecialtyRules.kt`, `SheetDialogs.kt` and `CreationEditor.kt`.
Use the corresponding Swift unit tests as behavioral references; add shared action
fixtures where they establish rules parity rather than merely echoing the code.

Keep the handoff's deliberately text-only rules as text: elder status, Amari
conservation/rationing, Bekaak ageing, Nhang physiology, Twice-Cursed prices/free
Merits, Vardyvle desires, Claiming and favored disease. Preserve unknown prerequisite
and Merit category names without crashing or treating unknown requirements as met.

Completion: positive and negative cases for each rule above, stable historical
purchase costs, and creation/ordinary-play agreement across platforms.

## 4. Group every official chooser by book

Android currently groups most lists by category or ownership across books; only
some screens (Conditions/Add Coil) already use books. Introduce a shared section
model used by `CatalogScreens.kt`, `IdentityPicker.kt` and `ConditionEditors.kt`.

- Requiem core first, then the same catalog-file order as Swift. Use book headings
  and smaller nested group headings. Keep every entry's book/page citation.
- Cover Masks/Dirges, Clans, Bloodlines, Covenants, Disciplines, Devotions, Merits,
  Banes, rituals, Mystery selection, Add Coil, Scales and Conditions.
- Within books retain own-clan bloodlines, learnable Devotions, Merit categories,
  ritual Disciplines and Scale Mysteries. Follow the handoff's empty-group rule
  consistently across all books. Alphabetize Mask/Dirge choices within their books.
- Disciplines first show an In-clan section spanning books. Then list every
  Discipline again under its book, including the in-clan entries. Repeated rows need
  section-plus-entry keys so Compose does not receive duplicate lazy-list keys.
- Search retains book sections and relevance order within each. Recently Used
  Conditions and Custom choices remain outside the book sections. No book toggles,
  exclusions or filters; the standing product decision is unchanged.
- Match the larger Merit dots and `● to ●●●` range wording, with spoken dot counts.
  Disable Add/Done for blank required free-text qualifiers, including whitespace;
  enforce validity in the edit layer as well as the dialog.

Completion: every chooser, including searches, empty groups and long headings,
follows the documented grouping; duplicate Discipline appearances remain selectable
and accessible.

## 5. Screenshot and accessibility acceptance

Reuse existing border/logo/fonts and red/white/grey theme. Match information order,
hierarchy, spacing and interaction while retaining native Android navigation,
system pickers, keyboard behavior and accessible controls.

| Reference inspected | Android acceptance work |
| --- | --- |
| `01-characters.png` | Keep library New/Import/Export actions and About. Add lineage such as `Ventrue (Bron) · Lancea et Sanctum`; current storage summary omits bloodline. Refresh relative Edited times each minute while visible, including TalkBack and resume behavior. |
| `02-sheet.png` | Verify identity rows, label/detail actions, logo/header, XP badge and Save at normal and large text. Long names and the Bron fit without obscuring controls. |
| `03-section-pill.png` | Retain the working current-section pill/jump behavior. Match selected-row emphasis as well as the checkmark; cover dynamic Creation/Ritual/Coil sections and Conditions last. |
| `04-attributes-skills.png` | The visible reference shows Skills: right-aligned legal dots, Specialties, category labels and unskilled penalty. Verify the same visual system for Attributes and Condition indicators in additional captures; they are not visible in this reference. |
| `05-disciplines-merits.png` | Verify long Merit labels, Clan/Bloodline Disciplines, Add actions, empty Devotions and section bands; keep paid and derived bonus dots distinct. |
| `06-discipline-picker.png` | Match the Bron's cross-book In-clan section, the repeated complete book lists, summaries and citations. Use Android-native search and dismissal. |
| `07-merit-picker.png` | Match book headings, nested categories, larger rating dots, warnings and search behavior. |
| `08-conditions.png` | Equal-height compact cards with next-card preview, shortened text and tap hint. Verify removal of first/middle/last card keeps a valid current index. Show swipe-for-more only when a later card exists; current Kotlin shows it on every page of a multi-card list. |
| `09-condition-card.png` | Full red-band card, editable note, effect, Resolution, Beat, possible sources, citation and End/Resolve actions. Confirm `Beat: n/a` can coexist with Resolve awarding a Beat, as pictured. Verify custom/persistent/counter variants too. |
| `10-experience.png` | This is the Change Log: totals, date sections, time, purchased/free changes, Condition names/notes and event labels. Preserve creation and XP-off explanations. |

Use singular `1 Experience` in XP badge TalkBack output; Kotlin currently hardcodes
the plural there. Test 0/1/many/negative amounts. Verify the carousel after deletion
rather than assuming a pager API gives the desired visible-card behavior.

Screenshots cannot prove saving, gesture behavior, unseen states or accessibility.
Capture matching Android states on an emulator, normal and 150% text, portrait and
landscape; inspect all ten comparisons. Test focus, keyboard dismissal, rotation,
modal recreation and TalkBack traversal. Keep images local unless publication is
separately requested; the existing source assets remain authoritative.

## 6. Functional parity acceptance and independent release

Run JVM rules and storage/import tests, full Swift/Kotlin file exchange, debug and
unsigned release builds/lint, and focused plus full Android UI regression coverage.
The exchange must include genuine Swift and Kotlin store outputs, not only static
fixtures. Preserve the GitHub iOS UI-test skip; iOS UI coverage stays local/Xcode Cloud.

Validate an in-place Android upgrade without uninstalling, using ordinary, guided,
Conditions and elder-bane characters. Verify data, dates, paid dots and unchanged
exports. Then perform real iOS/Android exchange and S24 FE acceptance with the new
features. Earlier beta-2 checks do not substitute for this validation.

Recheck Play's next unused version code before packaging; do not assume 10 remains
available. Keep signing, Play delivery, privacy/backup and 16 KB runtime checks
tracked as release readiness tasks. No upload or rollout is part of this planning
request. The app remains free.

Completion: all declared supported contracts pass, all pending Requiem parity items
above are resolved, and device acceptance is recorded before claiming full parity.

## 7. Mirror the shared-core extraction separately

Answer to the 12 November handoff question: recommend the same compiled Kotlin
boundary and eventual `:core`, `:requiem`, `:forsaken` layout. Do this after functional
parity so extraction regressions can be distinguished from rule changes.

For Phase 1, extract game-neutral data/catalog primitives, traits, tracks, log
strings and the genuinely generic rules into a JVM `:core` with no Vampire or
Android dependency. Move remaining `:rules` behavior into `:requiem`; retain `:app`
as the existing Requiem app initially. Keep reusable Compose components in a
separate Android UI module or package, outside the JVM core. Inject catalog and app
identity rather than reading Requiem globals from shared code. Audit actual iOS
Phase 1 scope: it deliberately leaves much Conditions/XP/prerequisite logic in
Requiem until Forsaken exists; do not prematurely generalize those engines.

Do not add a game field, rename package/storage paths, relocate authoritative
catalogs/fonts/fixtures, or create empty Forsaken modules in Phase 1. Preserve the
existing Requiem saved JSON and file extension. Update Gradle task references in
the scripts/workflow when modules move. Verify core compiles independently, all
contracts remain unchanged and existing saves are byte-identical on untouched
paths; release the extraction separately before any Forsaken screens.

## Implementation sequence

Use reviewable milestones: (1) integration baseline and CI contract policy,
(2) schema/elder banes, (3) covenant/ritual/Coil rules, (4) bloodline/Merit/Scale
rules, (5) all-picker grouping and screenshot/a11y refinements, (6) full functional
acceptance, (7) behavior-preserving core extraction and its own acceptance.
Append a handoff with concrete validation and remaining work at each milestone.
