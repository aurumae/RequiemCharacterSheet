# Phase B: Catalogs, Effects and Imported Descriptions

Status: **agreed 2026-11-03**, with the decisions below. Implementation in progress.

## Decisions

- **Summaries are our own wording.** Book excerpts and the Codex of Darkness are references for facts only (names, dots, costs, pools, prerequisites, pages). No book text ships in the app.
- **Scope:** core-book Disciplines, Merits, Banes, Clans and Covenants, plus the Akhud clan and Praestantia from *A Thousand Years of Night*. Devotions, Crúac and Theban rituals, and Coils of the Dragon come in a later phase.
- **Clans and covenants are catalog-backed.** At least a dozen clans exist across supplements, so clans are data, not code. The clan bane belongs to the clan entry.

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

Effects are a closed vocabulary that the rules engine understands. Catalog entries list them. `Character` adds them up instead of matching names.

```swift
enum Effect: Codable {
    case attributeBonus(AttributeKind, Amount)        // Vigor, Resilience, Praestantia
    case defenseBonus(Amount)                         // Celerity
    case alternativeDefenseSkill(fromQualifier: Bool) // Defensive Combat (Brawl/Weaponry)
    case initiativeBonus(Amount)                      // Fast Reflexes
    case speedBonus(Amount)                           // Fleet of Foot
    case sizeBonus(Amount)                            // Giant
    case healthBonus(Amount)
    // Added as new merits need them
}

enum Amount: Codable {
    case rating                 // the entry's dots
    case fixed(Int)
    case perRating([Int])       // index by dots, for uneven tables
}
```

The first step of Phase B moves the five existing hard-coded rules onto this system: Vigor, Resilience, Praestantia, Celerity, and Defensive Combat. Tests must show identical totals before and after.

Not in the first version: **activated** effects (spending Vitae to boost Celerity this turn) and conditional effects. The vocabulary can grow to cover them, with a per-character "active" toggle.

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

- **Praestantia** (*A Thousand Years of Night* p. 29) adds its dots to Dexterity **for rolls** and to **Initiative**, and may exceed the Blood Potency trait maximum. It doesn't mention Speed or Defense. The app currently adds it to Dexterity everywhere, including Speed and Defense. B2 needs a decision on this.
- **Vigor, Resilience and Celerity** match the app today: Vigor adds to Strength, Resilience to Stamina (so Health), Celerity to Defense.
- **Defensive Combat, Fast Reflexes, Giant, Iron Stamina and Strong Back** aren't in *Vampire: The Requiem*; they come from the *Chronicles of Darkness* core rulebook. The app already uses Defensive Combat, so it needs that book's entry before B2 can move it to data.
- **Covenants** aren't described in the excerpts, so their entries have no page numbers yet.
- **Clan banes** apply from Humanity 6 and stay even if Humanity later rises, so the sheet will need a stored "clan bane active" flag. The Ventrue bane applies from character creation, and the Akhud bane gives no threshold.
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

B1 and B2 change no behaviour and are covered by tests, so the risky part (data model and migration) lands first.

## Open questions

1. **Praestantia:** should it apply to Speed and Defense (as the app does now), or only to rolls and Initiative (as the book says)?
2. **Chronicles of Darkness Merits:** can you provide the core-rulebook pages for Defensive Combat and the other general Merits the app relies on (Fast Reflexes, Giant, Iron Stamina, Strong Back)?
3. **Covenants:** can you provide the covenant pages from the core rulebook, so their entries can cite pages?
