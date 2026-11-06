# Android beta signing and first Play upload

The first Play beta is **1.0.0-beta.1, version code 9**, package **`ie.requiem.sheet`**,
for Android 16 or later. It packages the accepted alpha 8 functionality as a non-debuggable
release build. Shrinking is not enabled in this first beta, so it introduces no optimisation
changes to the accepted app. iOS versioning is independent.

The user accepted all alpha 8 manual checks on the S24 FE running Android 17 and confirmed
real character transfers in both directions between Android and iOS. PR #3 has passed all
checks and is merged as `679758c`.

## Signing keys

Use the dedicated **upload key** to sign bundles locally. Google Play holds a different
**app signing key** and signs the APKs installed by testers. New apps currently enrol in
Google-generated Play App Signing by default; retain that arrangement when uploading.
The upload key is not the debug key and is not Google's distribution key.
[Google signing guidance](https://support.google.com/googleplay/android-developer/answer/9842756)

The local signing directory is outside both Git checkouts:

```
/home/oisin/RequiemCharacterSheetApp/AndroidSigning/
    upload-keystore.jks
    upload.properties
    upload-certificate.pem
```

The keystore contains the RSA-4096 private upload key, alias `requiem-upload`.
`upload.properties` contains its passwords and configuration. The directory is owner-only;
the keystore and configuration are readable/writable only by the owner. Neither belongs
in Git, a PR attachment or the Play upload. Keep an encrypted recovery copy of both in a
location you control, and put the passwords in your password manager. A second copy on the
same disk does not protect against loss of that disk. The public `.pem` certificate is safe
to share if Play asks for the upload certificate; it does not contain the private key.

The current upload certificate's SHA-256 fingerprint is:

```
57:EC:9F:74:0F:28:2F:D7:53:64:02:DA:8F:46:8F:B7:09:DC:36:18:28:28:73:6B:86:79:B5:6B:7F:16:0A:0F
```

Its validity ends on 24 March 2054. Compare this with **Upload key certificate** in Play
Console after the first upload. Google's **App signing key certificate** will be different.
If the upload key is lost, request an upload-key reset through Play; don't silently replace
it and expect the next upload to work.

## Rebuilding a signed bundle

From the repository root, with the documented JDK and Android SDK installed:

```sh
REQUIEM_SIGNING_PROPERTIES=/home/oisin/RequiemCharacterSheetApp/AndroidSigning/upload.properties \
  android/gradlew -p android :app:lintRelease :app:bundleRelease
```

The upload artifact is `android/app/build/outputs/bundle/release/app-release.aab`.
Set the same environment variable when launching Android Studio if you want its Gradle
release tasks to use this configuration. To set up another machine, restore the keystore
and private properties file outside its checkout. `storeFile` can be absolute or relative
to the properties file; use `android/signing.properties.example` as the non-secret template.
Normal debug builds require no signing configuration and retain the original debug key.

Release packaging refuses missing credentials, an invalid/unlockable key or the Android
debug certificate. CI explicitly opts into an **unsigned verification build** with:

```sh
android/gradlew -p android :app:lintRelease :app:bundleRelease -PrequiemUnsignedRelease=true
```

That unsigned output is not a Play upload artifact. CI receives no upload key or password.
The existing workflow still skips only the iOS UI test target on GitHub.

## First distribution through Play Console

Start with **Internal testing**, which supports up to 100 testers and can begin before
completing the full store setup. This gives us a Play-delivered build to check before the
closed beta and production requirements in the [release guide](play-store-release-guide.md).
[Google internal testing instructions](https://support.google.com/googleplay/android-developer/answer/9845334)

1. Create the app record if you have not already. Use the existing name, choose **App** and
   **Free**, and complete the declarations that accurately describe your app. The first
   bundle fixes its package identity as `ie.requiem.sheet`.
2. Open **Test and release → Testing → Internal testing** and create a release.
3. Retain Google-generated **Play App Signing**. Upload the signed **`.aab`**, not an APK,
   keystore or properties file. Confirm the detected version is `1.0.0-beta.1` (9) and
   check any warnings or errors reported by Play before proceeding.
4. Use a release name such as `1.0.0-beta.1 (9)`. Suggested release notes:

   > First Android beta: guided character creation, character sheet editing and play trackers,
   > advancement history, and character file export/import compatible with the iOS app.

5. Under the track's **Testers** tab, create/select an email list containing the Google
   accounts testers use on their phones. Add yourself. Set the feedback address or URL,
   save the list, review the release and roll it out to **Internal testing**.
6. Copy the opt-in link and give it to the selected testers. They must opt in using an
   included Google account, then install from Play. The first link may take several hours
   to become available; initial listing information may be temporary.
7. On the S24 FE, verify the actual Play installation, including import/export, guided
   creation, edits and XP history. A subsequent higher-code Play build must also be tested
   as an update without uninstalling. A locally generated APK cannot verify Google's
   signing or delivery path.

Internal testing does not satisfy the separate closed-testing requirement for a new
personal account. Complete Android privacy access, explicit backup rules, store content
and the required closed test before requesting production access. These signing changes
do not publish the app, add testers or make declarations on your behalf.

## Moving from the installed debug alpha

The existing alpha uses a different signing certificate. **Do not uninstall it until all
valuable characters have been saved outside the app and those files have been checked.**
Use each character's library menu → **Save to file**, and keep a second copy. Once the Play
release is available and those backups are verified, uninstall the debug alpha if necessary,
install from the internal-test opt-in link and use **Import Character** to restore them.
Compare names, guided progress, tracks and XP history. New testers without the debug alpha
can install directly. The upload-signed local release APK is for local verification; use the
Play installation for the beta group. [Android signing and update rules](https://developer.android.com/studio/publish/app-signing)

## Validation for beta 1

The release build and lint passed (zero errors, seven existing SDK/dependency update warnings),
along with all 54 JVM rules/storage tests. Checked both the explicit unsigned CI build and the
signed release path. Ordinary release packaging without credentials fails, and using the debug
certificate fails. The upload-signed AAB passes bundletool validation and Java signature verification;
every payload entry is signed by the expected upload certificate. The manifest is non-debuggable,
with package `ie.requiem.sheet`, version `1.0.0-beta.1` (9), and minimum/target API 36.

Bundle packaging requests 16 KB alignment. Both 64-bit native libraries have 16 KB-aligned LOAD
segments and safe RELRO boundaries, and generated APKs pass the SDK's 16 KB ZIP-alignment check.
The non-debuggable split APKs were installed on the Android 16 emulator. Importing an alpha export,
exporting it unchanged, editing a sheet and saving/reopening/exporting it all passed. The beta
version is displayed in About. This is a local release smoke test; the emulator uses a 4 KB kernel,
so a 16 KB runtime check and Play-delivered install/update checks remain separate validation.

The upload key, its passwords and synthetic test fixtures are absent from the bundle. New files
containing signing credentials are ignored by Git. The unrelated local Gradle JVM preferences file
was preserved and is not committed. No app runtime behavior, save schema, catalog, font or iOS
production code changed. CI now also compiles/lints an explicitly unsigned release without secrets;
the iOS UI-test skip flag is preserved.
