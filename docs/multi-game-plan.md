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
