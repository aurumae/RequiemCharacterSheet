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
| Section headings | Flat Earth Scribe | **Trade Winds** (OFL), a stand-in while the user asks the designer about a licence |
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
