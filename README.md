# Requiem and Forsaken Character Sheets

Native character-sheet apps for two Chronicles of Darkness games:

- **Requiem Character Sheet**, for Vampire: The Requiem, Second Edition
- **Forsaken Character Sheet**, for Werewolf: The Forsaken, Second Edition

Each game is its own app, on iOS (Swift and SwiftUI) and on Android (Kotlin and Jetpack Compose), and the two games
share a common core on each platform. The apps are free, work offline, keep characters on the device and collect no
personal data. iOS is the main version: new work is done there first, and the Android port follows it.

## Status

As recorded in this repository on 18 November 2026. Store review and device testing happen outside it, so
[the handoff](docs/handoff.md) has anything newer.

| | iOS 26 and later, iPhone | Android 16 and later |
| --- | --- | --- |
| **Requiem** | 1.4 is on the App Store. The source is 1.5. | `1.0.0-beta.3` (code 11), built for Play testing. It reads and writes the same saves as iOS 1.5 and has every capability in the save contract. Testing on a phone, a privacy policy and backup rules are still to do before a public release. |
| **Forsaken** | 1.0 was submitted for App Store review on 17 November 2026. | Forsaken Preview `0.2.0-preview.2` (code 3). Blank sheets and ordinary play can be edited; guided creation is read-only until phase 4 of [the port plan](docs/android-forsaken-plan.md). |

## What the apps do

Both apps are one player character's sheet, laid out like the game's official sheet:

- Attributes, Skills and Specialties, Merits, Conditions, Aspirations, Health and Willpower.
- Beats and Experiences. With XP Mode on, the sheet works out what each change costs or refunds and keeps a change
  log.
- Guided character creation, which can be left and resumed.
- Pickers for the official options, grouped by book, with a summary and page reference for each. Anything can also
  be typed in as a custom entry.
- Export and import of a character as a file.

**Requiem** adds clans, bloodlines and covenants, Disciplines, Devotions, blood sorcery, Coils and Scales, Blood
Potency and Vitae, Humanity and Touchstones, and Banes. Its books are *Vampire: The Requiem Second Edition*,
*Secrets of the Covenants*, *A Thousand Years of Night*, *Night Horrors: Spilled Blood*, *Dark Eras*, *Dark Eras
Companion*, *Dark Eras 2* and the Merits and Conditions of *Chronicles of Darkness*.

**Forsaken** adds auspices, tribes and lodges, the five forms with their own traits, Renown, Gifts and Facets, rites,
fetishes, the pack totem, Primal Urge and Essence, Harmony and Kuruth triggers. It covers the Forsaken, Ghost Wolves
and the Pure. Its books are *Werewolf: The Forsaken Second Edition*, *The Pack*, *Night Horrors: Shunned by the
Moon*, *Dark Eras*, *Dark Eras Companion*, *Dark Eras 2* and *Chronicles of Darkness*. The unofficial *Giver of
Gifts* articles are behind a switch on each character, off by default.

[Design decisions](docs/design-decisions.md) records the product decisions both platforms follow.

## Repository layout

| Path | Contents |
| --- | --- |
| `Chronicles/Core/` | Swift models and rules that belong to no one game: traits, Merits, Conditions, Experiences and the character file store. |
| `Chronicles/UI/` | SwiftUI shared by both iOS apps: the library, the sheet frame, dots and boxes, pickers, About. |
| `RequiemCharacterSheet/` | The Requiem iOS app, with its catalogs and fonts. |
| `ForsakenCharacterSheet/` | The Forsaken iOS app, with its catalogs and fonts. |
| `RequiemCharacterSheetTests/`, `ForsakenCharacterSheetTests/`, `RequiemCharacterSheetUITests/` | The iOS tests. |
| `RequiemCharacterSheet.xcodeproj` | The Xcode project for both iOS apps. |
| `Package.swift` | Builds both games' models on macOS, so `swift test` can run their tests without a simulator. |
| `android/` | The Gradle project: `:core`, `:requiem`, `:forsaken`, `:sheet-ui`, and the apps `:app` (Requiem) and `:forsakenApp`. |
| `shared/` | The save contract and its example characters, the catalog contract, and Forsaken's section headings as Android drawables. |
| `scripts/` | The contract and CI policy checks, and the save exchange. |
| `docs/` | Plans, formats, decisions and the handoff between platforms. |

The catalogs are JSON files, one per book, in `RequiemCharacterSheet/Catalogs/` and
`ForsakenCharacterSheet/Catalogs/`. The Android apps package the same files and fonts from those folders, so a
correction to a book reaches both platforms in one edit.

## Building and testing

**iOS.** Open `RequiemCharacterSheet.xcodeproj` in Xcode 26. There is a scheme for each app: `RequiemCharacterSheet`
and `ForsakenCharacterSheet`.

```sh
swift test
```

This builds both games' models for macOS and runs their unit tests, along with the contract policy check. Tests that
need the apps' views or artwork, and Requiem's UI tests, run in Xcode only.

**Android.** Open `android/` in Android Studio, or use JDK 21 with Android SDK Platform 36 and Build Tools 36.0.0:

```sh
android/gradlew -p android :app:assembleDebug :forsakenApp:assembleDebug
android/gradlew -p android :core:test :requiem:test :forsaken:test :app:testDebugUnitTest :forsakenApp:testDebugUnitTest
```

