# Phase B: Catalogs, Effects and Imported Descriptions

Status: **agreed 2026-11-03**, with the decisions below. Implementation in progress.

## Decisions

- **Summaries are our own wording.** Book excerpts and the Codex of Darkness are references for facts only (names, dots, costs, pools, prerequisites, pages). No book text ships in the app.
- **Scope:** core-book Disciplines, Merits, Banes, Clans and Covenants, plus the Akhud clan and Praestantia from *A Thousand Years of Night*. Devotions, Crúac and Theban rituals, and Coils of the Dragon come in a later phase.
- **Clans and covenants are catalog-backed.** At least a dozen clans exist across supplements, so clans are data, not code. The clan bane belongs to the clan entry.
- **Praestantia follows the book:** Dexterity for rolls and Initiative only, not Speed or Defense.
- **Clan banes** take effect when Humanity falls to 6 (every clan, including Ventrue and Akhud), stay in effect if Humanity rises, and can be switched off by the player in case they were set while trying out changes.
- **At most three Banes**; the Mekhet's extra Bane is one of them.

## Goals

1. Disciplines, Merits, Banes, Clans and Covenants can be picked from a built-in list, or entered by hand for homebrew.
2. Rules effects (Vigor adding to Strength, Defensive Combat adding a Defense option, …) come from data, not hard-coded names.
3. The app ships a summary level of detail per power (name, dots, cost, dice pool, one-line description, book and page), matching the level of codexofdarkness.com.
4. Players who own the books can import a file with full descriptions. The app never ships book text.

Aspirations stay freeform text and are out of scope.

## 1. Two layers: catalog and character

**Catalog entries** are read-only reference data, bundled with the app or imported. They describe a Discipline, Merit or Bane: what it's called, where it's from, what each dot does, and its mechanical effects.

**Character entries** are what's on a sheet. Each points at a catalog entry *or* is custom:

```swift
enum TraitSource: Codable, Hashable {
    case catalog(CatalogEntryID)   // e.g. "vigor", "defensive-combat"
    case custom(name: String)      // homebrew or anything not in a catalog
}

@Observable final class Discipline {   // likewise Merit, Bane
    let id: UUID
    var source: TraitSource
    var rating: Int
    var qualifier: String?   // Merits only: "Brawl" in "Defensive Combat (Brawl)"
    var notes: String        // the player's own notes
}
```

Custom entries have no effects, so they never change derived values. A custom entry can later be "linked" to a catalog entry if one is added.

Disciplines, Merits and Banes are **separate types that share this pattern**, rather than one unified model. Their catalog entries differ too much to share one shape.

## 2. Catalog entries

IDs are stable strings, unique per kind, like the skill IDs in Phase A. Each entry records its source book.

```swift
struct SourceReference: Codable, Hashable {
    let book: BookID            // "vtr2e-core"
    let page: Int?
}

struct DisciplineEntry: Codable, Identifiable {
    let id: CatalogEntryID      // "dominate"
    let name: String
    let source: SourceReference
    let kind: Kind              // .powers or .scaling
    let powers: [DisciplinePower]   // one per dot for .powers; one entry for .scaling
    let effects: [Effect]       // passive effects, e.g. Vigor adds its dots to Strength

    enum Kind: String, Codable { case powers, scaling }
}

struct DisciplinePower: Codable, Identifiable {
    let id: CatalogEntryID      // "dominate-mesmerize"
    let name: String            // "Mesmerize"
    let dots: ClosedRange<Int>  // 1...1, or 1...5 for scaling disciplines
    let cost: Cost
    let targetCondition: String?    // "Mesmerized": what the target must already have
    let dicePool: DicePool?
    let summary: String         // one line, our own wording
    var fullText: String?       // only from an imported file
}

struct MeritEntry: Codable, Identifiable {
    let id: CatalogEntryID      // "defensive-combat"
    let name: String
    let source: SourceReference
    let ratings: [Int]          // allowed dot ratings, e.g. [1] or [1, 2, 3]
    let qualifier: QualifierRule?   // e.g. must name Brawl or Weaponry
    let prerequisites: [Prerequisite]
    let effects: [Effect]
    let summary: String
    var fullText: String?
}

struct BaneEntry: Codable, Identifiable {
    let id: CatalogEntryID
    let name: String
    let source: SourceReference
    let summary: String
    var fullText: String?
}

struct ClanEntry: Codable, Identifiable {
    let id: CatalogEntryID          // "daeva", "akhud"
    let name: String
    let nickname: String?           // "Serpents"
    let source: SourceReference
    let favoredAttributes: [AttributeKind]   // choose one at the Embrace
    let disciplines: [CatalogEntryID]        // in-clan Disciplines
    let bane: ClanBane              // name, summary, Humanity threshold, page
    let summary: String
    var fullText: String?
}

struct CovenantEntry: Codable, Identifiable {
    let id: CatalogEntryID          // "invictus"
    let name: String
    let source: SourceReference
    let summary: String
    var fullText: String?
}
```

