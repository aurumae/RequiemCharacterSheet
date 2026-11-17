# Forsaken content audit (2026-11-16)

The user asked what still has to go into Forsaken before the App Store. Three sources were read in full, about 700
pages: **The Pack** (not in the app yet), the Werewolf chapters of **Dark Eras** (seven chapters, not in the app),
and the **core book** (largely in the app; read to find what is missing and to check what is there).

Nine readers took a part each and compared it with the catalogs and code. Items marked **✔** were then checked
against the book's text by Claude. The rest is a reader's finding: read the page again when acting on it. The
readers' full notes are kept on the user's Mac, not in this repository.

Pages are the book's printed pages. The Dark Eras chapters are stand-alone PDFs with their own page numbers, which
differ from the collected books' (see "Decisions needed").

## Fixed with this audit

- **✔ Defense against Firearms in Urhan.** The Advantages note said Defense applies against Firearms in every form
  but Hishu. Urhan doesn't apply it either (p. 166; pp. 96–98).
- **✔ Four auspice benefit pages** were one too low: Cahalith 18, Elodoth 22, Irraka 26, Rahu 32.
- **✔ Iron Masters' summary** named the wrong prey. They hunt humans, and supernatural beings hiding among them
  (p. 44).
- **Storm Lords' oath** had dropped a word: "to witness or to tend" (pp. 46, 47, 71).

Fixed afterwards, on the user's say (all ✔):

- **Ghost Wolves start with one Shadow Facet** (p. 50), not two. The user ruled that Chapter Three's quick reference,
  which implies two, is mistaken.
- **The two starting Shadow Facets come from two different Gifts** (pp. 83–84).
- **The totem's Merit picker** no longer offers Totem or Dedicated Locus (p. 92).
- **Brawl pool:** a die off with no Brawl dots (p. 154).
- **Wounds in Health boxes a smaller form doesn't have** upgrade the wounds left (p. 172), where they used to be
  hidden and then lost on saving.
- **Totemic Empowerment** also adds 5 to the Essence pool (p. 143); its summary gives the +2 to Perception rolls.
- **Unseen Sense** is in the `human` category (p. 113), so a werewolf can't take it.
- **Ghost Wolves' oath summary** no longer says they may follow the Oath of the Moon (pp. 49, 77).
- **Tilts:** the core book's eight are in the catalog as a new kind (pp. 312–313).
- **Ghost Wolves can't start with the Moon Gift's second Facet** (p. 50): guided creation keeps their auspice Renown
  at 1.

**Dark Eras is in** (`dark-eras.json`, `dark-eras-2.json`, `dark-eras-companion.json`), with the full books' pages
from the user: the Viking-age Gift of Technology and its five Facets, two rites, five fetishes, Rune Caster, the
Berserker archetype, five Conditions, four Tilts and two story-only lodges. Era creation rules, weapons and armour are
left for the era selector and the combat tools.

**The Pack is in** (`the-pack.json`), as far as it reaches one character: its five lodges with their Blessing,
Aspiration, Ban and Sacred Hunt, six Merits, two rites, five fetishes and the Essence Bleed Tilt. The sheet has a
Lodge section, and XP Mode charges a werewolf outside a lodge three times the cost of its Merits and rites.

## Wrong in the app, not yet fixed

| What | The book | Checked |
|---|---|---|
| Totem points of exactly 20 give 5 Experiences | The table puts 20 in both rows (p. 92 ✔); The Pack's 20-point sample totem spends 10 (p. 65) | ruling |

Confirmed correct, entry by entry: all 23 Gifts and 115 Facets, 23 rites, 55 Merits, 18 fetishes, 12 archetypes, 6
Kuruth trigger sets, the 39 core Conditions, the five tribes and five auspices apart from the fixes above, the Primal
Urge, form and Harmony tables, Experience costs and the Forsaken creation rules.

## The Pack (new book, `the-pack`)

**Fits the catalog as it is**

