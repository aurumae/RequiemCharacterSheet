# Design decisions

Product decisions about how the app works, made by the user. They apply to both the iOS and Android apps and to
everything added later. Add new decisions at the bottom, with the date.

## Official content is grouped by book, with no way to switch books off (2026-11-10)

Every list of official options is split into sections by the book the options come from. Each book's content
sits under a heading with the book's name, e.g. "A Thousand Years of Night". The books follow catalog order, with
the Requiem core book first. This covers:
- Masks and Dirges, Clans, Bloodlines and Covenants;
- Disciplines, Devotions, Merits and Banes;
- blood sorcery (Crúac and Theban rituals), Mysteries, Coils and Scales;
- Conditions;
- and any new kind of list added later.

Groupings a list already had stay, but inside each book. Examples are Merit categories, rituals by Discipline and
Scales by Mystery.

The Discipline list is an exception. The in-clan Disciplines of the character's clan, or of their bloodline if they
have one, are always shown at the top in an "In-clan for the …" section, whichever books they come from. Every
Discipline, in-clan ones included, is then listed again under its book. "Recently Used" Conditions and the Custom options sit
outside the book sections. Each option also keeps its "Book, p. N" citation.

Content from a new book must go under its own book section in every list it adds to.

**Players exclude books only by seeing which book an option comes from and choosing not to pick it.** There are
no per-book toggles, filters or settings, and none should be added.

## Separate apps for each game line, on a shared base (2026-11-12)

Each Chronicles of Darkness game gets its own app: "Requiem Character Sheet" for Vampire and "Forsaken Character Sheet"
for Werewolf. They share the game-neutral code (Attributes, Skills, Merits, Conditions, tracks, Experiences, catalogs,
saving) but have their own sheets, catalogs, themes and store listings. A character belongs to one game and opens only
in that game's app. See `docs/multi-game-plan.md`.

## Werewolf: Wolf Gift Facets cost 1 Experience (2026-11-12)

The Forsaken core book gives 1 in the quick reference (p. 84) and 2 in the text (p. 85). The user ruled for **1**.


## Each app's look follows its own official sheet (2026-11-15)

The app began as the official character sheet turned from three columns into one, scrolling on a phone. Matching each
official sheet closely is a design goal. Some loss of legibility in labels is accepted for it, as on the printed sheets.
Controls such as the section pill must stay easy to read.

Each game's official character sheet presents its sections differently, so the section-header design belongs to each
app and is not shared:
- **Requiem** adapts the solid dark bar with white text from the Vampire sheet.
- **Forsaken** uses the Werewolf sheet's rough dashed brush line, broken by the heading.

Future games will need their own design too. The shared interface code provides the slot for a header and each app
fills it. Forsaken's dashed lines are drawn in code, not copied from the sheet artwork. A fixed random seed keeps them
the same on every launch. They are tinted with the theme colour, and Android can reproduce them from the same
algorithm.

Fonts follow the same approach: free fonts are chosen to stand in for each official sheet's commercial ones. The
Storyteller's Vault template fonts are not licensed for use in an app. Forsaken's fonts (2026-11-15):

| Role | Official sheet | Forsaken app |
|---|---|---|
| Section headings | Flat Earth Scribe | **Flat Earth Scribe** itself, as pictures (see below) |
| Subheadings and labels | Treefrog | **Comforter** (OFL) |
| Trait names | Arnova ITC | **Grechen Fuemen** (OFL) |
| Small print | Goudy Old Style | the system font |

On the Forsaken sheet, as on the official one, trait names are black and labels and subheadings are in Werewolf Rust.
The section pill is filled in Werewolf Rust with its text in Grechen Fuemen, because it must be easy to read; Requiem's
pill font happens to be readable already. The wolf skull from the app icon sits behind the sheet as a faint Werewolf
Rust watermark, as it does on the official sheet. There is no page border.

