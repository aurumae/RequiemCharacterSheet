# Android character sheet

Open this directory in Android Studio and run the **app** configuration. The Kotlin/Compose app supports Android 16 and later (minimum API 36). It stores characters on the device and works offline. The Galaxy S24 FE on Android 17 is the first physical test device.

To build and install the debug APK with JDK 21 or Android Studio’s bundled JDK, set up Android SDK Platform 36 and Build Tools 36.0.0, then run from the repository root:

```sh
android/gradlew -p android :app:assembleDebug
adb install -r android/app/build/outputs/apk/debug/app-debug.apk
```

The first playable build supports a character library, name, Stamina, Health and XP Mode. Each edit is saved to app-private storage. Save and Back wait for pending writes. Existing guided sheets can be viewed; editing them comes in milestone 4. Unreadable and newer saves stay in the library with an explanation.

**Try a scene.** Create a blank sheet and name it. Raise Stamina from 1 to 2 with XP Mode off, turn XP Mode on, and raise it to 3. The log should show one free dot and one 4 XP purchase, with −4 XP available. Tap Health box 8 once for bashing damage. Go Home. To simulate Android reclaiming the process, run `adb shell am kill ie.requiem.sheet` while the app is in the background, then resume it from Recents. The same character should open with the eighth mark and two log entries. Lower Stamina to 2 with XP Mode on: the refund brings the balance back to zero. With TalkBack on, Stamina has raise/lower actions and each Health box announces its position and damage.

Run the local tests or the Compose interaction test (with an emulator or authorized device attached):

```sh
android/gradlew -p android :rules:test :app:testDebugUnitTest :app:lintDebug
android/gradlew -p android :app:connectedDebugAndroidTest
```

With Swift 6 and JDK 21 on the same machine, run the file exchange:

```sh
scripts/check-save-contract
```

The script has the production Swift encoder write two current characters into a temporary directory. Kotlin edits their names and timestamps, upgrades four older examples after an edit, and creates a blank sheet. Swift reads all seven files back and checks every saved field, including the new sheet’s defaults. The suites also compare the catalog IDs in order and test migration and future-version rejection. Run `swift test` for all host-side Swift model and storage tests. The Xcode app and test targets remain available for device and UI testing.

The JVM jar packages the three original JSON book files directly from the iOS catalog directory. `CharacterCodec` reads save versions 1–9 and writes v9. Keep the initially decoded character and pass it to `encodeEdit` with the edited copy. A null result means no file write or timestamp change is needed.

The examples in [shared/fixtures/characters](../shared/fixtures/characters) are synthetic characters with no player data. The unversioned example comes from the existing iOS decoder test. The complete v6, v7 and v8 fixtures use the Swift writers at `a51e9af`, `3d7f2c7` and `334f516`. The two forms of v9 use `3a8630a` (before priorities) and `506ea78` (current). The v10 example is intentionally unsupported.
