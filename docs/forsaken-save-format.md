# Forsaken save format (schema 1)

A Forsaken character is one JSON file, `<id>.json`, in the app's characters folder; a shared or exported file has
the extension `.wtfcharacter`. `ForsakenCharacter` in `ForsakenCharacterSheet/Models/ForsakenCharacter.swift` reads
and writes it. This is the format the first App Store release writes.

Two saved characters pin it, in `ForsakenCharacterSheetTests/Fixtures/`:

- `forsaken-v1-play.json`: a Cahalith of the Blood Talons well into play.
- `forsaken-v1-creation.json`: a Predator King part-way through guided creation.

`SaveFormatTests` checks that each loads and is written back unchanged, that between them they use every key below,
and what a selection of their numbers come to. They stay out of `shared/fixtures/` until Android has a `:forsaken`
module; then they move there and join the contract.

## Rules

- Every file has `"game": "forsaken"` and `"schemaVersion"`. The app refuses a file for another game, or with a
  higher schema version than it knows.
- A missing key reads as a new character's value, and unknown keys are ignored.
- **After the first release, anything new in the file needs the next schema version**, so an older app refuses the
  file instead of opening it and dropping what it can't read. This is Requiem's rule too.
- Dates are seconds since 2001-01-01 UTC, as numbers. Ids are UUID strings.
- A **trait source** is `{"catalog": "<id>"}` for a catalog entry or `{"custom": "<text>"}` for the player's own. On
  reading, custom text that matches a catalog entry's name is linked to it.
- "Left out" below means the key isn't written in that case.

## Keys

**File and character details**

| Key | Value |
|---|---|
| `game`, `schemaVersion` | `"forsaken"`, `1` |
| `id`, `createdAt`, `modifiedAt` | UUID; dates |
| `name`, `player`, `chronicle`, `concept` | text |
| `blood`, `bone` | trait sources (archetypes) |
| `auspice`, `tribe`, `lodge` | trait sources; `{"custom": ""}` for none |
| `huntersAspect` | the name of the Hunter's Aspect a Pure character chose from their tribe's two. Left out when empty. |

