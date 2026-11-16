# Multi-game plan: Requiem and Forsaken on one shared base

Status: **agreed 2026-11-12**. Phase 1 is done on iOS (see "Phase 1 as built").

## Decisions (user, 2026-11-12)

- **Separate apps on a shared base, in this repository.** "Requiem Character Sheet" (Vampire: The Requiem 2e) and
  **"Forsaken Character Sheet"** (Werewolf: The Forsaken 2e) are separate apps, with their own store listings, icons,
  themes and catalogs. They're built from shared Chronicles of Darkness code. Android does the same, in Kotlin.
- **Phase 1 ships on its own first.** It moves the game-neutral code into a shared core with no visible change and no
  save-format change, before any Werewolf screens exist.
- **Werewolf rules call:** a Wolf Gift Facet costs **1 Experience**. This follows the quick reference on p. 84, over the
  2 given in the text on p. 85.

## Shared and game-specific

| Shared core | Requiem only | Forsaken only |
|---|---|---|
| Attributes, Skills, skill lists, Specialties | Clan, Bloodline, Covenant | Auspice, Tribe, Lodge |
| Merit engine and CofD Merits | Disciplines, Devotions, sorcery, Coils and Scales | Gifts and Facets, Rites, Fetishes, Totem |
| Conditions; Aspirations; Health and Willpower | Blood Potency, Vitae | Primal Urge, Essence |
| Beats, Experiences, XP Mode, change log | Humanity, Touchstones, Banes, Mask/Dirge | Harmony (two Touchstones), Blood/Bone, Kuruth triggers |
| Catalog loading, book sections, pickers, custom entries | Elder banes, ritual rules | Five forms with per-form traits; Renown |
| Saving, export/import, guided-creation framework, About | | Hunter's Aspect |

## Phase 1: extract the core (iOS)

The goal is a compiled boundary: shared code must not refer to anything Vampire.
1. **`ChroniclesCore`.** A SwiftPM target (`Shared/Core/`) holds the game-neutral models:
   - Attributes, Skills, skill lists, Merits, Aspirations, Conditions, tracks;
   - trait keys, the change log, TraitSource, generic catalog types;
   - Utilities.

   Declarations used across the boundary are marked `package`. The Xcode app compiles everything as one module, with
   `SWIFT_PACKAGE_NAME` set so `package` is accepted.
2. **A shared character protocol.** `ChroniclesCharacter` holds the shared traits as protocol requirements. Shared rules
   are protocol extensions on it: Merit checks for the generic requirement kinds, Specialties, Conditions,
   Experiences and tracks. Game-specific requirement kinds (clan, bloodline, covenant, Discipline, Blood Potency) go
   through a game hook. The Vampire `Character` conforms, keeping its stored properties and save format exactly.
3. **Requiem code** stays in the `RequiemCharacterSheet` target, which depends on `ChroniclesCore`.
4. **Generic UI components** move to `Shared/UI/`: dots, boxes, pickers, book headers, section pill, Conditions
   carousel, hosted sheets and theme. This is a convention for now; it's compiled by each app.
5. **The app's identity** (name, legal notices, file type, theme) moves behind an `AppIdentity` value, so the second app
   supplies its own.
6. **Proof:** the save-contract fixtures and all tests pass unchanged, and saved files are byte-identical.

### Phase 1 as built (2026-11-12)

- **`Chronicles/Core/` is the `ChroniclesCore` SwiftPM target.** The Requiem package target depends on it. Building it
  on its own proves it has nothing Vampire. It holds:
  - Attributes, Skills, skill lists and Specialties;
  - Aspirations, box types and Utilities;
  - the trait log (`TraitKind` is now an open name, with saved strings unchanged);
  - `TraitSource`, `Merit` and `CharacterCondition` (stored data and save format);
  - the catalog basics: `CatalogEntry`, `Book`, `SourceReference`, `CatalogIndex`, book sections;
  - `MeritEntry`, `ConditionEntry` and `Effect`. Prerequisite kinds and Merit categories are open names; Requiem
    adds clan, Discipline and so on.
  - `ChroniclesCharacter`: the shared traits as a protocol, with the rules that need only those. These are attribute
    and skill ratings, Willpower dots, Beats to Experiences, and Specialty choices.
- **Catalogs are passed in.** Core types never reach for a global catalog: they take one as a parameter, e.g.
  `merit.entry(in:)` and `relink(in:)`. Requiem adds the familiar `merit.entry` and `merit.name` using its bundled
  catalog. Old name-only saves are relinked in `Character`'s decoding.
- **`Chronicles/UI/`** holds the generic views and the theme type:
  - dots, boxes, background and pickers, with book headers;
  - hosted sheets and character files;
  - `AppIdentity` (theme, file type, file extension). Requiem defines `AppIdentity.current` and `Theme.requiem` in
    `App/RequiemIdentity.swift`.
  - The interface code isn't a module yet, so this boundary is a convention.
