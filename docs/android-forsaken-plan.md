# Android Forsaken port plan

Status: **approved by the user, 17 November 2026; implementation may proceed in this order**.
Reference: iOS Forsaken 1.0 submitted on 17 November, repository `17f8db8`, and the
[submission handoff](handoff.md#2026-11-17-1305-utc--claude-ios--forsaken-10-is-submitted-androids-forsaken-can-start).
This replaces the old ordering that put Requiem's Play acceptance ahead of Forsaken.
Requiem and Forsaken release independently.

## What is already built

iOS has the complete first-release Forsaken sheet, guided creation, eight Forsaken
catalog files plus the shared CofD core catalog, and schema-1 `.wtfcharacter` saves.
The five model files, three view files, shared `Chronicles/Core` and `Chronicles/UI`,
74 Forsaken rules tests and `SaveFormatTests.swift` are the implementation reference.
The two fixtures exercise every top-level save key. The newer handoff entries and
[design decisions](design-decisions.md) supersede earlier sketches and book conflicts.
Schema 1 is frozen for the submitted build; changes to that format require schema 2
coordinated with iOS. Raise apparent catalog, fixture or behavior mistakes
as **Question:** in the handoff; do not change them or add Android workarounds.

Android has JVM `:core` and `:requiem`, with the Requiem Compose app in `:app`.
Beta 3 is version code 11 and its release acceptance is unfinished. Requiem now
uses the shared Compose controls in `:sheet-ui`.
The JVM core now owns shared prerequisites, Condition events, XP recording and
file storage. Requiem supplies its codec, rules and library summary.
Phase 2 adds JVM `:forsaken` and the separate `:forsakenApp`, a read-only viewer
with all nine catalog sources and schema-1 saved fields. It imports and exports
unchanged bytes. The canonical writer and werewolf calculations remain phase 3.

The save contract currently covers **Requiem only**. A green supported-mode run
does not certify Forsaken parity. Pushes and schedules allow declared pending ports;
manual strict mode claims full declared parity. Both iOS app schemes run in CI.
The previously reported CI failures have subsequent fixes; this plan does not use
the 13 November failure log as evidence of the present state.

## Module layout

| Module | Responsibility |
| --- | --- |
| `:core` (JVM) | Existing shared models, trait definitions and catalog indexing; common prerequisite checks, Condition operations, XP snapshot/ledger engine, search folding and track helpers. Generic document/storage operations where they need no Android APIs. |
| `:requiem` (JVM) | Requiem catalog assembly, character/codec and schema migrations, vampire traits, costs/refund policy, creation and rule-specific prerequisite hooks. |
| `:forsaken` (new JVM module) | Forsaken schema-1 model/codec, catalog assembly and all werewolf rules, creation, costs and per-game edit operations. No dependency on `:requiem`. |
| `:sheet-ui` (Android library) | Compose controls/theme, library and sheet frame, common section editors, picker/search, navigation, lifecycle saving, and Android file/share integration. Depends on `:core`; games supply adapters. |
| `:app` | Existing Requiem application, package `ie.requiem.sheet`, existing storage and release lineage; injects Requiem rules, identity and resources. |
| `:forsakenApp` (new application) | Separate installable Forsaken app, private library, `.wtfcharacter` import/export, identity, resources and signing/version configuration. Depends on `:forsaken` and `:sheet-ui`. |

Extract the common portions of `Prerequisites.kt`, `Conditions.kt`,
`ExperienceRules.kt`, `SpecialtyRules.kt`, `CharacterDocument.kt` and
`CharacterFiles.kt` in small steps, with Requiem regression coverage at each step.
Keep manifest-named Requiem tests and their names through extraction; adapt their
internals and add core tests without dropping existing evidence requirements.
Keep game-specific parts behind explicit adapters. The shared ledger takes the
game's snapshot, kind ordering, per-level cost and refund policy: Requiem's Humanity
and Blood Potency restrictions remain its own. Forsaken supplies its Renown,
Moon Gift, Facet, rite and Primal Urge keys and historical purchase costs.

Keep Kotlin's immutable edit pipeline. Implement Swift view side effects as explicit
domain edit operations, including creation grants on identity changes, totem Merit
row synchronization and wound folding when Health shrinks. Recomposition or merely
opening a file must not repeat purchases, grant dots or award Beats.

Retain Android's atomic writes, stale-write protection, pending-import recovery,
duplicate choices and raw export behavior. The generic store receives a game/schema
probe, codec and summary factory; Android URI handling stays in `:sheet-ui`.
Do not move a Requiem codec into core or make a single saved character with both
games' fields. App-private stores and sharing authorities must remain separate.

The Health-fold helper belongs in `:core`, with Forsaken opting in. Do not silently
enable werewolf wound folding for Requiem: its current iOS behavior does not call it.
Likewise, extract common calculations with game hooks for Willpower and bonuses;
do not impose Requiem's rating clamps on Forsaken's saved or effective ratings.

## Build order and installable milestones

Each phase can use several small PRs. Each PR includes a handoff and passes its
selected CI jobs before merging. Phase numbers are dependency order, not dates.

**Phase 0 implementation (17 November):** Requiem checks game identity before
migration/import/open, preserves unchanged exports, and still omits `game` on
canonical writes. Rule-engine tests now use fixed synthetic inputs; the general
advisory fallback has named evidence in [the CI policy](ci-contract-policy.md).
The phase-0 handoff records validation and publishing status. No Forsaken fixtures
have moved and no Forsaken module is built in this phase.

**Phase 1 implementation (17 November).** Requiem uses the shared library, sheet
frame, editing rows, catalog picker and store. The skull stays fixed as the list
scrolls or the keyboard covers its lower portion. The section menu opens at the
current section, and XP and Save keep their space at large text sizes. Core rules
accept per-game costs, refunds and Willpower bonuses. Health folding is available
for Forsaken. Requiem keeps its existing visible-track behavior. The phase 1
candidate is the Requiem app. Physical-device TalkBack and keyboard acceptance
remain on the device checklist.

**Phase 2 implementation (18 November).** Forsaken Preview installs beside Requiem
as `com.omccolgan.ForsakenCharacterSheet`, version `0.1.0-preview.1` (code 1).
Its library, sheet, catalog browser and details use the submitted assets and fonts.
Saved ratings, creation choices, active flags, free Facets and purchase history are
inspectable. Effective ratings, derived capacities, XP balances and editing are
explicitly unavailable. Opening a creation save does not apply or alter grants.
Both original fixtures remain in place and unchanged. Both games reject foreign
files at their actual activity and store boundaries. Keep Both changes only ID/name.
The workflow builds, tests, lints and packages both apps but the contract/exchange
still covers Requiem only. See [viewer validation](android-forsaken-viewer.md).

**Phase 3 Android implementation (18 November).** The ordinary-play candidate
`0.2.0-preview.1` (code 2) adds canonical schema-1 writing, blank sheets, calculated
werewolf traits, Gifts, Totem advantages, Conditions, purchase history and edits.
Guided saves remain read-only. See [ordinary-play validation](android-forsaken-ordinary-play.md).
The shared contract migration and first Forsaken Xcode exchange remain pending the
explicit coordination gate below; phase 3 is not fully complete until those land.

| Phase | Work and completion gate | What the user can install and test |
| --- | --- | --- |
| **0. Protect saves and stabilize tests** | Refuse foreign-game files in Requiem's real import/open boundary before any migration or write. Move rules-outcome tests onto synthetic catalogs, retaining live checks for declared contracts. Add the general tested `advisory-text` fallback and review the Gallows Post test change. | A Requiem candidate that accepts existing files and refuses Forsaken/unknown games without changing the library. Forsaken implementation has not started in this phase. |
| **1. Shared rules, storage and interface** | Extract the modules/adapters above. Add watermark, search folding, toolbar/menu layout, counted dots and unique row identities. Add catalog metadata/note-choice support and check splash/accessibility follow-ups. Existing Requiem exchange and storage tests must still pass. | A Requiem candidate with the shared UI improvements; exercise keyboard reveal, scrolling, search, large text, TalkBack, import/Keep Both and restart recovery. |
| **2. Forsaken foundation and viewer** | Add `:forsaken` and `:forsakenApp`; load all nine catalog sources and all schema-1 fields. Build the themed library, section frame and catalog details. Read the original fixtures in place. Complete decoding and raw transfer tests; do not claim canonical writer/rules parity yet. | Both apps installed together. A clearly identified Forsaken preview can import, inspect and export a character unchanged. Imported saves remain read-only; unavailable calculations are not presented as correct. Test both game-refusal directions and file handling. |
| **3. Complete ordinary play and enroll the contract** | Finish canonical encoding and the interacting werewolf rules below, then enable ordinary-play editing. Match the play fixture's numbers and all non-creation rule outcomes. Coordinate the multi-game contract migration and first real exchange with Claude. Guided characters remain read-only until phase 4. | A usable Forsaken ordinary-play candidate: create a blank character, edit an iOS play save, shift forms, use Gifts/rites/totem/Conditions, buy and refund traits, restart and return the file to iOS. |
| **4. Guided creation and full rule parity** | Implement all seven steps, hard limits, grants and finish/leave semantics for Forsaken, Ghost Wolves and Pure. Add creation/action exchange cases; account for every reference rule test and clear pending capabilities only with executed evidence. | Create each of the three character types, resume creation across apps, change tribe/auspice/free Skill, finish with bonus XP and continue ordinary play. The submitted creation fixture remains intact. |
| **5. Acceptance and delivery** | Verify the complete UI, actual device exchange, accessibility, lifecycle recovery, upgrade/data retention and packaging; complete Forsaken's own listing/privacy/backup/signing decisions. Run strict exchange and both apps' required checks. | A signed Forsaken release candidate, then an internal Play build when the user authorizes upload. Requiem can release separately at any point once its own gates pass. |

The preview is a temporary milestone, not a reduced first release. Canonical encoding
depends on correct derived Health/Willpower lengths and active effects; therefore
phase 2 promises raw transfer, not a partially correct rewrite. Phase 3 enables
editing only after the entire schema is retained and its ordinary-play calculations
and mutations pass. Creation data can round-trip while its editing capability is
still explicitly pending.

### Phase 3 rules that must land together before ordinary-play acceptance

- All five forms and per-form Advantages, Primal Urge/Essence, Harmony/Touchstones,
  Kuruth, Spirit Rank, Pure Hunter's Aspect and the absence of effective auspice/Moon
  Gifts for Pure. Preserve stored values that are currently inactive.
- Totem budgets and advantages, zero-owned-dot granted Merit rows, granted
  Specialties, distinct-source over-limit allowances and faded uncounted dots.
  Exactly 20 pack points gives 5 Experiences. Existing overspent totems are retained.
- Passive/active Gift and rite effects, form restrictions, Favored Form choices,
  Instinctive Defense, armor and worked pools, including untrained penalties and
  Chance Die display where the reference applies them. Preserve text-only rules.
- Moon/Shadow/Wolf grouping, alternate/custom and additional Moon Gifts, affinity
  including era replacements, free Facet credits, saved active flags, and historical
  refunds. Display the same price that the purchase operation charges: first Shadow
  Facet 3 with affinity or 5 otherwise, further Facets 2, Wolf Facets 1, additional
  Moon Gift 5 then 2 per Facet. Apply the Renown and creation exceptions from Swift.
- Lodges, benefits and lore; outsiders pay triple for the taught Merits/rites, with
  the original price retained for refund. No invented tribe eligibility gate.
- Shared Conditions/Beats/XP history, Siskur-Dah's faction/lodge note groups,
  custom entries, merits and prerequisites, rites and fetishes with their details.
  Check the view-triggered behavior as well as model methods.

Phase 4 follows `ForsakenCreation.swift`: 5/4/3 Attributes, 11/7/4 Skills, three
Specialties, ten Merit dots, the free Skill/Renown/Totem/Language grants, and the
different Ghost Wolf and Pure allotments. Preserve partly completed priorities and
grant provenance. Invalid choices get the reference's explanation; incomplete but
legal creation can finish after the reminder, while rule-breaking creation cannot.
Finishing adds bonus Experiences and enables XP Mode; leaving keeps the character
without turning that into a paid purchase history.

## Proposal for the shared save and catalog contract

**Coordination gate:** agree this structure with Claude before moving fixtures or
changing policy, workflow, Xcode resources or iOS tests. None of those changes is
part of this planning PR. Phase 2 reads the fixtures at their existing paths.

### Registry and fixtures

Add a versioned `shared/save-contracts.json` registry keyed by game. Each entry
declares its manifest, fixture ownership, catalog contract/inputs, reader/writer
probes and evidence adapters. Keep Requiem's existing
`shared/fixtures/contracts.json`, fixture paths, capability IDs and
`shared/catalog-contract.json` intact. Add
`shared/fixtures/forsaken/contracts.json` and
`shared/forsaken-catalog-contract.json`. Qualify report/scenario/capability identities
by game so `save.base`, schema 1 or a repeated book ID cannot collide.

The current validator recursively assumes every JSON file in `shared/fixtures/`
is a Requiem scenario and hard-codes Requiem source paths. First make it registry
aware, prove that the old Requiem selection/protections are unchanged, then move the
two Forsaken fixtures **without changing their bytes** to
`shared/fixtures/forsaken/characters/`. Record their pre-move hashes, update iOS
bundle resources and test lookup in the same coordinated change, and verify both
suites read the same files. Add exact ownership checks: every fixture belongs to
one game; unknown or multiply classified files fail. Keep registry/manifest files
explicitly distinguished from scenarios. The migration must not offer a general
fixture-rewrite or regression-check bypass.

Enroll Forsaken in phase 3 once its canonical reader/writer and real-store tests
can honestly claim schema 1. Declare iOS's implemented capabilities, and Android's
remaining creation/UI capabilities as pending with owner and handoff. Distinguish
full-state preservation from behavioral parity: passing a codec round trip does
not prove creation is implemented. An unsafe editor must not be advertised as a
supported consumer merely because it decodes the schema.

### Required save coverage

- Retain `SaveFormatTests`' full JSON-object equality and every-key check, including
  conditional omission versus empty arrays, fractional Foundation dates, UUIDs,
  custom/catalog sources, active flags, unofficial content, grant provenance,
  free-Facet credits, Favored Form choices and the paid-dot ledger. Object equality
  is distinct from the byte equality required for untouched import/export.
- Port the play fixture's semantic assertions: Mara's Strength 7 in Dalu, 10 in
  Gauru and 5 in Hishu; 10 XP spent and 4 available; the intentionally overspent
  totem; custom and additional Moon Gifts; Conditions and history.
- Preserve the creation fixture and its incomplete state exactly. Resolve the
  reference questions below before defining edit/resume expectations.
- Add new, versioned action scenarios for ordinary play, each creation faction,
  grant changes, active effects/Health shrink, buying/refunding Gifts and lodge
  lore, free Facet consumption/removal, and Conditions/Specialties history.
  Use the same action plan and expected outcomes on both platforms.
- Exercise real stores: unchanged export, cancel/identical/replace/Keep Both,
  case-insensitive UUID identity, restart recovery and no-op saves. Keep Both changes
  only identity/name; other fields survive. Android's storage tests must use the
  same production storage path as the app's file handling.
- Test both games refusing the other and unknown games before mutation, plus a
  synthetic next-version Forsaken file. Missing `game` means Requiem; Forsaken
  requires `"game":"forsaken"`. Requiem canonical writes still omit `game`, while
  untouched imports retain their original bytes. File extensions do not establish
  which game's payload it is.

### Catalog contract

Use the eight existing Forsaken files plus only shared `cofd-core.json`; do not
copy/rewrite catalogs or mix both games' same-named Dark Eras files. Match Swift's
order: Werewolf core, CofD core, remaining filename stems, then unofficial sources;
the first duplicate ID wins within each entry kind. Official books remain visible.
Unofficial visibility is per character, off by default, and hiding it never deletes
owned material. Requiem gains no unofficial save key without a separate schema decision.

Classify every catalog field/type and semantic value, including nested Gift Facets,
effects and their form restrictions, prerequisite kinds, `replaces`, lodge lore,
Pure secondary Renown/skills/aspects, note-option groups, Tilts, book `official` and
`url`. Validate references within the appropriate game/catalog set, including
shared merits/conditions, and retain the existing anti-regression guarantees.
Additive books should not require a hard-coded book-count edit.

Outcome tests use small synthetic catalogs to establish mechanics. Live catalogs
are checked for the declared structural/semantic contract and reference integrity;
the immutable save fixtures retain their agreed semantic assertions. The general
advisory fallback test must exercise real decoding and presentation: an unknown
field/rule value does not crash or falsely enforce a rule, and its descriptive text
remains available. Cite it only where advisory behavior is actually safe; it is
not permission to omit an implemented Forsaken numeric rule.

### Bidirectional exchange and CI

Extend `scripts/check-save-contract` with game selection; preserve existing invocations
and make the normal default run all enrolled games. Retain the Requiem SwiftPM
producer → Kotlin/store → Swift consumer sequence and existing environment overrides.
Keep artifacts in separate per-game directories with the selected plan and reports.

Forsaken's current character model imports SwiftUI and its catalog uses `Bundle.main`;
it cannot simply be added to the host Swift package. Proposed first implementation:
Claude adds producer/consumer modes to the **existing Forsaken Xcode unit-test
target**, using production model/store code. A macOS driver runs the producer,
retrieves files from a known test-app container directory, runs Kotlin consumers
and producers, stages the Kotlin results back into that simulator container, and
runs the iOS consumer. Use a controlled simulator and explicit test-mode input;
Claude should confirm the container/test configuration before implementation.
No UI-test automation is needed for this exchange. A host-buildable Forsaken model
can be considered later as an agreed refactor, not assumed by this plan.

The driver must fail on a missing producer, missing consumed scenario, failed
test or absent report. Add an evidence adapter for Forsaken's Xcode test results
alongside SwiftPM/JUnit evidence, checking that named tests really ran and passed.
Do not replace actual export exchange with two tests that merely read the same fixture.

Add `:forsaken:test`, the second app's storage tests, lint, debug APK and unsigned
release packaging to Android CI. Keep Requiem tasks and both iOS app suites.
Put the simulator-based Forsaken exchange on a runner with the required Xcode/iOS
runtime; do not assume the existing macOS-15 host-exchange runner suffices. The
aggregate `CI result` must depend on it, whether implemented as a separate job or
an explicitly selected part of the iOS job. Extend routing and aggregation tests
in the same PR; initially run all affected jobs for shared/Forsaken contract inputs.
Preserve `-skip-testing:RequiemCharacterSheetUITests`.

Main pushes and schedules remain supported-mode; manual strict remains strict.
Pending work is reported and tested as pending, not turned into red main. Run policy
unit tests against synthetic pending manifests, never assert live strict parity.
Retain PR-base protection for fixtures, capabilities, catalog classifications,
reader limits, writers and test references. The two startup/post-push CI rules in
AGENTS apply throughout; a red main is diagnosed before starting new work.

## Requiem follow-ups and scope

| Follow-up | Disposition |
| --- | --- |
| Other-game refusal | Phase 0, before sharing storage or distributing Forsaken. Cover actual import and library open, not only a codec helper. |
| CI rules in AGENTS; PR #9 handoff | Housekeeping with this planning task. The old handoff's release-first priority is historical; the 17 November instruction supersedes it. |
| Synthetic outcome tests; general advisory fallback | Phase 0. Claude's Carthian Pull positive/Attaché negative test correction matches the broadened Gallows Post rule. Verify Status 2 permits Jack-Booted Thug as requested, then keep mechanics isolated from live catalog corrections. |
| Watermark and keyboard; quote-folding search; toolbar/menu; counted dots; unique row IDs | Phase 1 in the shared interface, used by both apps. XP remains readable, the section pill ellipsizes, the bounded menu opens at the current section, and keyboard reveal targets the actual row. |
| Splash tap-through; accessibility | Phase 1: check/block taps until splash dismissal; verify singular “1 Experience” and refreshing library edited-time text/semantics. Confirm existing coverage before adding redundant fixes. Full TalkBack traversal remains a device acceptance task. |
| `Book.official`/`url`, `ConditionEntry.noteOptions`, unknown effects, nine CofD merits | Phase 1 common parsing/presentation; phase 2 Forsaken catalog tests; phase 3 Forsaken numeric effects. Requiem skips unknown effects safely and retains descriptions; first-wins reprint precedence is preserved. |
| Remaining Requiem 1.5 parity | Finish alongside shared work where it overlaps; otherwise after Forsaken's functional port. Record gaps explicitly rather than treating current declared schema parity as UI parity. |
| Requiem Play/device release gates | Separate track: S24 FE acceptance, real-device iOS exchange, TalkBack, Play-delivered upgrade, 16 KB runtime, explicit backup/device transfer, privacy link/wording, Data safety and listing/account evidence. None blocks Forsaken development. |

Forsaken's theme uses Werewolf Rust `#855A4A`, Comforter labels/subheadings, Grechen
Fuemen trait names and picker headings, and system text where the reference uses it.
No Requiem page border. Use the supplied icon/logo/skull and the sheet-only fixed
7% watermark; it stays centered in the full list area below the logo when the
keyboard covers its lower part, with no hit target or accessibility element.
Use the generated heading XML and `headings.json`, tint/scale them with text size,
label each as a heading and check section coverage. Missing artwork falls back to
Grechen Fuemen. Never add or bundle Flat Earth Scribe or Trade Winds; heading changes
go through the licensed Mac generator for both platforms. Ship the two OFL notices
and the flattened-heading attribution in About.

Do not reopen settled scope: playable Forsaken/Ghost Wolves/Pure, not Wolf-Blooded;
no Pack section/group-level rules; no B6 import, PDF export or new era selector.
Tilts are already catalog content, but a Tilt/combat/equipment workflow, extra
Primal Urge reminders, further Favored Form automation and other deferred audit
features stay deferred. Pack-Merit reminders remain an optional later question,
not a dependency of this port.

PR **#5** should be refreshed with screenshots of the actual Requiem release candidate
before merging, or superseded with a new asset PR while preserving the beta-1 archive.
PR **#6** is useful historical beta-1 Advertising ID evidence; resolve its documentation
conflict and recheck the final candidate's package/dependencies before calling it
current release sign-off. Both presently conflict with main. Keep them out of the
Forsaken plan and do not merge stale release claims unchanged or close them silently.

## Questions and acceptance evidence

**User decisions, 17 November 2026:** the phase order and module split are approved.
Android's application ID is `com.omccolgan.ForsakenCharacterSheet`, matching iOS.
No Forsaken Play listing exists. Keep the current Android 16/API 36 baseline.
The delivery plan is a separate free “Forsaken Character Sheet” listing, version
code 1 and internal testing first. Listing registration, signing/upload setup and
the existing privacy/backup decisions belong to the delivery phase; they do not
block the rules modules. No listing or upload has been performed by this approval.

**Question: Claude — contract/exchange coordination.** Agree the registry, unchanged
Requiem paths, byte-preserving fixture move and Xcode-backed exchange above? Please
own/coordinate the iOS test-resource changes, producer/consumer modes and Xcode
evidence extraction with the Android/policy PR. Confirm a reliable test-container
handoff; if a small host-buildable extraction is preferable, propose it before we
change `Package.swift` or model boundaries.

**Question: Claude — creation fixture.** `forsaken-v1-creation.json` identifies a
Predator King with `freeSkill: survival` and `grantedRenown: [purity]`, which the
format tests pin. The current tribe entry instead has primary Glory and
Animal Ken/Brawl/Crafts. Is this intentionally an older/inconsistent but preserved
creation save? Please pin opening/resuming and then changing tribe/auspice/free Skill
with a test: `applyCreationGrants()` would alter these grants, but the sheet calls
it on identity changes, not automatically on opening. Do not rewrite the fixture
to answer this question; add a new example/test if needed.

**Question: Claude — catalog prose.** The catalog-format description says primary
Renown is absent for the Pure, whereas the catalogs and `shunnedByTheMoonHasThePure`
test give them primary Renown. Please clarify the description; Android will retain
the submitted catalogs and match the implemented Pure rules.

**Question: Claude — log keys.** The save-format prose says non-Attribute/Skill/Renown
keys use row UUIDs, but shared XP snapshots use `specialty:<skill-id>` and Condition
operations write `condition:<catalog-or-custom>/<UUID>`. The play fixture also has
bare `condition:<UUID>` history. Please document and pin both preserved historical
keys and newly generated keys with a production action example, including the
`primalUrge:primalUrge` singleton. Android should preserve old history, not normalize it.

For each implementation phase, map relevant reference test names to Kotlin tests
and record passes/pending outcomes in the handoff. High-risk gates include
`bonusDotsPastTheLimitStackBySource`, `shiftingToASmallerFormKeepsItsWounds`,
`thePriceShownIsThePriceCharged`, `lodgeLoreCostsOutsidersThreeTimesAsMuch`,
`aSecondMoonGiftCostsFiveThenTwoAFacet`, and all creation grant tests. Add interaction
coverage for view-triggered edits rather than relying on model-only tests.

Local Linux validation covers Python policy, Kotlin rules/storage, Android lint,
packaging and available device/emulator tests. Swift/Xcode and bidirectional Forsaken
exchange require macOS CI/Claude's Mac; do not report them as locally run. Before
release, compare small/large text and keyboard layouts with iOS, run TalkBack on
device, exchange real files both ways and install both apps together. CI success
does not replace those acceptance checks.
