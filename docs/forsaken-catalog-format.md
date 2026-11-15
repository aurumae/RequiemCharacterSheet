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
  "merits": [], "conditions": [], "fetishes": []
}
```

Every entry has `id`, `name`, `source: { "book", "page" }` and `summary` (one or two sentences).

- **auspices**: `moon` ("crescent", "full", "gibbous", "half", "new"), `renown` (one of "cunning", "glory", "honor",
  "purity", "wisdom"), `skills` (three Skill ids, e.g. "animal-ken"), `huntersAspect` (`{ "name", "condition" }`,
  the condition's id), `moonGift` (a gift id), `giftAffinities` (Shadow Gift ids).
- **tribes**: `kind` ("forsaken", "ghost-wolf" or "pure"), `renown` (absent for Ghost Wolves and the Pure),
  `giftAffinities` (Shadow Gift ids; empty when the book gives none), `oath` (`{ "name", "summary" }`, the tribal
  vow, or the Pure tribe's restriction), `firstTongueName` (optional).
- **lodges**: as tribes' optional extras: `tribes` and `auspices` (ids it's limited to, empty for any), `requirements`
  (free text), `benefit` (free text). The core book's lodges have only `summary`.
- **archetypes**: `kind` ("blood" or "bone"); `summary` says how it regains Willpower.
- **gifts**: `kind` ("moon", "shadow" or "wolf"), `auspice` (for a Moon Gift), and `facets`, each with `id`,
  `name`, `source`, `summary`, and either `renown` (Shadow and Wolf Gifts) or `dots` (1–5, Moon Gifts), plus optional
  `cost` (e.g. "1 Essence"), `action` ("instant", "reflexive", "contested", "extended"…), `dicePool` (e.g.
  "Wits + Investigation + Cunning") and `duration`.
- **rites**: `kind` ("wolf" or "pack"), `rating` (1–5), and optional `action`, `dicePool`, `targetSuccesses`,
  `duration`.
- **merits**: Requiem's Merit entry. Categories: "werewolf", "fighting", "mental", "physical", "social", "other".
  Prerequisite kinds include Requiem's shared ones (attribute, skill, merit, willpower, other) and Forsaken's:
  `renown` (id = the Renown, minimum = dots), `primalUrge` (minimum), `harmony` (minimum), `tribe`, `auspice`,
  `notTribe` (id = tribe).
- **conditions**: Requiem's Condition entry.
- **fetishes**: `kind` ("fetish" or "talen"), `rating` (1–5), and optional `spirit` (the kind of spirit bound in it),
  `activation` (e.g. "Spend 1 Essence" or "Roll Harmony"), `effect`.