| Kind | Entries |
|---|---|
| Merits (6) | Lodge Armory (3 or 5), Lodge Connections (1–5), Lodge Lorehouse (1–5), Lodge Sorcery (3 or 5), Lodge Stronghold (2 or 4), all p. 81; the style Uma Suguthkuth (1–5; Strength 3, Brawl 4), p. 83 |
| Rites (2) | Banshee Howl (pack rite 3, p. 87); Carrion Feast (wolf rite 3, p. 91) |
| Fetishes (5) | Predator's Doom 3 (p. 83); Iron Leviathan Harpoon 2, Nomad Chain 3, Roadkiller 4 (p. 85); Glorious Lyre 3 (p. 89) |
| Conditions (5) | Hunting Nature: Human, Wolf and Werewolf (persistent, p. 104); Lost Cohesion, Lost Hunters (p. 105) |
| Siskur-Dah options (5) | One per lodge (pp. 83–91), as `noteOptions` in a new group |

**Needs new catalog fields or sheet features**

- **Lodges with rules (5):** Garm (pp. 82–83), the Thousand Steel Teeth (84–85), the Screaming Moon (86–87), the
  Temple of Apollo (88–89), the Eaters of the Dead (90–91). Each has a Blessing, an extra Aspiration, a Ban, a
  Sacred Hunt benefit and Tools (the Merits, rites and fetishes it offers). The lodge entry has none of these
  fields, and the sheet shows a lodge as one row.
- **Lodge rules for every adherent (pp. 79–81):** a lodge's Merits and rites cost outsiders three times the
  Experiences; breaking the Ban twice suspends the Blessing; Lodge Sorcery, Lorehouse and Armory need choices the
  Merit qualifier can't hold (Influences from the lodge's list, a topic per dot, three fetish weapons).
- **Pack Merits (5, pp. 29–31):** Den (1–5), Directed Rage (3–5), Magnanimous Totem (2–4), Moon's Grace (3–5),
  Territorial Advantage (1–5). They belong to the pack, which starts with five dots (p. 21). Den adds its dots to
  Defense inside the den; Directed Rage shifts the Kuruth control time the Harmony section shows.
- **The pack's record (pp. 20–21, 28–29; pack sheet in the Appendix):** three Pack Aspirations, Pack Touchstones,
  Complications, Hunting Nature with its track, a pack Willpower pool, Pack Beats and Experiences. Losing a Pack
  Touchstone is a breaking point for each packmate.
- **Pack Tactics (pp. 58–63):** a new trait the pack buys at 2 Experiences a dot, with three examples (Animal
  Magnetism 1, All Alone 3, Overkill 5) and rules for building more. A new packmate buys in at 1 Experience per two
  dots.
- **Totem (pp. 63–65):** three sample totems (Szigblal 5 points, Glabna 15, Ushugudh 20); Experiences may improve
  the totem itself (Attribute 4, Influence 5, Numen 4); two reminders on Social maneuvering for packmates.
- **Tilts:** Essence Bleed (p. 83), inside the style.

Chapter Four (three settings) and the protectorates section have no mechanics.

## Core book: missing

Added on 2026-11-17, each read again from the book first:

- **Lodge of the Field** (p. 277): the only core lodge with rules; adds Primal Urge to the Essence maximum, and has
  a Lodge section. Story-only lodges: the Dreaming Lodge (p. 266), the Lodge of Quicksilver Children (p. 216).
- **Voyager Membership** (p. 272): a 1–5 dot Merit for humans.
- **Ghost Wolves' First Tongue name**, Thihirtha Numea (pp. 250, 252).
- **The Pure and silver** (p. 198): touching silver does 1 bashing a turn, 1 lethal on full-moon nights. A line in
  the Advantages notes for a Pure character.
- **Tilts (8, pp. 312–313).**
- **Conditions (3, optional, pp. 294–295):** First, Second and Third Trimester.
- **Rite details:** each rite's symbols, sample dice pool, time per roll and Essence cost, for every book's rites,
  shown in the rite's details. Shunned by the Moon's rites give no sample pool.

Still missing:

- **Tables and rules the sheet doesn't show:** effective Spirit Rank from Renown (p. 99) and the bane rule that
  follows from it (pp. 185–186); wound penalties (p. 171), which Gauru ignores; the Primal Urge table's Basu-Im and
  hunt-time columns; shapeshifting cost by Harmony; breaking-point lists; the fetish activation pool; the tracking
  bonus, which the code holds but never shows; several form rules (Gauru's Rage, Dalu's crowd-cowing roll).