- **Saves are unchanged.** Every shared fixture encodes byte-for-byte as before, except those with no saved ids,
  which get fresh ones on every read. All tests pass unchanged.
- **Left for when Forsaken exists,** so both games shape them: the Condition rules (add, end, resolve, Beats), the
  generic requirement checks and the XP rules. These still live on Requiem's `Character`.

Not in Phase 1 (they need Astra and later phases): moving `Catalogs/`, `Fonts/` or `shared/fixtures/`; a `game` field
in catalogs and saves. Today's files stay valid Requiem files; Forsaken files will carry `"game": "forsaken"` and use
`.wtfcharacter`.

## Forsaken app identity (2026-11-15)

- **Bundle ID:** `com.omccolgan.ForsakenCharacterSheet`. Files use `.wtfcharacter`; saves carry `"game": "forsaken"`.
- **Assets in `ForsakenCharacterSheet/`,** ready for the target:
  - `Fonts/`: Comforter and Grechen Fuemen, each with its OFL licence. Section headings are pictures in Flat
    Earth Scribe (see `design-decisions.md`); the font itself is never bundled.
  - `Assets.xcassets`: the app icon, the Werewolf logo, the skull watermark (a template image the app tints Werewolf
    Rust) and Werewolf Rust as the accent colour.

  Like Requiem's, the fonts are shared with Android.

## Phase 2 as built so far (2026-11-15)

- **Shared store and list.** `CharacterFileStore<C>` (in `Chronicles/Core`) saves any game's characters. It reads the
  file's `game` key: a missing key means Requiem, and any other game is refused with "This character is from another
  game". Requiem keeps `CharacterStore` and `CharacterImport` as type aliases, and its saves are unchanged.
  `CharacterListView` (in `Chronicles/UI`) is generic; each game says how to create a character and which sheet opens.
- **Per-game sections and headings.** `SheetSection` is an open type, with the sections every game has in
  `Chronicles/UI` and Requiem's own in `RequiemSheetSections.swift`. `Theme.sectionHeaderStyle` is `.row` for
  Requiem and `.brushLine` for Forsaken; `BrushLine` draws the stroke from a seed. The theme also gives faces per text
  style (`fonts`), the pill's face, whether trait names use the accent colour, and an optional border.
- **The Forsaken target.** The target is `ForsakenCharacterSheet` (`com.omccolgan.ForsakenCharacterSheet`, version
  1.0, iPhone, iOS 26), with a shared scheme. Its folder is synchronised with the project, so new files there join the
  target. Shared files in `Chronicles/` are listed in both targets; new ones made through Xcode join both.
  - `ForsakenCharacter` saves `"game": "forsaken"` with schema 1 and the extension `.wtfcharacter`.
  - The sheet uses the shared `CharacterSheetFrame`, which has the logo, watermark, list, pill and saving. It has
    the Character section so far: Name, Player, Chronicle, Blood, Bone, Concept, Auspice, Tribe and Lodge.
- **Also shared now:** the splash (`SplashContainer`), About (each app lists its own fonts) and the row components.

- **Every shared section is shared (step 4).** Attributes, Skills with Specialties, Merits with the picker and
  details, Aspirations, Health, Willpower, Conditions and Experience are generic views in `Chronicles/UI`. Forsaken's
  sheet has all of them, and Requiem's sheet uses `CharacterSheetFrame` too.
  - **Rules in the core.** The game-neutral rules moved into `Chronicles/Core`, so `swift test` still covers them:
    - Merit prerequisites for Attributes, Skills, Merits and Willpower, the "one of" logic, and rating and effect
      wording (`Prerequisites.swift`);
    - Conditions (`ConditionRules.swift`, for any `ConditionsCharacter`);
    - Experience totals, change logging, XP charges and refunds (`ExperienceCore.swift`, for any
      `ExperienceCharacter`). Each game supplies its trait snapshot, its costs, its refund rule and the order of its
      kinds of trait.
  - **Hooks in `SheetCharacter`.** The views ask the character for game rules through `SheetCharacter`
    (`Chronicles/UI`): rating caps, guided-creation limits, Merit category order and titles, Merits a kind of character
    can't take, Condition marks and creation priority menus. Each hook defaults to a game without the rule; Requiem
    supplies its own in `RequiemSheetCharacter.swift`.
  - **Catalog convention.** The shared views refer to `Catalog.bundled` (its `books`, `merits` and `conditions`),
    `merit.entry`/`merit.name`, the `CharacterCondition` conveniences (`entry`, `name`, `effectText` and so on) and
    `SourceReference.citation()`. Each app defines these for its own catalog: Requiem in `Models/`, Forsaken in
    `ForsakenCatalog.swift`. Forsaken bundles `cofd-core.json` for now.
- **Forsaken tests.** The `ForsakenCharacterSheetTests` target is hosted in the Forsaken app, and the Forsaken scheme
  runs it. It covers the save format, refusing Requiem and newer files, the catalog, Health, XP charges and refunds,
  and Condition Beats.

## Phase 3 as built so far (2026-11-15)

