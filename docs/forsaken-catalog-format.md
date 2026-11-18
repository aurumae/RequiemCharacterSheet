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
  "merits": [], "conditions": [], "fetishes": [], "kuruthTriggers": [], "tilts": []
}
```

Every entry has `id`, `name`, `source: { "book", "page" }` and `summary` (one or two sentences).

`book` may have `"official": false` and a `"url"` for unofficial sources, e.g. the Onyx Path blog's Giver of Gifts
articles (`giver-of-gifts-1.json`, `giver-of-gifts-2.json`); their entries have no `page` and are cited by the URL.
Unofficial files load after all the books.

Files load in this order: `wtf2e-core`, `cofd-core`, then the other books by file name without its extension, so
`dark-eras`, `dark-eras-2`, `dark-eras-companion`, `nh-shunned-by-the-moon`, `the-pack`. Forsaken's Dark Eras files
are its own, in `ForsakenCharacterSheet/Catalogs/`; they share only their names and book ids with Requiem's.

- **auspices**: `moon` ("crescent", "full", "gibbous", "half", "new"), `renown` (one of "cunning", "glory", "honor",
  "purity", "wisdom"), `skills` (three Skill ids, e.g. "animal-ken"), `huntersAspect` (`{ "name", "condition" }`,
  the condition's id), `moonGift` (a gift id), `giftAffinities` (Shadow Gift ids), `benefit` (`{ "name", "summary",
  "page" }`, the Auspice Benefit every member has).
- **tribes**: `kind` ("forsaken", "ghost-wolf" or "pure"), `renown` (the tribe's Renown, or a Pure tribe's primary
  Renown; absent only for Ghost Wolves),
  `giftAffinities` (Shadow Gift ids; empty when the book gives none), `oath` (`{ "name", "summary" }`, the tribal
  vow, or the Pure tribe's restriction), `firstTongueName` (optional).
  Optional, where the book gives them (e.g. the Pure in Night Horrors: Shunned by the Moon): `secondaryRenown` (the
  Renowns a second creation dot may go to), `skills` (tribe Skills, ids), `huntersAspects` (`[{ "name", "condition" }]`
  to choose from, for tribes without an auspice).
- **lodges**: as tribes' optional extras: `tribes` and `auspices` (ids it's limited to, empty for any), `requirements`
  (free text), `benefit` (free text: what every adherent gains) and `effects` (what adherence does to the sheet's
  traits; "rating" is the character's Primal Urge), as the Lodge of the Field has. Most of the core book's lodges
  have only `summary`. A lodge with rules (The Pack,
  p. 80) also has `totem` (its name), the three marks every adherent bears, `blessing`, `aspiration` and `ban`, and
  what it teaches: `merits`, `rites` and `fetishes` (ids), with `tools` (free text) for what is particular to this
  lodge, e.g. the Influences its Lodge Sorcery offers. A Merit or rite listed by any lodge is lodge lore: it asks for
  one of those lodges, and costs a werewolf outside them three times the Experiences. The lodge's Sacred Hunt is a
  Siskur-Dah `noteOptions` entry with the lodge's `id` and `group` "lodge".
- **archetypes**: `kind` ("blood" or "bone"); `summary` says how it regains Willpower.
- **gifts**: `kind` ("moon", "shadow" or "wolf"), `auspice` (for a Moon Gift; an auspice may have several, e.g.
  alternates, and its `moonGift` names the core one), `replaces` (the id of the Gift an era's version stands in for,
  e.g. the Viking age's Gift of Technology in `dark-eras.json`; it has its own id and Facet ids, and counts as the
  replaced Gift in `giftAffinities`), and `facets`, each with `id`,
  `name`, `source`, `summary`, and either `renown` (Shadow and Wolf Gifts) or `dots` (1–5, Moon Gifts), plus optional
  `cost` (e.g. "1 Essence"), `action` ("instant", "reflexive", "contested", "extended"…), `dicePool` (e.g.
  "Wits + Investigation + Cunning vs Resolve + Primal Urge": the character's Attributes, Skills, Renown and Primal
  Urge joined with " + ", written as on the sheet so their dice can be counted, then " vs " or " - " and whatever
  resists) and `duration`, and `effects` (Requiem's effect objects; `"amount": "rating"`
  means dots of the Facet's Renown, or of auspice Renown for a Moon Gift), `passive` (true if always on) and
  `effectForms` (forms it applies in, if not all).
- **rites**: `kind` ("wolf" or "pack"), `rating` (1–5), and optional `action`, `dicePool` (the pool of the book's
  sample rite; each pack settles its own), `targetSuccesses`, `interval` (the time each roll takes, e.g.
  "10 minutes"), `symbols` (what the rite must show), `cost` (e.g. "3 Essence"), `duration`, `effects` (while
  switched on; "rating" is the rite's dots). The effect `{"type": "armor", "amount": …}` adds general armor, e.g.
  Raiment of the Storm.
- **merits**: Requiem's Merit entry. Categories: "werewolf", "human" (only humans can take them, e.g. the Church of
  the Wolf's; listed but unavailable to werewolves), "fighting", "mental", "physical", "social", "other".
  Prerequisite kinds include Requiem's shared ones (attribute, skill, merit, willpower, other) and Forsaken's:
  `renown` (id = the Renown, minimum = dots), `primalUrge` (minimum), `harmony` (minimum), `tribe`, `auspice`,
  `notTribe` (id = tribe).
- **conditions**: Requiem's Condition entry, which may have `noteOptions` (see `docs/phase-b-design.md`). Siskur-Dah
  uses them for the ritemaster's tribe, with `group` "forsaken" or "pure", or their lodge, with `group` "lodge"; each
  option has its own `source`, which may be another book. Options with no `group`, such as Outlaw's two kinds, are
  shown as one plain list.
- **kuruthTriggers**: the book's trigger sets (p. 103), each with `passive`, `common` and `specific` text.
- **tilts**: `kind` ("personal" for one character, "environmental" for the whole scene), `summary` (what the Tilt
  does), `cause` (how it's inflicted) and `ending` (how it ends). The sheet doesn't track Tilts yet.
- **fetishes**: `kind` ("fetish" or "talen"), `rating` (1–5), and optional `spirit` (the kind of spirit bound in it),
  `activation` (e.g. "Spend 1 Essence" or "Roll Harmony"), `effect`.
