# Android character sheet

Open this directory in Android Studio to work on the Kotlin `:rules` module. The first milestone covers the character file and catalog formats. The Android app module will target Android 16 and later (minimum API 36). The first device for testing is a Galaxy S24 FE on Android 17.

From the repository root, run the Kotlin tests with JDK 21:

```sh
android/gradlew -p android :rules:test
```

With Swift 6 and JDK 21 on the same machine, run the file exchange:

```sh
scripts/check-save-contract
```

The script has the production Swift encoder write two current characters into a temporary directory. Kotlin edits their names and timestamps, upgrades four older examples after an edit, and creates a blank sheet. Swift reads all seven files back and checks every saved field, including the new sheet’s defaults. The suites also compare the catalog IDs in order and test migration and future-version rejection. Run `swift test` for all host-side Swift model and storage tests. The Xcode app and test targets remain available for device and UI testing.

The JVM jar packages the three original JSON book files directly from the iOS catalog directory. `CharacterCodec` reads save versions 1–9 and writes v9. Keep the initially decoded character and pass it to `encodeEdit` with the edited copy. A null result means no file write or timestamp change is needed.

The examples in [shared/fixtures/characters](../shared/fixtures/characters) are synthetic characters with no player data. The unversioned example comes from the existing iOS decoder test. The complete v6, v7 and v8 fixtures use the Swift writers at `a51e9af`, `3d7f2c7` and `334f516`. The two forms of v9 use `3a8630a` (before priorities) and `506ea78` (current). The v10 example is intentionally unsupported.
