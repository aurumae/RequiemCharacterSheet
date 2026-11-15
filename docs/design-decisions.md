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
