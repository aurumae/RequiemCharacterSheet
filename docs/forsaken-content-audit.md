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

## Wrong in the app, not yet fixed

| What | The book | Checked |
|---|---|---|
| Ghost Wolves start with two Shadow Facets | One Shadow Gift only, and no Gift affinities of their own (p. 50) | ✔ |
| Two starting Shadow Facets may come from one Gift | One Facet each of two Shadow Gifts (pp. 83–84) | ✔ |
| A Ghost Wolf can reach the two-dot Moon Gift at creation | Can't start with it (p. 50); the reader found no check in the creation code | ✔ text |
| The totem's Merit picker offers Totem and Dedicated Locus | A totem can't grant either (p. 92) | |
| Totemic Empowerment gives +1 to three Attributes only | Also +5 to the Essence pool and +2 to Perception (p. 143) | |
| Unseen Sense is a Mental Merit a werewolf can take | Humans only (p. 113): it belongs in the `human` category | |
| Brawl pool with no Brawl dots is just Strength | −1 die untrained (pp. 154, 160); Requiem applies this | |
| Damage in Health boxes a smaller form doesn't have is hidden, and lost on saving | The remaining wounds are upgraded (p. 172) | |
| Ghost Wolves' oath summary says they may still follow the Oath of the Moon | Not in the text (pp. 49, 77) | |
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

- **Lodge of the Field** (pp. 274–277): the only core lodge with rules; adds Primal Urge to the Essence maximum.
  Story-only lodges the app lacks: the Dreaming Lodge (pp. 266–267), the Lodge of Quicksilver Children (p. 216).
- **Voyager Membership** (p. 272): a 1–5 dot Merit for humans.
- **Ghost Wolves' First Tongue name**, Thihirtha Numea (pp. 250, 252).
- **The Pure and silver** (p. 198): touching silver does 1 bashing a turn, 1 lethal on full-moon nights. A reminder.
- **Tilts (8, pp. 312–313):** Arm Wrack, Blinded, Earthquake, Heavy Winds, Knocked Down, Leg Wrack, Poisoned,
  Stunned. The app has no Tilts, though its own text names several.
- **Conditions (3, optional, pp. 294–295):** First, Second and Third Trimester.
- **Rite details:** each rite's symbols, sample dice pool, time per roll and Essence cost (the detail view shows
  none of them).
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

## Decisions needed (user)

1. **A Pack section.** The Pack is mostly about the pack, not the werewolf. Does the sheet gain a Pack section
   (Aspirations, Touchstones, Complications, Hunting Nature, Pack Merits, Pack Tactics, Beats and Experiences), kept
   on each character as the Totem is?
2. **Lodges with rules.** New lodge fields and a Lodge section. The Eaters of the Dead are in the core book as
   story only and in The Pack with rules: one entry or two? Are lodges limited by tribe where the book only
   describes who joins? Is the triple cost enforced, shown, or left to the player?
3. **Lodges: The Faithful** is a later lodge book the user owns. Does it replace The Pack's lodge rules?
4. **Tilts.** Add them as a kind, or keep them out as in Requiem?
5. **Dark Eras.** Is era content wanted in the first release? Official books can't be switched off, so a legion rite
   or a Viking Gift would show for every character; the era Gift of Technology needs a way to replace the core one.
   Which pages are cited: the stand-alone PDFs' or the collected books'?
6. **Ghost Wolves at creation:** one Shadow Facet, as p. 50 says?
7. **Pure creation.** Forsaken by Rome (p. 78) gives the Pure three Renown dots and a free dot in two tribe Skills.
   The app gives two and one, from Shunned by the Moon's quick reference (p. 202), which says it updates those
   rules but is silent on both points.
8. **Totem points of exactly 20:** five Experiences or ten?
9. **Equipment.** Weapon and armour tables, with armour's penalties applied to Defense and Speed?
10. **Optional rules** (the trimester Conditions, the Punk Generation and others): in the pickers or not?
