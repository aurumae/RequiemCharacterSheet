# Android character sheet

Open this directory in Android Studio and run the **app** configuration. The Kotlin/Compose app supports Android 16 and later (minimum API 36). It stores characters on the device and works offline. The Galaxy S24 FE on Android 17 is the first physical test device.

To build and install the debug APK with JDK 21 or Android Studio’s bundled JDK, set up Android SDK Platform 36 and Build Tools 36.0.0, then run from the repository root:

```sh
android/gradlew -p android :app:assembleDebug
adb install -r android/app/build/outputs/apk/debug/app-debug.apk
```

The current alpha supports guided character creation and the complete ordinary-play sheet: character details, Attributes and Skills, Disciplines, Merits, Aspirations, Banes, all play trackers, Humanity and Touchstones, Rituals, Devotions, Mysteries, Coils and Scales. Use **Sections** to navigate the sheet. Mask, Dirge, Clan and Covenant have searchable catalog choices and also accept custom text. Each edit is saved to app-private storage. Save waits for pending writes and confirms in place; Back waits and returns to the library. Guided sheets can be resumed, edited, finished or left as ordinary sheets. Unreadable and newer saves stay in the library with an explanation.

The app follows the iOS release’s paper frame, fonts, colors and section bands. Edit Stamina by tapping a dot and tap each Health box to cycle damage. Dots and Health boxes use the iOS spacing: 20 dp marks on a 24 dp pitch. Tap an attribute’s name to open a dropdown with full-sized rows. During ordinary play it offers attributes from 1 and skills from 0 through max(5, Blood Potency), up to 10; creation also applies the starting-dot budgets. All Attributes and Skills use this shared control. Tap a filled first Skill dot again, or choose 0 from its name menu, to clear the rating. Black dots show Attribute and roll bonuses separately from the red base rating; roll-only bonuses do not inflate Health, Speed or Defense. Rows wrap or stack at large text sizes. The Change Log opens as a native bottom sheet. Install with `adb install -r` to update the first alpha while retaining characters.

The Dark Pack notice appears on launch for five seconds and can be dismissed by tapping anywhere. Rotation keeps the same timer, and returning from the background does not restart it. The same notice remains in **About this app**.

**Try a scene.** Create a blank sheet and name it. Raise Stamina from 1 to 2 with XP Mode off, turn XP Mode on, and raise it to 3. The log should show one free dot and one 4 XP purchase, with −4 XP available. Tap Health box 8 once for bashing damage. Go Home. To simulate Android reclaiming the process, run `adb shell am kill ie.requiem.sheet` while the app is in the background, then resume it from Recents. The same character should open with the eighth mark and two log entries. Lower Stamina to 2 with XP Mode on: the refund brings the balance back to zero. With TalkBack on, Stamina has raise/lower actions and each Health box announces its position and damage.

**Try the expanded sheet.** Enter an existing character with XP Mode off. Select or type a Clan and Covenant, set Attributes and Skills, then turn XP Mode on. An Attribute dot costs 4, a Skill dot 2 and a Specialty 1. Tap Add Specialty under a Skill; tap an existing Specialty to rename or delete it. Renaming is free, Cancel leaves it alone, and removing a paid Specialty with XP Mode on refunds 1. Lowering a paid trait with XP Mode off removes its paid status without a refund. Changes and the ledger survive saving and reopening. The next milestone is distributing the parity alpha and testing releases, as described in [the port plan](../docs/android-port-plan.md).

**Guided creation.** Choose Guided character creation from the library. The seven-step checklist sits at the top of the sheet, and tapping a step jumps to its section. Pick Primary, Secondary and Tertiary separately for Attribute and Skill categories: their budgets are 5/4/3 and 11/7/4. A category has no starting dots until its priority is assigned. Choosing an occupied priority swaps the two categories. Dots you cannot currently buy are faded, and rating menus list only the permitted values.

Selecting a catalog clan asks which favoured Attribute receives its free dot. Change that choice from the checklist. The dot sits outside the Attribute budget and cannot be removed while creating. A clan change removes it only if the new clan does not favour that Attribute. The first Touchstone belongs at Humanity 7 for Ventrue and 6 otherwise.

Creation allows three Specialties, three Discipline dots (at most one out of clan), and ten Merit dots. Each extra Blood Potency dot uses five Merit dots, to a maximum of Blood Potency 3. Sorcery requires the appropriate covenant Status; only the chosen Mystery’s Coil can be learned, and ritual slots and ratings must fit their Discipline. Merit prerequisites are enforced. Catalog options explain why an entry is unavailable. Devotions and Scales wait until after creation.