Forsaken's About page uses the system font, in Werewolf Rust at the same sizes, so the licences and notices are easy
to read. The About button on the list keeps Comforter. The pill's Grechen Fuemen is set larger (21pt) than Requiem's
pill face, as its letters are small for their size.

BushToad is not used. It's an unlicensed 1999 imitation of Treefrog ("BushToad by Three Mile Island"), and its owner
is unknown.

## Signature colours (2026-11-15)

- **Vampire Red** (Requiem): #581A12.
- **Werewolf Rust** (Forsaken): #855A4A, taken from the official Werewolf sheet. It has 5.9:1 contrast on white, so it
  is fine for small text.

## Skull watermark behind the sheet (2026-11-15)

Both apps show their game's skull faintly behind the character sheet, in the signature colour at about 7% strength.
It stays fixed while the sheet scrolls, centred in the list area below the logo. It appears only on the sheet, not on
the character list. Requiem uses its app-icon skull and Forsaken uses the wolf skull.

## Forsaken: what the app covers (2026-11-15)

- **Character kinds.** Forsaken werewolves (five tribes, five auspices), Ghost Wolves (no tribe; 2 Renown at
  creation; no 2-dot Moon Gift at the start, p. 50) and the Pure (Fire-Touched, Ivory Claws, Predator Kings: no auspice
  or Moon Gifts, an extra Shadow Gift, a bonus Totem dot, pp. 197–198). Wolf-Blooded characters aren't covered.
- **Essence.** A new character starts with 7 Essence (p. 84); the Primal Urge table (p. 93) sets the maximum.
- **Lodges** work like Requiem's Bloodlines: chosen from a list grouped by book, or typed as a custom lodge. The core
  book's lodges are story only (pp. 51–53); later books' lodges, with their rules, join the list when we add them.
- **Fetishes and talens** have their own section: the core book's samples (pp. 147–149) or the player's own, with
  rating and Essence notes.
- **Wolf Gift Facets cost 1 Experience** (decided 2026-11-12; see above).

## Unofficial content is optional, per character (2026-11-16)

Catalogs can include unofficial content: fan-made material and the publisher's design previews, such as the Giver
of Gifts articles on the Onyx Path blog. A catalog marks its book `"official": false`. Every app has an **Unofficial
Content** switch on the character sheet, saved with each character and off by default. While it's off, every picker
on that sheet leaves unofficial books out; while it's on, they appear after the official books, under their name and
"(Unofficial)". Official books are always shown and still can't be switched off. Turning the switch off doesn't
remove anything the character already took. An unofficial entry is cited by its URL if it has one.

The switch appears once an app has unofficial content. Forsaken has it now; Requiem will show it when its first
unofficial catalog is added, which needs a Requiem save-format key.

## Werewolf: Moon Gifts come with auspice Renown, and can be swapped (2026-11-16)

The sheet splits Gifts into Moon, Shadow and Wolf sections. The Moon Gifts section is left out for the Pure. A
character's Moon Gift Facets aren't bought: each dot of auspice Renown unlocks the next. The Moon Gift is the
auspice's own by default, but the player can choose another, e.g. an alternate Moon Gift shared by the developers or
fans, or write their own. Changing auspice goes back to the new auspice's own Moon Gift.

## Search treats every kind of apostrophe and quote alike (2026-11-16)

Every search in every app matches straight and curly apostrophes and quotes against each other, as well as ignoring
case and accents, so what the keyboard types always finds the catalog's text.

## Werewolf: the sheet keeps easily forgotten rules in view (2026-11-16)

- **Auspice Benefit.** A section after Renown shows the character's auspice benefit, e.g. the Rahu's Tenacious. The
  Pure, who have no auspice, don't have the section.