- **Can't be bought or applied yet:** a second Moon Gift with Experiences (5, then 2 a Facet); Instinctive Defense
  and Favored Form on the form table; Raiment of the Storm's armour.
- **On the printed sheet but not in the app:** the totem's spirit traits (Rank, Attributes, Influences, Numina,
  bane); a weapons table; armour's Defense, Speed and Strength lines; example Touchstones (13, pp. 87–88).
- **Equipment (pp. 169–177):** 26 weapons, 7 armours, 28 pieces of equipment. The app has no equipment list.

## Dark Eras

| Chapter (book) | For a werewolf's sheet |
|---|---|
| Forsaken by Rome (Dark Eras Companion, pp. 52–83) | Rite: Shackled Lightning (pack, 2, p. 80). Fetish: the Ivory Claws (3, p. 82). Roman weapons and armour; three legion manoeuvres. Its Pure creation rules differ from the app's (see below). |
| The Sundered World (Dark Eras; Neolithic; shared with Mage) | A creation template: no tribes, Harmony 5. One Tilt (Shattered Time). Two lodges and seven sects, story only. |
| The Bowery Dogs (Dark Eras; 1970s New York) | A free dot in Allies, Contacts, Mentor or Retainer at creation. Conditions and Tilts under optional rules (The Punk Generation, Urban Collapse, Riot). |
| The Wolf and the Raven (Dark Eras; Viking age; shared with Geist) | Merit: Rune Caster (2). Blood archetype: Berserker. A Gift of Technology for the era, five Facets, replacing the core Gift. Rite: Sigrblot (2). Four fetishes. Lodge of Muspell (story only). Conditions: Ergi, Outlaw. |
| Fear and the Golden Promise of Tomorrow (Dark Eras 2; shared with Deviant) | Nothing for werewolves beyond two general Conditions. |
| Hunger in the Black Land (Dark Eras 2; Egypt; shared with Beast and Promethean) | Three era rules (p. 34), one Tilt. No character options. |
| The Great War (Dark Eras 2; shared with Geist and Promethean) | A geist may be a totem; nothing with numbers. |

The files for The Sundered World, The Bowery Dogs, The Wolf and the Raven and Fear and the Golden Promise of Tomorrow
don't name their book; those four attributions are the readers' own and should be checked against the user's copies.

No chapter states the eras' replacement Skills, though some stat blocks use Archery and Enigmas. That rule must be in
the collected books' front matter, which wasn't among the files.

## Decided (user, 2026-11-16)

Recorded in `docs/design-decisions.md`.

- **No Pack section.** The app is one player character's sheet; group-level things are out of scope. So Pack Merits,
  Pack Tactics, Hunting Nature and the pack's Aspirations, Touchstones and Experiences stay out. From The Pack, what
  goes in is what reaches the character: the lodges and what they offer.
- **Lodges: The Faithful is First Edition** and isn't a source. The Pack's lodge rules stand.
- **Tilts go in the catalog.** A combat system that uses them, with weapons and armour, comes after the first
  release.
- **Dark Eras content goes in**, under its own books, the Viking-age Gift of Technology included. An era selector
  comes later.
- **Ghost Wolves follow Chapter One** wherever Chapter Three conflicts with it: one Shadow Facet, and no second
  Moon Facet at the start.
- **Lodges:** the Eaters of the Dead are listed under both books; no lodge is limited by tribe; the triple cost for
  outsiders is charged by the sheet.
- **Dark Eras is cited by the full books' pages**, which the user supplies.
- **What's in the book goes in**, optional-rule Conditions and story-only lodges included (2026-11-17).
- **Pure creation follows Shunned by the Moon** (p. 202), which replaces the Dark Eras Companion's rules: two Renown
  dots and one free Skill dot, as the app has it (2026-11-17).
- **Totem points of exactly 20 give five Experiences**, as the app has it (2026-11-17).

## Decisions still needed (user)

1. **Pack Merits that change the character.** Den adds to Defense in the den and Directed Rage changes the Kuruth
   control time. They are the pack's Merits, so they are out with the Pack section unless the user wants them as
   reminders.