A character's clan and covenant use the same `TraitSource` as Disciplines, so a homebrew or not-yet-catalogued clan is still possible.

**Cost** is stored structured, so the app can show it consistently in the Codex notation (● Vitae, ○ Willpower, (optional)) and later deduct it:

```swift
struct Cost: Codable {
    var vitae: CostAmount       // .none, .fixed(2), .range(3, 9), .varies
    var willpower: CostAmount
    var isOptional: Bool        // "(●)"
}
```

**Dice pools** are stored structured for the common shape, with a text fallback for unusual ones ("highest Composure + Blood Potency in group"):

```swift
struct DicePool: Codable {
    let attribute: AttributeKind
    let skill: SkillID?
    let includesDiscipline: Bool
    let resistance: String?     // "Resolve + Blood Potency" (contested) or "− victim's Resolve"
}
```

Because pools are structured, the sheet can later show each power's **current pool for this character**, e.g. "Mesmerize: 6 dice".

## 3. Effects

Effects are a closed vocabulary that the rules understand. Catalog entries list them, and `Character` adds them up instead of matching names. As implemented (B2):

```swift
enum Effect {
    case attribute(AttributeKind, Amount)       // raises the trait: Vigor, Resilience
    case attributeRolls(AttributeKind, Amount)  // rolls only: Praestantia (Dexterity)
    case defense(Amount)                        // Celerity
    case initiative(Amount)                     // Praestantia, Fast Reflexes
    case speed(Amount)                          // Fleet of Foot
    case size(Amount)                           // Giant, Small-Framed (and so Health)
    case defenseSkillFromQualifier              // Defensive Combat (Brawl/Weaponry)
}

enum Amount { case rating, fixed(Int) }
```

In JSON: `{"type": "attribute", "attribute": "strength", "amount": "rating"}`. Unknown types are skipped, so a newer or imported catalog can't break loading.

Attributes have two values: the **trait** (with `attribute` bonuses), used for Speed, Defense and Health, and the **roll** value (also with `attributeRolls` bonuses), used for dice pools and shown on the sheet.