- **Kuruth triggers.** The player picks one of the book's trigger sets (Blood, Moon, The Other, Pack, Territory,
  Wounds) or writes their own. Its Passive, Common and Specific triggers are shown, muted when the character's
  Harmony means they don't apply: all apply at 0 and 10, Common and Specific at 1, 2, 8 and 9, only Specific at 3, 4,
  6 and 7, none at 5. The general triggers every werewolf has are listed below.
- **Siskur-Dah.** The player chooses the ritemaster's tribe, as the character didn't necessarily lead the rite, and
  the card shows that tribe's effect. The other faction's tribes (Pure for the Forsaken, Forsaken for the Pure) are
  offered in a separate section marked as the character's enemies, as the two sides rarely hunt together.

## Werewolf: going past a trait's limit stacks by source (2026-11-16)

Several rules let a trait go "one dot above the normal limit", e.g. a totem's Attribute or Skill advantage and
Embodiment of the Firstborn. The book doesn't say what happens with more than one. The user's ruling: **each source
allows one dot past the limit, and different sources stack.** One source doesn't stack with itself: however many
dots of a trait a totem grants, it allows only one past the limit.

The sheet shows every dot. Bought dots are Werewolf Rust and bonus dots are black, and any dots past what the sources
allow are faded and don't count. Example: Strength 5 at Primal Urge 1 with two totem dots shows 7 dots, the last
faded; adding Embodiment of the Firstborn (Strength) shows 8, the last faded; Primal Urge 6 makes them all count.

## Werewolf: the pack totem (2026-11-16)

The Totem section has the totem's name, Aspiration (a fourth Aspiration for every pack member) and ban. The player
enters the pack's total Totem points, any number, because points are pooled and the other characters aren't on the
sheet. The points set the Experiences for advantages (1, 3, 5 or 10, p. 92), which the player spends on Attribute or
Skill dots, Specialties and Merits. Every pack member gains them. Totem Merits ignore prerequisites, and totem
Attribute and Skill dots follow the limit rule above. A Merit the totem grants gets a row in Merits, its granted
dots in black after any the character buys in Werewolf Rust, so the two can be combined.

## Werewolf: guided creation (2026-11-16)

Forsaken offers guided creation like Requiem, with the same hard limits, following the core book's quick reference
(pp. 82–84) and, for the Pure, Night Horrors: Shunned by the Moon's (p. 202):
- Attributes 5/4/3 and Skills 11/7/4 by priority; three Specialties; a free dot in one of the auspice's Skills (a
  Pure tribe's Skills for the Pure).
- Choosing an auspice asks which of its Skills takes the free dot, and the auspice's and tribe's Renown dots are
  filled in automatically and can't be removed; they move if the auspice or tribe changes.
- Renown: the auspice's, the tribe's and one more, none above two. **Ghost Wolves** have no tribal Renown, so they
  get two dots. The Pure get the tribe's primary Renown and a dot in it or a secondary Renown.
- Gifts: one Facet each of two Shadow Gifts from the tribe's or auspice's (Ghost Wolves: one Facet, of the
  auspice's; see "Werewolf: starting Shadow Gifts" below), and a Wolf
  Facet unless two dots of auspice Renown bring the Moon Gift's second Facet. The Pure take two Facets of the tribe's
  Gifts, one of any Shadow Gift and one Wolf Facet. A Facet needs a dot of its Renown.
- Rites: two dots, and up to five more for a Merit dot each.
- Merits: ten dots, also paying for extra Rites and Primal Urge (five a dot, up to 3). Every character gets a free
  Totem dot (two for the Pure) and Language (First Tongue). Harmony starts at 7.

## Werewolf: Gifts and rites that change the sheet (2026-11-16)

A Facet or rite that changes a trait is counted on the sheet. Passive ones always count, e.g. Warrior's Hide (Purity
to Health), Rabid Fever (Purity to Initiative), Zeal (Purity to Willpower, which may pass 10) and Primeval Echo
(Purity to the Essence maximum). Ones that are used, e.g. Primal Strength or Totemic Empowerment, have a switch on
their row; while it's on, their dots show in black on the Attribute or Skill and count in derived traits and dice
pools, past the usual maximum. The Advantages table also shows Armor (general/ballistic, with Fortified Form in its
form) and the Brawl pool in every form, and Weaponry and Firearms pools in Hishu and Dalu for a character with dots in
them.

