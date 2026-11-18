# Forsaken Android visual reference

The user supplied the iOS 1.0 screenshots on 18 November 2026 because the Android
preview does not yet look right. They are the visual reference for subsequent
Android work, alongside the Swift views and [standing design decisions](design-decisions.md).
The ordinary-play preview has functional coverage; its appearance is not accepted.
This review does not change application code or claim visual parity.

## Sources and comparison limits

All 22 PNG screenshots were inspected in these two local folders, outside Git:

- `/home/oisin/RequiemCharacterSheetApp/Forsaken iOS Screenshots/1.0 (6.9-inch 1320x2868)/`
- `/home/oisin/RequiemCharacterSheetApp/Forsaken iOS Screenshots/1.0 extras (6.9-inch 1320x2868)/`

Each is 1320 × 2868. `04-advantages.png` and the extras' `advantages.png` are
byte-identical, leaving 21 distinct views. Ignore the archive's `__MACOSX` metadata.
The images remain outside the repository; the existing logo, watermark, fonts and
heading outlines remain the application's assets.

The two retained Android captures (`/tmp/forsaken-phase3-sheet.png` and
`/tmp/forsaken-phase3-advantages.png`) show the previous candidate at 150% text.
They expose layout differences, but are not a matched-scale pixel comparison.
No new Android screenshots or physical-device tests were taken for this review.
Screenshot character values also differ from the immutable save fixtures. Recreate
visual examples separately; never change a fixture or rule to match a pictured number.

## Composition to carry forward

The sheet is white, with fine grey rules and broad rows. Werewolf Rust (`#855A4A`)
is used for labels, subheadings, selected controls and bought dots; trait names and
bonus dots are black. Secondary rules and metadata are grey. The fixed logo has
substantial visual weight above the scrolling content. The wolf skull stays faint,
fixed and centred in the list area, with no page border and no watermark in the library.

The toolbar preserves the back action, readable rust section pill, XP and Save.
Section headings are the supplied Flat Earth Scribe outlines between seeded brush
strokes. Keep their proportions and whitespace. iOS's glass navigation chrome is
platform presentation; use native Android interaction and accessible controls while
matching the sheet's hierarchy and placement.

The reference font roles are distinct. These are Swift's base point sizes, not
measurements to copy from a 1320-pixel screenshot:

| Role | Reference |
| --- | --- |
| Fixed section headings | Existing vector heading art, rust; scale with text size |
| Labels, including Name/Essence/Beats | Comforter, 30, rust |
| Subheadings, including Mental and Gift names | Comforter, 32, rust |
| Rated traits, including Attributes/Skills/Renown | Grechen Fuemen, 23, black |
| Other trait names, including Facets | Grechen Fuemen, 21, black |
| Section pill | Grechen Fuemen, 21, white on rust |
| Entered values, explanatory text, citations | System font, with body/detail/note hierarchy |

Use `ForsakenIdentity.swift`, `Theme.swift` and the individual Swift views to resolve
roles. Android currently has one `trait` style and chooses label versus trait styling
from the presence of a click callback; this must become an explicit visual role.
Also separate numeral substitution from the subheading font: Forsaken's Swift theme
has no numeral override, while Android's shared `SheetText` currently substitutes
Comforter for digits in Grechen Fuemen text. Preserve Requiem's own typography.
Never bundle Flat Earth Scribe or Trade Winds. Do not regenerate heading artwork
for this correction; Claude has accepted the current raw-resource loader.

## Specific corrections identified