- **Catalog.** `ForsakenCharacterSheet/Catalogs/wtf2e-core.json` is in the forsaken-catalog format
  (`docs/forsaken-catalog-format.md`). It has 5 auspices, 9 tribes, 8 lodges, 12 Blood and Bone archetypes, 23 Gifts
  with 115 Facets, 23 Rites, 55 Merits, 45 Conditions and 18 fetishes, all with the book's pages. Forsaken lists the
  Werewolf core book first, then the shared Chronicles of Darkness core.
- **Character.** Auspice, tribe, lodge, Blood and Bone link to the catalog. Renown, Primal Urge (with its table),
  Essence (starting at 7), Harmony, Touchstones, Kuruth triggers, form, Gift Facets, Rites and fetishes are saved.
  Primal Urge caps Attributes and Skills, the form changes Attributes, Size and Health, and Merit prerequisites check
  Renown, Primal Urge, Harmony, tribe and auspice. Experience costs follow pp. 84–85; a Wolf Gift Facet costs 1.
- **Sheet.** The sections are Character (with catalog pickers), Form, Attributes, Skills, Merits, Renown, Gifts, Rites,
  Fetishes, Aspirations, Health, Willpower, Primal Urge with Essence, Harmony with Touchstones, Kuruth triggers,
  Experience and Conditions.

- **The Pure.** Night Horrors: Shunned by the Moon (`nh-shunned-by-the-moon.json`) holds the three Pure tribes, which
  moved there from the core file, with their secondary Renown, Skills and two Hunter's Aspects. It also has five Shadow
  Gifts, five Rites, nine Merits and eight Conditions. A Pure character has no auspice: the Auspice row becomes a
  Hunter's Aspect choice, their Gift affinities are the tribe's alone, no Moon Gift is free, and Renown notes mark the
  secondary Renowns.

- **Gifts.** Moon, Shadow and Wolf Gifts are separate sections. Moon Gift Facets aren't listed with the others: each
  dot of auspice Renown unlocks the next Facet of the character's Moon Gift, which is their auspice's own unless
  they choose an alternate or write their own.
- **Unofficial content.** A book can be marked unofficial. The Giver of Gifts 1 and 2 (Onyx Path blog) add the Gift
  of the Screaming Moon, the Gift of Cities and the Gift of Essence. Each character's Unofficial Content switch,
  off by default, decides whether pickers show them.

- **Reminders.** An Auspice Benefit section, Kuruth trigger sets muted by Harmony with the general triggers, and
  Siskur-Dah effects by the ritemaster's tribe.

- **Since then (2026-11-16):** guided creation for the Forsaken, Ghost Wolves and the Pure; the pack totem; an
  Advantages section with Defense, Initiative, Speed and Perception for each form; Gift and rite effects; section
  headings as Flat Earth Scribe pictures. See the handoff entries of that date.

### Before the App Store (user, 2026-11-16)

1. Add **The Pack** as a book. Done 2026-11-16, as far as it reaches one character: the lodges and what they teach.
2. Go through the Werewolf chapters of **Dark Eras** and the rest of the **core book**, and add any mechanics the
   catalogs lack. `docs/forsaken-content-audit.md` lists what was found.
3. Settle the save format (it is still a draft at schema 1), then the App Store listing and screenshots.

### Order of work between the apps (user, 2026-11-16)

- New work is done on iOS first and ported to Android afterwards.
- Android's `:forsaken` starts once the iOS app has been submitted to the App Store, not before.
- Requiem's Android beta 3 and Forsaken don't block each other. Until iOS Forsaken is submitted, Astra's work is
  Requiem: beta 3's acceptance and release, and the iOS 1.5 follow-ups. After that, `:forsaken` starts wherever
  the Play release has got to.

## Later phases

2. A second app target, Forsaken, with only the shared sections and its own theme.
3. The Werewolf core catalog (`wtf2e-core.json`):
   - Auspices, Tribes and Lodges;
   - Gifts and Facets, Rites and Fetishes;
   - Merits and Conditions;
   - the Primal Urge and form tables.
4. Werewolf sheet sections:
   - Forms, Renown, Gifts, Rites;
   - Primal Urge and Essence, Harmony, Kuruth;
   - XP costs and guided creation.
5. Werewolf sourcebooks, grouped by book (see `design-decisions.md`).

Android follows each phase: `:core`, `:requiem` and `:forsaken` modules, and two app modules.

### Android Phase 1 as built (13 November 2026)

Android now mirrors this boundary with JVM `:core`, game-specific `:requiem` and
the existing `:app`. The core owns shared saved models, catalog indexing and book
sections, trait definitions, track helpers and game-neutral character calculations.
Requiem retains its schema policy, migration, purchase ledger, prerequisites and
Condition edit engine. `ie.chronicles.ui` contains reusable Compose controls with
app-injected fonts/artwork. Catalogs, fonts, package/storage paths and JSON remain
unchanged; no Forsaken module exists yet. See `android/README.md` for verification.