## Werewolf: Facets learned with Renown (2026-11-16)

In XP Mode, each Renown dot gained lets the character learn one Facet of that Renown free, in a Gift they've
unlocked (one whose Facet they know, or any Wolf Gift) (p. 115). The Gift sections show the free Facets waiting, and
the picker marks the Facets they can go on. Shadow and Wolf Facets are listed under their Gifts.

## Werewolf: section headings are pictures in Flat Earth Scribe (2026-11-16)

The user bought Blambot's Basic Desktop licence for Flat Earth Scribe (Nate Piekos), which covers the font
"flattened into graphics" but not embedded in an app (that's a separate, much dearer licence). So the font file is
**never** added to either app or the repo. `scripts/render-forsaken-headings.swift`, run on the user's Mac with the
font installed, draws each Forsaken section heading as filled outlines into a vector PDF in
`ForsakenCharacterSheet/Assets.xcassets/Section Headings`. The app tints them Werewolf Rust, scales them with the
text size and gives them their heading as an accessibility label. A new or renamed section needs the script run
again; a test checks every heading has its picture. Text that isn't a fixed heading, such as book names in pickers,
uses Grechen Fuemen instead (Comforter is too hard to read there). About credits the font.

## The app is one player character's sheet (2026-11-16)

Each app covers a single player character. Things that live at the level of the group are out of scope: Forsaken has
no Pack section, so The Pack's Pack Merits, Pack Tactics, Hunting Nature, pack Aspirations, Touchstones and
Experiences aren't in the app. The pack totem is the exception, because its Aspiration, ban and advantages apply
directly to the character and change their sheet.

## Second Edition only (2026-11-16)

Both apps follow the Second Edition rules and take content only from Second Edition books. First Edition books, such
as Lodges: The Faithful, aren't sources, even where a Second Edition book covers the same ground more briefly.

## Tilts are in the catalog; combat tools come later (2026-11-16)

Forsaken's catalogs hold Tilts as a kind of their own, starting with the core book's eight (pp. 312–313). The sheet
doesn't track them yet. After the first App Store release the user intends a system for combat: dealing damage,
applying Tilts, healing, working out dice pools, wearing equipment and so on. Tilts, weapons and armour wait for it.

## Era content is grouped by its book; an era selector comes later (2026-11-16)

Dark Eras content goes into Forsaken under its own books, including Gifts that stand in for a modern one, such as the
Viking-age Gift of Technology. Grouping by book is how a player leaves content out: if a book isn't relevant or
permitted, they don't choose from it. Later, an era selector will change the Skill list and flag options that don't
suit the chosen era.

## Werewolf: starting Shadow Gifts (2026-11-16)

- A new character's two Shadow Facets come from **two different** Gifts (pp. 83–84). Guided creation refuses a
  second Facet of the same Gift. The Pure's two tribe Facets may share one (Shunned by the Moon, p. 202).
- **Ghost Wolves start with one Shadow Facet**, from their auspice's Gifts. Chapter One says so (p. 50); Chapter
  Three's quick reference implies two for everyone. The user's ruling is that Chapter Three is mistaken.

## Wounds outlast the Health boxes they were in (2026-11-16)

When a character loses Health boxes, e.g. a werewolf shifting to a smaller form, the wounds in them aren't lost. Each
one upgrades the least severe wound left, from the left: bashing to lethal, lethal to aggravated (p. 172). A wound
finds an empty box first. The sheet does this as the form changes, and the wounds don't come back if the boxes do.

## The sheet works out Experience costs (2026-11-16)

In XP Mode the sheet charges what the rules say, as accurately as it can, and doesn't leave a cost for the player to
adjust by hand. Where a cost depends on who the character is, the sheet applies it.

## Werewolf: lodges with rules (2026-11-16)

- **What a lodge gives.** The Pack's lodges mark each adherent with a Blessing, one more Aspiration and a Ban
  (p. 80). A character in such a lodge gets a Lodge section, after the Auspice Benefit, with those three, the lodge's
  Sacred Hunt and what it teaches. The core book's lodges are story only and get no section.
- **Who can join.** The books describe who usually joins a lodge; they set no requirement. The lodge's summary says
  who they are, and the picker offers every lodge to every character.
- **The same lodge in two books.** The Eaters of the Dead are in the core book as story only and in The Pack with
  rules. They are listed under both, so a table that doesn't use The Pack still has the core book's.
- **Lodge lore.** A Merit or rite a lodge teaches shows that lodge as a prerequisite. A werewolf outside it can still
  learn it, and XP Mode charges three times the usual cost (p. 80): 3 Experiences a dot. What was paid is what's
  refunded, whatever the character's lodge is by then.
- **Sacred Hunt.** A ritemaster may give their lodge's benefit in place of their tribe's, to everyone on the hunt. So
  Siskur-Dah offers the lodges to every character, in a group of their own.

## Werewolf: Ghost Wolves follow Chapter One (2026-11-16)

Where the core book's Chapter Three conflicts with Chapter One about Ghost Wolves, Chapter One is right (p. 50). They
start with one Shadow Facet, and can't start with their Moon Gift's second Facet. A dot of auspice Renown always
brings its Moon Gift Facet (p. 115), so guided creation keeps a Ghost Wolf's auspice Renown at 1: their other Renown
dot goes elsewhere.

## Dark Eras is cited by the full books' pages (2026-11-16)

As in Requiem, Dark Eras content is cited to the collected books (Dark Eras, Dark Eras Companion, Dark Eras 2) with
their page numbers, not to the chapters sold on their own, whose pages differ. The user supplies the pages.

## What's in the book goes in, worded with care (2026-11-17)

If a Second Edition book the app covers prints a trait a player character can have, the app includes it. That holds
for Conditions that belong to optional rules, or that sit in pages shared with another game, and for lodges with no
rules, which are listed with a summary as the core book's are.

Where a book's own wording is harsh, ours is brief and plain: enough to use the trait, with the page for anyone who
wants the full context. Example: the Viking-age Ergi Condition is described as an accusation of unmanliness, and
leaves the rest to Dark Eras, p. 164.

## Werewolf: Dark Eras content (2026-11-17)

- Dark Eras content is in three books of Forsaken's own: Dark Eras, Dark Eras 2 and Dark Eras Companion, cited by
  the full books' pages.
- **The Viking-age Gift of Technology** is its own Gift, listed under Dark Eras, with the same name as the modern one
  it stands in for. A tribe's or auspice's affinity for Technology covers both. Nothing stops a character learning
  from either: the player chooses by book until there's an era selector.
- **Sigrblot is a Pack Rite.** The book doesn't say; it's performed for the pack's territory before a raid.
- Era creation rules, weapons and armour wait for the era selector and the combat tools.

## Werewolf: the Pure are created by Shunned by the Moon (2026-11-17)

Night Horrors: Shunned by the Moon (p. 202) explicitly updates and replaces the Pure's creation rules in the Dark Eras
Companion (Forsaken by Rome, p. 78). So a Pure character starts with two Renown dots, the tribe's primary and one in
it or a secondary Renown, and a free dot in one of the tribe's Skills, not the three dots and two Skills of the older
book.

## Werewolf: twenty Totem points give five Experiences (2026-11-17)

The totem table (p. 92) puts 20 points in both the "15–20" row and the "20+" row. The user's ruling: exactly 20 is
five Experiences; ten starts at 21.