The [Android guide](android/README.md) covers installing on a device and the emulator tests.

**Both platforms.** With Swift 6 and JDK 21 on one machine:

```sh
scripts/check-save-contract
```

This runs the policy check, `swift test` and Requiem's Android unit tests, then passes Requiem characters from Swift
to Kotlin and back through each app's real store. Add `--strict` to require that Android has everything iOS declares.

## Character files

Characters are JSON. Moving one between devices is a manual export and import; nothing synchronises. Each app
refuses a file from the other game, and a file from a newer version it can't read in full.

**Requiem** files are `.vtrcharacter`. Both platforms read schemas 1–12 and write the lowest of 10, 11 or 12 that the
character needs: 11 with Conditions or their history, 12 with an elder clan bane in effect. That lets an older app
open any character it can show completely. `shared/fixtures/contracts.json` is the contract: it lists the
capabilities each platform supports, the example characters in `shared/fixtures/characters/` and the scripted
sequences of play whose results both platforms must match. `shared/catalog-contract.json` does the same for catalog
fields and rule values. See [Maintaining iOS-first compatibility](docs/ci-contract-policy.md) and the
[Android transfer guide](docs/android-character-transfer.md).

**Forsaken** files are `.wtfcharacter`, at schema 1, described in [its save format](docs/forsaken-save-format.md).
Two saved characters in `ForsakenCharacterSheetTests/Fixtures/` pin the format, and Android's tests read them there.
Forsaken hasn't joined the contract or the exchange yet, so a green run says nothing about Forsaken parity between
the platforms.

## Continuous integration

One GitHub workflow, [Character save contract](.github/workflows/save-contract.yml), runs on pull requests, on pushes
to `main` and weekly:

- **policy** checks the contracts against the code, catalogs and fixtures, then chooses which jobs the change needs.
- **android** tests, lints and packages both Android apps.
- **exchange** runs `scripts/check-save-contract` on macOS.
- **ios** runs `swift test`, then builds and tests both Xcode schemes in a simulator. Requiem's UI tests are skipped
  here, because the runner times out on UI queries; they run in Xcode Cloud and locally.
- **CI result** passes only if every chosen job did.

Because iOS goes first, a feature can be on `main` before Android has it. The contract records it as pending for
Android, and ordinary runs accept that. A red `main` means something is broken, never that Android hasn't caught up.

## How the work is organised

The iOS apps are developed with Claude Code and the Android apps with Codex (Astra in the handoff), for one author.
[`CLAUDE.md`](CLAUDE.md) and [`AGENTS.md`](AGENTS.md) hold each agent's instructions, and
[`docs/handoff.md`](docs/handoff.md) is the append-only log in which each tells the other what changed and what to
follow up. iOS work is committed to `main`; Android work arrives through `android/…` branches and pull requests. Each
app is released from its own tested commit with its own version number.

## Documentation

Current:

- [Design decisions](docs/design-decisions.md): product rulings for both platforms.
- [Handoff](docs/handoff.md): the running log between iOS and Android.
- [Multi-game plan](docs/multi-game-plan.md): what is shared between the games and what isn't.
- [Maintaining iOS-first compatibility](docs/ci-contract-policy.md): the contract, and adding an iOS feature before
  its Android port.
- Forsaken: [save format](docs/forsaken-save-format.md), [catalog format](docs/forsaken-catalog-format.md),
  [content audit](docs/forsaken-content-audit.md) and [section headings](shared/forsaken-headings/README.md).
- Android Forsaken: [port plan](docs/android-forsaken-plan.md) and the
  [ordinary-play candidate](docs/android-forsaken-ordinary-play.md).
- Android release: [character transfer](docs/android-character-transfer.md), [signing](docs/android-signing.md) and
  the [Google Play release guide](docs/play-store-release-guide.md).

Records of finished work:

- [Android port plan](docs/android-port-plan.md), [iOS 1.3 parity](docs/ios-1.3-parity-plan.md),
  [beta 2](docs/android-beta2-plan.md), [parity with iOS 1.5](docs/android-current-parity-plan.md) and
  [beta 3 validation](docs/android-beta3-validation.md).
- [Forsaken viewer](docs/android-forsaken-viewer.md), the phase before ordinary play.
- [CI for iOS-first development](docs/ios-first-ci-plan.md), the proposal behind the current workflow.
- [Catalogs, effects and descriptions](docs/phase-b-design.md), the design of Requiem's catalogs.

## Legal

This is unofficial Fan Content permitted under the Dark Pack. These apps are not official World of Darkness material.
The catalogs summarise rules in our own words and cite the book and page; no book text is included.

The bundled fonts (IM Fell English, Cinzel, Comforter and Grechen Fuemen) are under the SIL Open Font License, and
their licences are beside them in each app's `Fonts/` folder. Forsaken's section headings are drawn in Flat Earth
Scribe and stored as outlines; the font itself is not in this repository or in either app.

The [iOS privacy policy](https://gist.github.com/aurumae/5a83610184c4f0e4b14b514ac508a1a9) covers Requiem on iOS.
Android needs its own policy, linked from inside the app, before it is published on Google Play.