| Reference screenshots | Current Android difference | Required direction |
| --- | --- | --- |
| `00-characters`, `02-sheet` | `LogoHeader` constrains every logo to 184 × 108 dp; the wide Werewolf artwork is visibly undersized. Library uses shared `SectionBand("CHARACTERS")`. | Give each game appropriate logo sizing. Swift fits the logo at 100 pt high. Add a game-supplied library header: the screenshot's Characters heading is Grechen Fuemen with brush strokes. Keep rust character names, black summaries, grey edited times and the About label. |
| `02-sheet`, extras `totem`, `harmony`, `experience` | `PlayChoice` always puts a Choose button beside the label, then the value below. Text fields and counters stack whenever text scale exceeds 1.3. Character puts Concept before Blood/Bone. | Restore label-left/value-right rows with a small selection affordance, and the Swift field order. Make reflow depend on available space and content. Preserve readable large-text editing and keyboard reveal. Counter layout should read label, decrease, value, increase. |
| Extras `attributes`, `skills`, `merits`; `05-renown` | `TraitRatingControl` styles most rated names as rust Comforter. Merits repeat their name in an entry header and rating row. Skill penalty text is folded into the decorative category heading. | Use black Grechen Fuemen rated names with aligned dot columns, one title per row, supporting text below, and penalties in muted system text. Keep bought/bonus/faded-dot semantics and accessible rating menus. |
| Extras `primal-urge`, `harmony` | The generic control repeats the section name and limits each row to five dots. | Use the reference's section-level ten-dot track when space permits, followed by the rule summary and related fields. Maintain accessible overflow/reflow and all saved ratings. |
| `03-forms` | Form selection is a generic choice dialog. | Show all five forms in a segmented selector, then the black form name, modifier line and muted rules. Retain native accessible selection and narrow-screen adaptation. |
| `04-advantages`, extras `advantages` | `FormAdvantages` emits five paragraphs of values. | Build the five-form comparison table: rust row labels, aligned numbers, selected form capsule and distinct current-form numbers, armor pairs, combat pools and conditional notes. Keep an accessible per-form summary. |
| `06-moon-gifts`, `07-shadow-gifts`, extras `rites` | Generic headers, notes and action rows split information that the reference groups; Gift counts sit below headings. | Place name and dots/count on the same row, metadata below, then a worked pool with the dice count emphasized in rust. Group owned Facets under their Gift, mute locked Moon Facets, and keep active switches attached to their power. Avoid duplicate titles and repeated “Read details” prompts. |
| `08-facet-picker` | Android uses a white flat list, top outlined search, rust book headings and compressed price metadata. | Preserve book → Gift → Facet hierarchy: muted Grechen book headings, rust Comforter Gift/affinity headings, grouped white choices on a pale surface, clear cost, prerequisites and citation. Retain search access while scrolling/typing; test placement against Android IME/insets. |
| `09-conditions` | Conditions are long inline editors with several actions. | Use the horizontal card presentation and full-card details: rust title strip, persistence badge, note, effect, Resolution/Beat, position hint and Add Condition. Keep resolution/Beat actions accessible and preserve the current save/event pipeline. |
| Extras `kuruth`, `lodge`, `totem`, `experience` | Generic `PlayInfo` makes rule labels look like trait names; counters and summaries differ in grouping. | Use rust labels and black values/body, muted inactive Kuruth triggers with their reason, distinct lodge facts, Totem budget/grants, and a Change Log row with its count. |
| `01-guided-creation`, extras `creation-attributes` | Creation remains read-only. | Keep these as phase-4 references: checklist/progress, section jumps, category priority/remaining dots and unavailable-dot state. Do not expose an incomplete creation editor during the visual correction. |

### A rules reminder revealed by the comparison

Android's Advantages reminder is currently hard-coded to Dalu and always includes
the Pure silver warning. Swift's `AdvantagesView.notes` is conditional: Firearms
Defense names the current form only in Dalu/Gauru/Urshul; the claw/teeth Initiative
note appears in Gauru; the silver note appears only for the Pure. Match this source
when correcting Advantages. This is an Android presentation bug, not a new rules
question or permission to alter the reference.

## Implementation order and acceptance

1. Before the next candidate, port Claude's confirmed custom-Wolf price and
   Totem-granted Merit fixes, with the price text and historical refunds checked.
2. Correct theme roles, logo/library header, field/counter layout, rated rows and
   spacing. Supply per-game styling through shared components; retain Requiem's look.
3. Restore form selection, the Advantages table, Gift/rite grouping and picker
   hierarchy, then Conditions cards. These are phase-3 ordinary-play corrections,
   alongside the agreed contract work, before adding phase-4 creation UI.
4. Capture a representative library, Character, Attributes, Advantages, Gifts,
   picker, Conditions and counter screen at a comparable logical width and normal
   text size. Compare with the named iOS references, then repeat on a narrow phone,
   at 150% text, in landscape and with the keyboard open. Inspect actual renders,
   not only source values or successful interaction tests.
5. Check typography roles, alignment, heading/brush proportions, logo and watermark
   placement, state styling and readable controls. Keep targeted tests for behavior
   affected by new layouts: purchases/refunds, dot selection, form changes, Condition
   actions, section jumps and keyboard focus. Physical TalkBack and cross-device
   transfer remain acceptance work; static screenshots cannot prove either.

See [the port plan](android-forsaken-plan.md) for phase dependencies and the revised
SwiftPM contract/exchange coordination. This visual review is not a claim that the
ordinary-play UI already matches iOS or that phase 3 is complete.