Not yet modelled: **activated** effects (spending Vitae to boost Celerity this turn), conditional effects (e.g. Safe Place's Initiative bonus), and wound penalties (Iron Stamina). The vocabulary can grow to cover them.

## 4. Catalog files

Bundled catalogs are JSON files in the app, one per book:

```
Catalogs/vtr2e-core.json
```

```json
{
  "format": "requiem-catalog",
  "version": 1,
  "book": { "id": "vtr2e-core", "name": "Vampire: The Requiem 2nd Edition" },
  "disciplines": [
    {
      "id": "vigor", "name": "Vigor", "kind": "scaling",
      "source": { "book": "vtr2e-core", "page": 141 },
      "effects": [{ "attributeBonus": { "attribute": "strength", "amount": "rating" } }],
      "powers": [{
        "id": "vigor", "name": "Vigor", "dots": [1, 5],
        "cost": { "vitae": { "fixed": 1 }, "optional": true },
        "summary": "Adds to Strength."
      }]
    },
    {
      "id": "dominate", "name": "Dominate", "kind": "powers",
      "source": { "book": "vtr2e-core", "page": 131 },
      "powers": [{
        "id": "dominate-mesmerize", "name": "Mesmerize", "dots": [1, 1],
        "dicePool": { "attribute": "intelligence", "skill": "expression",
                      "includesDiscipline": true, "resistance": "Resolve + Blood Potency" },
        "summary": "Imposes the Mesmerized Condition; control with short commands."
      }]
    }
  ]
}
```

A `CatalogStore` loads the bundled files and any imported ones, and looks entries up by ID.

## 5. Importing full descriptions

An imported file has the **same format** as a bundled catalog. When imported, its entries are merged by ID:

- For an existing entry, its `fullText` fields are added. Nothing else changes, so bundled rules data stays authoritative.
- A new ID adds a new entry. This also gives homebrew catalogs for free, e.g. a troupe's custom Disciplines.

Imported files are copied into the app's private storage (`Application Support/Catalogs/`) and can be removed from a settings screen.

Writing the file by hand from nothing would be tedious, so the app offers **Export Template**: a catalog file listing every bundled entry and power by ID and name, with empty `fullText` fields. A player fills in the text from their books and imports it. They could also share it with their own group, but that's their choice; the app never distributes it.

Import uses the system document picker (`fileImporter`), and the file is checked against the format and version first. Errors name the problem entry.

## 6. Saved characters (schema version 5)

- `disciplines`, `merits` and `banes` entries gain `source`, `qualifier` and `notes`.
- **Migration:** an existing entry's `name` is matched against catalog names. "Vigor" becomes `.catalog("vigor")`. "Defensive Combat (Brawl)" becomes `.catalog("defensive-combat")` with qualifier "Brawl". Anything unmatched becomes `.custom(name:)`, so nothing is lost.
- Opening an old save still doesn't count as an edit (the re-encode comparison from Phase A covers this).

## 7. UI

- **Disciplines:** each row shows the name and dots. Tapping the name opens a detail sheet listing the powers up to the character's rating: name, dots, cost, dice pool (with this character's dice), summary, page, and full text if imported. Higher-dot powers are shown dimmed below.
- **Add Discipline / Merit / Bane** opens a searchable picker of catalog entries, plus "Custom…" for free text.
- **Merits** enforce allowed ratings, ask for a qualifier when needed (Brawl/Weaponry), and show unmet prerequisites as a warning, not a block.
- **Settings** (new, from the character list): imported catalogs, Import, and Export Template.

## 8. Findings from the source books

- **Praestantia** (*A Thousand Years of Night* p. 29) adds to Dexterity for rolls and to Initiative, and may exceed the Blood Potency trait maximum. Implemented as such in B2.
- **Vigor, Resilience and Celerity** matched the app: Vigor adds to Strength, Resilience to Stamina (so Health), Celerity to Defense.
- **Defensive Combat, Fast Reflexes, Giant, Small-Framed** and other general Merits come from the *Chronicles of Darkness* core rulebook, now a third catalog (`cofd-core.json`). Merits reprinted in *Vampire: The Requiem* use the Requiem version.
- **Defensive Combat (Weaponry)** only applies while holding a weapon, so the sheet keeps showing it as a separate Defense line.
- **Clan banes** apply from Humanity 6 and stay even if Humanity rises; stored as `clanBaneActive` (schema version 6).
- **Banes** (core p. 108–109): at most three, each −1 die to detachment rolls; many scale with Humanity.

## 9. Order of work

| Step | Content | User-visible change |
|---|---|---|
| B1 | Catalog types, bundled catalogs (Disciplines, Merits, Banes, Clans, Covenants, plus Akhud and Praestantia), schema v5 migration | None |
| B2 | Effects system; move the five hard-coded rules onto it | None (same totals) |
| B3 | Discipline picker and detail sheet | Yes |
| B4 | Merits catalog, picker, qualifiers, prerequisites | Yes |
| B5 | Banes catalog and picker | Yes |
| B6 | Import, Export Template, settings screen | Yes |

B1 and B2 change no behaviour (apart from the Praestantia correction) and are covered by tests, so the risky part (data model and migration) lands first.

**Progress:** B1–B5, the Chronicles of Darkness Merits catalog, and the clan bane flag are done. B6 is on the back burner.

## Blood sorcery, Devotions, Coils and Scales (S1)