**Shared with every Chronicles sheet** (the same shapes as Requiem's)

| Key | Value |
|---|---|
| `attributes` | `[{"attribute": "strength", "rating": 3}]`, all nine |
| `skills` | `[{"skill": "brawl", "rating": 3, "specialties": ["Claws"]}]` |
| `merits` | `[{"id", "source", "qualifier"?, "rating"}]`. A Merit the totem grants has a row here with rating 0. |
| `aspirations` | `[{"id", "text"}]` |
| `conditions` | `[{"id", "source", "note", "counter", "addedAt"}]`; a custom one also has `customEffect`, `customResolution`, `customBeat` (text) and `customPersistent` |
| `healthTrack` | one of `"none"`, `"bashing"`, `"lethal"`, `"aggravated"` per Health box in the form worn when saved. Wounds beyond those boxes are folded in first (p. 172). |
| `willpowerTrack` | `"none"` or `"spent"` per Willpower box |
| `beats`, `experiences`, `xpMode` | numbers; whether XP Mode is on |
| `changeLog` | `[{"id", "date", "trait", "name", "from", "to", "experiences", "xpMode", "duringCreation"?, "event"?, "beats"?}]`. `trait` is `"<kind>:<id>"`. |
| `paidDots` | `{"<kind>:<id>": {"<dot>": <Experiences paid>}}`, so lowering a trait refunds what it cost |
| `creation` | guided creation's choices, while it lasts: `{"attributePriorities": {"physical": 0}, "skillPriorities": {…}, "freeSkill"?, "grantedRenown": ["purity"]}`. Priorities are 0 primary, 1 secondary, 2 tertiary. Left out once creation is finished. |
| `showsUnofficialContent` | `true` if pickers offer unofficial content. Left out when false. |

Trait kinds in `changeLog` and `paidDots`: `attribute`, `skill`, `specialty`, `merit`, `condition`, and Forsaken's
`renown`, `moonGift`, `facet`, `rite` and `primalUrge`. What follows the kind, with UUIDs in capitals:

| Kind | Key | Example |
|---|---|---|
| `attribute`, `renown` | the trait's name | `attribute:strength`, `renown:glory` |
| `skill` | the Skill's id | `skill:animal-ken` |
| `specialty` | the Skill's id; the level is how many Specialties it has | `specialty:brawl` |
| `merit`, `facet`, `rite`, `moonGift` | the row's UUID | `merit:8C0E…` |
| `primalUrge` | always `primalUrge` | `primalUrge:primalUrge` |
| `condition` | the catalog id, or `custom`, then `/` and the Condition's UUID. Logged, never in `paidDots`. | `condition:shaken/8C0E…`, `condition:custom/8C0E…` |

`SaveFormatTests.eachKindOfTraitHasItsLogKey` makes each kind of change and pins these. History under any other key is
kept as it is and shown by the name the entry recorded: the play fixture has a Condition logged as `condition:<UUID>`,
which no version of the app wrote (`historyUnderOtherKeysIsKept`).

## The fixtures are examples of the format, not of play

Both fixtures were put together by hand to use every key. Two things in them couldn't come from the app:

- The play fixture's last log entry is under `condition:<UUID>` (see above).
- The creation fixture is a Predator King whose free Skill dot is on Survival and whose granted Renown is Purity. The
  tribe gives Animal Ken, Brawl or Crafts, and Glory.

Opening a file never puts such things right: a reader keeps `creation` as saved. The creation panel then asks for the
free Skill dot again, and the grants are brought into line only when the player places that dot or changes the
auspice or tribe (`openingASavedCreationLeavesItsGrantsAlone`, `editingAResumedCreationMovesItsGrants`). The fixtures
themselves never change; examples of real creation by each kind of character will be added beside them.

**Werewolf traits**

| Key | Value |
|---|---|
| `renown` | `{"glory": 3}`; Renowns without dots are left out |
| `primalUrge`, `essence`, `harmony` | numbers |
| `fleshTouchstone`, `spiritTouchstone` | text |
| `kuruthTriggerSet` | trait source: one of the book's sets, or the player's own |
| `kuruthTriggers` | `{"passive", "common", "specific"}`, the player's own triggers. Left out for a set from the book. |
| `form` | `"hishu"`, `"dalu"`, `"gauru"`, `"urshul"` or `"urhan"` |
| `size`, `armor`, `ballisticArmor` | Size in Hishu; armor the player entered. `ballisticArmor` is left out when 0. |
| `totem` | `{"name", "aspiration", "ban", "packPoints", "advantages": [{"id", "kind", "target", "detail", "dots"}]}`. `kind` is `"attribute"`, `"skill"`, `"specialty"` or `"merit"`; `target` is the Attribute, the Skill's id or the Merit's catalog id. Left out for an empty totem. |
| `favoredForm` | what the Favored Form Merit changes: `{"attributes": ["strength"], "drawbacks": [{"form": "hishu", "attribute": "strength"}]}`. `attributes` is the second dot's, then the fourth's (`null` for one not yet chosen); a drawback not yet chosen lacks its keys. Left out when nothing is chosen. |

**Gifts, rites and fetishes**

| Key | Value |
|---|---|
| `moonGift` | trait source for the Moon Gift whose Facets come with auspice Renown. Left out when it is the auspice's own. |
| `moonFacets` | the Facet names of a custom `moonGift`, from one dot up. Left out when empty. |
| `extraMoonGifts` | Moon Gifts bought with Experiences: `[{"id", "source", "dots", "facets"?}]`. `dots` is how many Facets are bought; `facets` names a custom Gift's. Left out when empty. |
| `facets` | Shadow and Wolf Facets: `[{"id", "source", "active"?, "withRenown"?}]`; a custom one also has `customGift` and `customKind` (`"shadow"` or `"wolf"`). `active`: switched on. `withRenown`: learned free with a new dot of Renown. |
| `renownFacetCredits` | `{"honor": 1}`: free Facets from Renown gained in XP Mode, not yet learned. Left out when none. |
| `rites` | `[{"id", "source", "active"?}]`; a custom one also has `customRating` |
| `fetishes` | `[{"id", "source", "note"?}]`; a custom one also has `customRating` |

The Facets of `moonGift` aren't saved: the character has one for each dot of auspice Renown.

## Read but never written

Drafts from before the first release put Moon Gift Facets in `facets`. They are dropped on reading.
