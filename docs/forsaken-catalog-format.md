# Forsaken catalog format

Forsaken's catalogs are JSON files like Requiem's, with `"format": "forsaken-catalog"` and `"version": 1`. Forsaken
also reads the shared `cofd-core.json` (Requiem's format), taking its Merits and Conditions. All text is in our own
words, with the book's page. IDs are lower-case and hyphenated, unique within their kind, and stable once released.

```json
{
  "format": "forsaken-catalog",
  "version": 1,
  "book": { "id": "wtf2e-core", "name": "Werewolf: The Forsaken Second Edition" },
  "auspices": [], "tribes": [], "lodges": [], "archetypes": [], "gifts": [], "rites": [],
  "merits": [], "conditions": [], "fetishes": [], "kuruthTriggers": []
}
```

Every entry has `id`, `name`, `source: { "book", "page" }` and `summary` (one or two sentences).

`book` may have `"official": false` and a `"url"` for unofficial sources, e.g. the Onyx Path blog's Giver of Gifts
articles (`giver-of-gifts-1.json`, `giver-of-gifts-2.json`); their entries have no `page` and are cited by the URL.
Unofficial files load after all the books.

- **auspices**: `moon` ("crescent", "full", "gibbous", "half", "new"), `renown` (one of "cunning", "glory", "honor",
  "purity", "wisdom"), `skills` (three Skill ids, e.g. "animal-ken"), `huntersAspect` (`{ "name", "condition" }`,
  the condition's id), `moonGift` (a gift id), `giftAffinities` (Shadow Gift ids), `benefit` (`{ "name", "summary",
  "page" }`, the Auspice Benefit every member has).
- **tribes**: `kind` ("forsaken", "ghost-wolf" or "pure"), `renown` (absent for Ghost Wolves and the Pure),
  `giftAffinities` (Shadow Gift ids; empty when the book gives none), `oath` (`{ "name", "summary" }`, the tribal
  vow, or the Pure tribe's restriction), `firstTongueName` (optional).
  Optional, where the book gives them (e.g. the Pure in Night Horrors: Shunned by the Moon): `secondaryRenown` (the
  Renowns a second creation dot may go to), `skills` (tribe Skills, ids), `huntersAspects` (`[{ "name", "condition" }]`
  to choose from, for tribes without an auspice).
- **lodges**: as tribes' optional extras: `tribes` and `auspices` (ids it's limited to, empty for any), `requirements`
  (free text), `benefit` (free text). The core book's lodges have only `summary`.
- **archetypes**: `kind` ("blood" or "bone"); `summary` says how it regains Willpower.
- **gifts**: `kind` ("moon", "shadow" or "wolf"), `auspice` (for a Moon Gift; an auspice may have several, e.g.
  alternates, and its `moonGift` names the core one), and `facets`, each with `id`,
  `name`, `source`, `summary`, and either `renown` (Shadow and Wolf Gifts) or `dots` (1–5, Moon Gifts), plus optional
  `cost` (e.g. "1 Essence"), `action` ("instant", "reflexive", "contested", "extended"…), `dicePool` (e.g.
  "Wits + Investigation + Cunning") and `duration`.
- **rites**: `kind` ("wolf" or "pack"), `rating` (1–5), and optional `action`, `dicePool`, `targetSuccesses`,
  `duration`.
- **merits**: Requiem's Merit entry. Categories: "werewolf", "human" (only humans can take them, e.g. the Church of
  the Wolf's; listed but unavailable to werewolves), "fighting", "mental", "physical", "social", "other".
  Prerequisite kinds include Requiem's shared ones (attribute, skill, merit, willpower, other) and Forsaken's:
  `renown` (id = the Renown, minimum = dots), `primalUrge` (minimum), `harmony` (minimum), `tribe`, `auspice`,
  `notTribe` (id = tribe).
- **conditions**: Requiem's Condition entry, which may have `noteOptions` (see `docs/phase-b-design.md`). Siskur-Dah
  uses them for the ritemaster's tribe, with `group` "forsaken" or "pure"; each option has its own `source`.
- **kuruthTriggers**: the book's trigger sets (p. 103), each with `passive`, `common` and `specific` text.
- **fetishes**: `kind` ("fetish" or "talen"), `rating` (1–5), and optional `spirit` (the kind of spirit bound in it),
  `activation` (e.g. "Spend 1 Essence" or "Roll Harmony"), `effect`.
