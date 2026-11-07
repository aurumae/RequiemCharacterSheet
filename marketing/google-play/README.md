# Google Play listing assets

Prepared on 7 November 2026 for **Requiem Character Sheet 1.0.0-beta.1 (9)**,
package `ie.requiem.sheet`. These show the signed Android release from `f0bd5a7`,
merged in PR #4, rather than the newer iOS UI in `ac283ea`.

## Upload files

Upload `feature-graphic.png` to **Feature graphic**. Upload the eight PNGs in
`phone-screenshots/` to **Phone screenshots**, in numerical order. All upload
files are opaque, 24-bit RGB PNGs and each is under 1 MB.

- Feature graphic: **1024 × 500**.
- Eight phone screenshots: **1080 × 1920**, portrait **9:16**.
- `contact-sheet.jpg` is a review preview, not an upload screenshot.
- `source/` contains the fictional character saves, original generated artwork
  and generation prompt; these are not store uploads.
- `manifest.json` records dimensions, exact byte sizes and SHA-256 checksums.

The app icon is supplied separately by the user. No icon was generated or changed.
These files have not been uploaded to Play Console.

Dimensions and PNG format were checked against the user's Console requirements and
[Google's preview-asset guidance](https://support.google.com/googleplay/android-developer/answer/9866151).
All nine upload images were visually reviewed. Screenshot RGB pixels were verified
to be identical to the original emulator captures after removing the unused alpha
channel; screenshots have no added captions, fabricated interface or composited UI.

## Suggested alt text and order

| File | Alt text |
| --- | --- |
| `feature-graphic.png` | Requiem Character Sheet, an unofficial tabletop companion for Vampire: The Requiem Second Edition. |
| `01-character-library.png` | Character library with saved vampires, guided creation and character import. |
| `02-guided-creation.png` | Seven-step character creation checklist with Attribute budgets and progress indicators. |
| `03-attributes.png` | Mental, Physical and Social Attributes with editable rating dots and Resilience bonuses. |
| `04-skills-and-specialties.png` | Mental Skills with rating dots and custom Specialties, including History and Archives. |
| `05-disciplines-and-coils.png` | Disciplines and Coils of the Dragon, with ratings and powers from the Mystery of the Wyrm. |
| `06-merits-and-aspirations.png` | Character Merits and three written Aspirations on the editable sheet. |
| `07-health-willpower-and-vitae.png` | Health damage, spent Willpower, Blood Potency and current Vitae trackers. |
| `08-humanity-and-touchstones.png` | Humanity ratings with named Touchstones connecting a vampire to mortal life. |

## Capture and artwork provenance

Screenshots were taken directly from the installed, non-debuggable beta using
`adb exec-out screencap -p` on an Android 16 (API 36.1) emulator. The display was
set to 1080 × 1920 at 320 dpi (540 × 960 dp), with the normal 1.0 font scale.
System status-bar icons and notifications were hidden using Android's status-bar
command; the app's own layout, typography, controls and navigation were unchanged.

Only fictional emulator characters were used. `source/Roisin-Vale.vtrcharacter`
is the developed character; `source/Iona-Byrne.vtrcharacter` is in guided creation.
Import them through the app's normal Import Character action on a test device.
The library capture shows both; the checklist uses Iona. For the remaining images,
open Róisín and use Sections → Attributes, Skills, Disciplines, Merits, Health and
Humanity respectively. The Health capture is scrolled upward about 17 px from the
section jump so the current Vitae controls remain clear of the bottom fade.
Relative modification dates in a new library capture will naturally differ.

The source saves are screenshot examples, not additions to the shared save-contract
fixtures or changes to either platform's data model. The S24 FE was not accessed.

The feature graphic was generated with the built-in image generation tool, using
the app's existing `page_border.jpg` as a style reference. It uses a new typographic
composition and explicitly identifies the app as unofficial. The exact prompt and
mechanical export command are in `source/feature-graphic-prompt.txt`; the original
1774 × 887 image is retained beside it. The final export is uniformly downsampled
and center-cropped to the required dimensions, without removing text or ornaments.
The screenshot fonts are the app's licensed IM Fell English and Cinzel resources;
no font files or licences were added or altered. The feature graphic's lettering
is generated artwork, not a new font dependency.

The existing app artwork remains subject to its original rights and Dark Pack
notices. See the release guide for the listing's required rights notice. These
assets do not change the app's legal acknowledgements or imply publisher endorsement.

Refresh affected screenshots when shipping a newer Android UI. In particular,
Claude's 7 November handoff lists iOS changes still awaiting a separate Android
parity task; those features are not represented as already released here.