Added ahead of XP tracking and guided creation, which need their costs and rules. Facts come from Vampire: The Requiem pp. 142–159; summaries are our own words.

- **Ritual Disciplines.** Crúac and Theban Sorcery are Disciplines of a new kind, `ritual`, with no powers of their own. `ritualRules` records the teaching covenant, the Status needed, the casting cost and pool, and the Humanity rule: Crúac caps Humanity at 10 − dots, and Theban needs Humanity at least equal to the miracle's dots.
- **Rituals** (`rituals`): 10 Crúac rites and 9 Theban miracles, each with its Discipline, dots, target successes, contested or resisted pool, and sacrament.
- **Devotions** (`devotions`): 28 entries. Each has its Discipline prerequisites (`prerequisitesAnyOf` for Summoning), cost, pool and the book's own Experience cost. Several printed costs differ from the "half the prerequisite dots" guideline; we keep the printed values.
- **Mysteries** (`mysteries`): Ascendant, Wyrm and Voivode, each a Coil of five named tiers.
- **Scales** (`scales`): 10 entries, each naming its prerequisite Coil tier, which decides whether it costs 1 or 2 Experiences.
- **Character schema v7** adds `rituals`, `devotions`, `mystery` (the Mystery followed), `coils` (dots per Mystery) and `scales`. These are additive, so older saves load with none. A custom Discipline typed as "Crúac" or "Theban Sorcery" links to the new entry.

Corrections agreed with the user:
- Printed Devotion costs stand. The book's halving rule is only a guideline.
- Touch of Deprivation's pool uses Obfuscate. The printed Auspex is a holdover from 1e.
- Variants the book describes in passing are separate entries named "… (Advanced)", after Onyx Path's later "Danger Sense (Advanced)" style: Gargoyle's Vigilance (Advanced), which adds Protean 5 and costs 4 Experiences, and Blandishment of Sin (Advanced), at 4 dots with 8 successes.

**S2 (sheet UI and rules).** New Devotions, Rituals and Coils of the Dragon sections. Each has a picker built on a shared `CatalogPickerView`, a detail sheet built on `CatalogDetailView`, and a custom-entry option.
- The Rituals section appears once the character has a Ritual Discipline.
- The Coils section appears for the Ordo Dracul, or once the character has Coils or Scales.

As with Merit prerequisites, broken rules show as warnings rather than being blocked; hard limits come with guided creation. The warnings cover:
- a ritual rated above the Discipline's dots;
- a Theban miracle above the character's Humanity;
- Crúac's Humanity cap (a note, which becomes a warning when Humanity is above it);
- learning rituals without the covenant Status;
- a Coil outside the character's Mystery above their Ordo Dracul Status.

Scales show 1 or 2 Experiences depending on their prerequisite Coil. Name matching treats curly and straight apostrophes alike.

## Experiences (X1)

- **XP Mode** (`xpMode`, per character, off by default).
  - Off: changes are free.
  - On: each new dot costs the book's price and is remembered in `paidDots`.
- **Costs per dot:** Attribute 4, Skill 2, Specialty 1, Merit 1, in-clan Discipline 3 and other Disciplines 4 (Crúac and Theban Sorcery always 4), Mystery Coil 3 and other Coils 4, Humanity 2, Blood Potency 5.
  - Rituals are free up to one per Discipline dot, then 2 each.
  - Devotions and Scales cost what the catalog lists; a Scale costs 1 with its prerequisite Coil and 2 without.
- **The change log** (`changeLog`) records every change to these traits, whatever the mode: trait, name, from → to, date, Experiences charged or refunded, and whether XP Mode was on.
- **How changes are noticed.** The sheet watches a snapshot of trait levels (`traitSnapshot`) and logs the differences after each edit. This needs no per-row code, and a deleted trait keeps its name in the log.
- **Refunds.** Lowering a trait with XP Mode on refunds only the dots that were paid for. Dots added while XP Mode was off aren't refunded.
  - Lowering with XP Mode off drops the paid record without a refund.
  - Losing Humanity or Blood Potency never refunds, since those fall in play.
- **Totals.** `experiences` is now Experiences earned. Spent is the sum of the log, and Available is earned minus spent. It may go negative.
- **Saves.** Schema 8. Older saves start with XP Mode off and an empty log, so Available equals the Experiences they already show.