Priority changes, clan changes and existing saves can leave broken rules. The checklist identifies them, and unaffected categories remain editable while you correct the sheet. Finish Creation stays disabled until the sheet is within its limits. If legal steps are incomplete, Keep Going returns to the sheet and Finish Anyway opens the rank selector. Selecting a rank is saved without awarding its XP yet; Finish grants the bonus once and enables XP Mode. Creation dots remain free and appear as Creation in the log. Leave Guided Creation keeps the sheet and clan dot, grants no bonus and keeps XP Mode off. Save, Back, rotation and process restoration preserve progress.

**Try guided creation.** Make a Ventrue and choose Presence for its clan dot. Give Social Attributes Primary, raise Presence to 5 and Manipulation to 3: all five starting dots are used. Switch Social to Tertiary to see the two-dot overspend and disabled Finish button, then lower Manipulation to 1. Record a Touchstone at Humanity 7, save and reopen. Finish Anyway with Ancilla selected: 15 Experiences should become available exactly once. Lower the free Presence rating to 4 (no refund), raise it to 5 (cost 4), then lower it again (refund 4).

**Powers and personal traits.** Tap Add Discipline, Merit or Bane to search the bundled books or create a custom entry. In-clan Disciplines and Vampire Merits appear first. Tap a name for its reference details; use its dots or the three-dot menu’s Set rating action to edit. Merit menus respect gaps in legal ratings, and repeatable Merits can have different qualifiers. Prerequisites warn during ordinary play without preventing an entry. Aspirations support multiline editing. Banes are limited to three; the clan-bane switch activates at the clan’s Humanity threshold and stays on if Humanity later rises.

**Play and advancement.** Tap Willpower boxes to spend or restore them. Blood Potency controls the Attribute/Skill cap and maximum Vitae. Tap a counter’s label or value for direct entry, or use its plus/minus buttons; five Beats add one earned Experience. Tap a Humanity dot to set Humanity and the adjacent text to edit its Touchstone. Losses of Humanity and Blood Potency never refund XP. Advantages reflect catalog effects, including alternative Defenses and combat dice pools.

**Sorcery.** Adding a ritual Discipline reveals Rituals. Its dots provide that many free ritual slots; later rituals cost 2 Experiences. Add Crúac at 1 with XP Mode on, then Rigor Mortis and Pangs of Proserpina: the Discipline costs 4, the first ritual 0 and the second 2. Devotion details show prerequisites, costs and pools; custom Devotions have an editable Experience cost. Selecting Ordo Dracul reveals Coils of the Dragon; picking a Mystery adds its Coil at zero dots. Your Mystery’s dots cost 3 each, other Coils cost 4, and a Scale costs 1 when a prerequisite Coil is met or 2 otherwise. Refunds use the amount actually paid, even if eligibility changes later. Saved sorcery remains visible after changing covenant or removing a Discipline.

Run the local tests or the Compose interaction tests (with an emulator or authorized device attached):

```sh
android/gradlew -p android :rules:test :app:testDebugUnitTest :app:lintDebug
android/gradlew -p android :app:connectedDebugAndroidTest
```

With Swift 6 and JDK 21 on the same machine, run the file exchange:

```sh
scripts/check-save-contract
```

The script has the production Swift encoder write two current characters into a temporary directory. Kotlin edits their names and timestamps, upgrades four older examples after an edit, and creates a blank sheet. Swift reads all seven files back and checks every saved field, including the new sheet’s defaults. The suites also compare the catalog IDs in order, run the shared Stamina, core advancement and 37-action ordinary-play sequences, and test migration and future-version rejection. The ordinary-play sequence exchanges its completed sheet and XP ledger in both directions, including free rituals, changing Scale prices and nonrefundable losses. A 71-action guided-creation sequence also compares budgets, problems, checklist details and logs at every step, and exchanges unfinished, ready-to-finish, finished and advanced characters. Run `swift test` for all host-side Swift model and storage tests. The Xcode app and test targets remain available for device and UI testing.

The JVM jar packages the three original JSON book files directly from the iOS catalog directory. `CharacterCodec` reads save versions 1–9 and writes v9. Keep the initially decoded character and pass it to `encodeEdit` with the edited copy. A null result means no file write or timestamp change is needed.

The examples in [shared/fixtures/characters](../shared/fixtures/characters) are synthetic characters with no player data. The unversioned example comes from the existing iOS decoder test. The complete v6, v7 and v8 fixtures use the Swift writers at `a51e9af`, `3d7f2c7` and `334f516`. The two forms of v9 use `3a8630a` (before priorities) and `506ea78` (current). The v10 example is intentionally unsupported.