**X2 (UI).** Beats and Experiences move out of Advantages into a new EXPERIENCE section. It has:
- an XP Mode switch, with a line explaining the current mode;
- Beats;
- Earned (adjustable), Spent and Available;
- a Change Log row, which opens the log newest first, grouped by day, with each entry's time, change, cost, and "XP Mode off" where it applied.

The toolbar badge reads "XP Off", or the Available total in XP Mode, and switches XP Mode when tapped.

Below zero, per the user's wish for nothing intrusive: Available and the badge turn yellow (`theme.caution`), and a three-second notice appears only when Available first drops below zero. VoiceOver announces it too.

## Guided creation (C1)

A character with `creation` set (schema 9) is held to the starting dots on pp. 79–82. These are hard limits: dots beyond them can't be tapped, and pickers grey out what doesn't fit.

| Area | Rule |
|---|---|
| Attributes | 5/4/3 extra dots. The book doesn't make the player declare priorities, so they're worked out: the category with the most dots is primary. The clan's free favoured-Attribute dot goes wherever it fits best. |
| Skills | 11/7/4, worked out the same way |
| Specialties | 3 |
| Disciplines | 3 dots, at most 1 out of clan. That one dot may be Crúac or Theban Sorcery with Status in their covenant, or the Mystery's Coil with Ordo Dracul Status. Other Coils aren't allowed. |
| Rituals | One ritual per sorcery dot, rated no higher than the Discipline |
| Devotions and Scales | Not at creation; they're learned with Experiences afterwards |
| Merits | 10 dots, with 5 more per extra dot of Blood Potency (at most 3). Merits Kindred can't take are refused. |
| Humanity | 7 |

`creationReport` gives the budgets and problems for the creation panel. `creationMaximum(for:upTo:)` gives each row's limit: the highest rating that adds no new problem.

The 15 Chronicles of Darkness Supernatural Merits, plus Vice-Ridden and Virtuous, are marked `unavailableToKindred`. On the normal sheet they show a "Not available to Kindred" warning; in creation they're refused.

The book's 27 Mask and Dirge archetypes (p. 81) are a catalog list. The Mask and Dirge rows gain a menu of them, and typing your own still works.

**C2 (UI).**
- "New Character" asks for **Guided Character Creation** or **Blank Sheet**. A blank sheet has no limits, e.g. for an existing character.
- A guided character's sheet opens with a CHARACTER CREATION panel: progress, then the seven book steps. Each step shows its live budget and a done, in progress or problem icon, followed by any broken rule.
- While creating:
  - dots that can't be bought are faded;
  - the XP badge is hidden and XP Mode is locked off;
  - log entries are marked "Creation";
  - catalog Merit prerequisites are hard limits.
- **Finish Creation**
  - Disabled while a rule is broken.
  - If steps remain, it reminds the player and offers "Finish Anyway".
  - It then asks for an Experienced Kindred rank (+0 to +100) and adds those Experiences. XP Mode turns on, so what's bought afterwards is paid for.
- **Leave Guided Creation** keeps everything as a blank sheet.

**After the user's test (2026-11-04).** Guiding by inference was unclear, so the player now chooses explicitly:
- **Priorities.** Each Attribute and Skill category header has a Primary/Secondary/Tertiary menu showing the dots left. A category can't take dots until it has a priority. Choosing a taken priority swaps the two categories.
- **The clan's dot.** Choosing a clan in guided creation asks which favoured Attribute takes it. That dot is outside the 5/4/3 and can't be tapped away; changing clan takes it off and asks again.
- **Over-budget categories.** A category over its budget (e.g. after a priority swap) can't grow.

Other changes:
- The clan's first Touchstone Humanity (`firstTouchstoneHumanity`: 7 for the Ventrue, 6 otherwise) decides which dot the Kindred Traits step checks.
- The Merit picker lists Vampire Merits first.
- Capped Merits' dots sit at the left of the five-dot column.
- Aspirations are tap-to-edit, multi-line, and shown in the trait-name style. Return ends editing.

Still open: B6 (catalog import and export template).

## Open questions

None at the moment.
