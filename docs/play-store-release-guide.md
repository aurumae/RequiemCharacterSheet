# Phase 6 Google Play release guide

Prepared 5 November 2026 for Requiem Character Sheet. The Android baseline is `1d0c798`, version `0.4.0-alpha.6`, now accepted on the Galaxy S24 FE. This guide covers the remaining work from developer registration through the first public release and subsequent updates. It includes the internal distribution and upgrade checks previously listed as phase 5; those checks still need to happen through Google Play.

You are creating a new developer account. The main route below assumes a **personal account** for this independent project. Use an organisation account instead if a legal organisation is the publisher. This guide describes work to do; it does not create signing keys, publish a privacy policy, submit declarations or upload an app.

Our proposed first release is free, without advertisements, purchases, accounts or a backend. Keep Android 16 as the minimum. Start recruiting compatible testers while preparing the release: account verification and the closed test will determine much of the schedule.

## 1 What is already ready and what remains

| Area | Current position | Work before public release |
| --- | --- | --- |
| Character sheet | Guided creation, ordinary play and advancement accepted on your S24 FE | Retest the build delivered by Play |
| Rules and saves | 195 Swift tests, 40 JVM tests and 11 emulator tests passed for alpha 6; shared save exchange passed | Run checks against the final release commit |
| Android support | `minSdk`, `targetSdk` and `compileSdk` are 36 | Keep Android 16 minimum; recheck Play requirements at submission |
| Identity | Package is `ie.requiem.sheet`; label is Requiem Character Sheet | Confirm the permanent package and public publisher name |
| Signing | All delivered alphas use a debug certificate | Create an upload key and use Play App Signing |
| Privacy | Repository links to an iOS policy; About currently contains Dark Pack information only | Publish an Android policy and add an accessible in-app link |
| Character portability | JSON files are private to the app; no export/import screen | Provide a tested route for transferring alpha characters |
| Backup | Manifest does not specify backup behaviour | Configure and test cloud backup and device transfer explicitly |
| Store graphics | Android QA screenshots and a 216 × 216 launcher source exist | Prepare proper store graphics and suitable screenshots |
| Distribution | APK sideloading has been tested | Internal Play test, closed test, production access and public review |

The code findings above come from [app configuration](../android/app/build.gradle.kts), [the manifest](../android/app/src/main/AndroidManifest.xml), [character storage](../android/app/src/main/java/ie/requiem/sheet/CharacterFiles.kt), [About this app](../android/app/src/main/java/ie/requiem/sheet/MainActivity.kt), and [the existing privacy-policy link](../README.md).

## 2 Finish setting up your developer account

**Your tasks:** complete registration using a Google account you control long term, enable strong account security and recovery, and keep the registration receipt. Registration currently costs **US$25 once**. Complete the identity and contact verification requested by the Console; identity documents and payment details belong in Google's registration flow. [Google registration guidance](https://support.google.com/googleplay/android-developer/answer/6112435)

Choose a public developer name and a support address you will monitor. The existing privacy policy gives `app@oisinmccolgan.com`; confirm that it is still the address you want to use. A personal account displays your legal name, country and developer email; monetisation and some regional requirements can require additional public information. An organisation generally needs a D-U-N-S number and matching legal details. Google uses a linked payments profile for identity details even when the app will be free. Review the public profile before completing registration. [Required account information](https://support.google.com/googleplay/android-developer/answer/13628312)

For a new personal account, complete **device verification** from the Console's Home task using the Play Console mobile app, signed in as the account owner. Your S24 FE is suitable if it is not rooted: Google's device requirement is a real, non-rooted Android device running Android 10 or later. [Device verification](https://support.google.com/googleplay/android-developer/answer/14316361)

Complete any Android developer verification and package-registration tasks shown in the account. Play publishers use Play Console for this; you do not need a second Android Developer Console account just to publish here. New Play apps have their package registered during app creation, subject to availability. [Android developer verification for Play publishers](https://developer.android.com/developer-verification/guides/google-play-console)

Also complete the **trader-status declaration** when available. Google's current deadline is 1 February 2027. Whether you are a trader depends on your actual activities, not simply on choosing a personal account or making the app free. A hobby project may be a non-trader, but you must make that assessment. Traders have additional contact and terms-of-service requirements; for a personal trader account, address and phone information become public. [Trader-status requirements](https://support.google.com/googleplay/android-developer/answer/17594752)

**Done when:** the account's verification tasks are complete, its contact details work, and you understand which details are public.

## 3 Confirm the rights and pricing for this release

The current Dark Pack agreement expressly includes character sheets and mobile character generators, with free distribution and no in-app purchases or other monetised transactions. It also covers Chronicles of Darkness material. Our proposed route is therefore **free, with no ads or purchases**. A commercial release would require a separate permissions review. Keep the Dark Pack logo, required legal notice and clear unofficial status in the app and its promotion. The agreement limits reproduction of source material; the notice alone does not authorise unrestricted copying. [Dark Pack agreement](https://www.paradoxinteractive.com/games/world-of-darkness/community/dark-pack-agreement)

Before submission, collect the permissions and provenance for the actual bundled assets: the Requiem logo, parchment border, skull artwork, Caslon Antique and Mrs Eaves font files, and catalog text. Check that font licences permit embedding in an Android app. Retain the existing book references and review summaries against their sources. This is a review of the material already shipped, not a request to replace the visual style.

Keep a dated copy or link to the applicable agreement and any separate permissions. Google provides an advance-notice route for third-party intellectual-property documentation; use it if needed to explain the licensed fan content before review. The listing must identify you as the publisher and clearly describe the app as unofficial. [Google's intellectual-property policy](https://support.google.com/googleplay/android-developer/answer/9888072) · [Advance notice to app review](https://support.google.com/googleplay/android-developer/answer/6320428)

**Done when:** the rights file covers the shipped material and store artwork, and the listing's claims match those permissions.

## 4 Set the permanent app identity and release version

Keep `ie.requiem.sheet` unless you want a different identifier before first registration or it is unavailable. This identifier determines which Android application receives updates; it is separate from the editable store title. Play package names are permanent and cannot be reused. [Create and configure a Play app](https://support.google.com/googleplay/android-developer/answer/9859152)

For the first release candidate, I suggest a user-facing version such as `1.0.0-rc1`. Use the next unused integer version code above 6, and increment it for each newly uploaded build. The public release can be `1.0.0`; its code must continue increasing. Promoting an already uploaded, unchanged artifact between tracks does not require rebuilding it. We should decide the version before building the candidate so its metadata, screenshots and release notes agree.

Keep the code in the existing combined repository. Integrate the accepted Android branch history into the intended release branch, reconcile any newer iOS/catalog changes, then tag the exact release commit. Continue iOS feature work separately and use the shared tests to detect differences. A public release should be reproducible from its tag without relying on uncommitted files in a worktree.

For subsequent development builds, consider an application ID suffix such as `.debug` and an obvious development label. That lets development and Play installations coexist. Introduce it only after the current alpha's data has been preserved; changing an identifier does not transfer its private files.

## 5 Plan the move from debug signing to Play signing

**Do not uninstall the current alpha until its characters have been backed up and the restore path has been checked.** Previous alpha upgrades worked because they shared a debug certificate. Google Play does not accept that certificate for publishing. A new release signing identity will not simply update the existing debug installation with the same package name. [Android signing and update rules](https://developer.android.com/studio/publish/app-signing)

My recommended transition is:

1. Add character export and import, preserving the existing schema, character IDs, creation progress, damage, paid-dot ledger and history.
2. Deliver one final migration alpha signed with the **existing debug key**, so it updates alpha 6 normally.
3. Export every character to a user-selected location outside the app's private directory. Keep a second copy.
4. Verify the exported files by importing them into a separate test installation and comparing the saved values.
5. Only after verification, remove the old installation if needed and install the Play test version.
6. Import the copies and check that characters and XP history agree. Test imports with duplicate IDs, damaged files and unsupported future versions without silently overwriting existing sheets.

Export/import is our proposed protection for players' data, not a general Play Store submission requirement. For your single development phone we could instead make a controlled USB extraction from the debuggable alpha, but that is a developer recovery procedure, not a feature ordinary testers can use. Android backup should not be relied on to bridge this signing change.

Once testers are using Play-signed builds, later Play updates should retain their app data. We will explicitly test that update path before production.

## 6 Create the release signing setup and app bundle

Use **Play App Signing** with Google-managed app signing keys and a separate upload key held by you. The upload key authenticates the `.aab` file we submit; Google signs the APKs installed on users' phones. Current new-app enrolment includes Google's Android 17 signing support. Let Play manage that rather than adding signing logic to the app. An upload key can be reset through Play if lost; still keep secure backups. [Play App Signing](https://support.google.com/googleplay/android-developer/answer/9842756)

In Android Studio, open this checkout's `android/` directory and use **Build → Generate Signed Bundle / APK → Android App Bundle**. Create a dedicated upload keystore outside Git, record its alias, and store passwords and recovery copies securely. Select the release variant. The existing Gradle file does not yet configure release signing, so an ordinary command-line release build is not automatically a signed submission artifact. [Android Studio signing workflow](https://developer.android.com/studio/publish/app-signing)

**Our code tasks:** configure release signing through local properties or secure CI inputs, exclude keystores and secret files from Git, and document the build. Keep release builds non-debuggable. If we enable shrinking or obfuscation, test the resulting build and preserve its mapping file; enabling these is not itself a release requirement.

After configuring signing, the expected command from the repository root is:

```sh
android/gradlew -p android :app:bundleRelease
```

The normal output is `android/app/build/outputs/bundle/release/app-release.aab`. Verify its signature, package, version code, SDK values and release manifest. Upload the **AAB**, not the existing debug APK. An AAB is a publishing artifact, not something you install directly on your phone. [Build release bundles](https://developer.android.com/build/building-cmdline)

Archive the exact bundle, checksum, Git commit, version, toolchain, public certificate fingerprints and test results. Keep signing secrets separately. Test the version installed through Play: a locally signed APK is not a substitute for checking the delivered package.

## 7 Complete Android privacy and backup work

The [current policy](https://gist.github.com/aurumae/5a83610184c4f0e4b14b514ac508a1a9) explicitly covers the iOS app. It discusses crash reporting and support correspondence, but does not describe Android character storage or Android backup. Publish an Android-specific policy, or a clearly separated policy covering both platforms without changing the meaning of the existing iOS promises.

Google requires a publicly accessible privacy-policy webpage and a policy link or text inside the app, even for apps that collect no data. The policy must identify the app or publisher, provide a privacy contact, and explain data handling, retention and deletion. Use a normal webpage available without login or geographic restrictions, not a PDF. Add **Privacy policy** to About this app while retaining the Dark Pack notice. [Google's user-data policy](https://support.google.com/googleplay/android-developer/answer/10144311)

For this app, the policy should explain in plain language:

- Character names, player names, notes and other sheet contents are stored in app-private files; entering a real person's name is optional.
- Whether the final build sends anything to you or to an integrated service. The inspected application has no ads, account system, analytics integration or app-managed server connection.
- The final backup and device-transfer behaviour, and how user-directed exports work if implemented.
- Deleting a character, clearing app storage and uninstalling; separately explain that previously exported files and backup copies may remain elsewhere.
- How support emails and voluntarily supplied character files or screenshots are used and retained.
- Any diagnostics actually available through Google Play or an added SDK. Do not copy the iOS crash-reporting sentence without checking Android behaviour.

**Backup needs a deliberate implementation.** Android's `allowBackup` defaults to true, and internal files normally participate in system backup. Some manufacturer device transfers behave differently from cloud backup, so setting that flag alone is not a complete transfer policy. For our Android 16 minimum, define `data-extraction-rules` and test both restore and device transfer. [Android backup documentation](https://developer.android.com/identity/data/autobackup)

My preference is to permit documented system backup of character files, with appropriate encryption conditions, and also provide manual export/import. System backup protects against device loss; manual files give players a portable copy. Avoid promising that data can never leave the device if system backup or user-directed export is enabled. Neither constitutes automatic iOS/Android synchronisation.

Complete **Data safety** after auditing the final merged release manifest, dependencies and runtime behaviour. Based on the inspected app, “no data collected or shared” is a plausible outcome, not a declaration to submit blindly. Google's definition excludes purely local processing, but includes collection by integrated SDKs; evaluate backup, exports and support flows against the form's definitions. Closed and production tracks require the form, including apps with no collection. [Data safety guidance](https://support.google.com/googleplay/android-developer/answer/10787469)

The app has no user accounts. Creating a character is not account creation, so the account-deletion requirement does not mean we must add a login system or account-deletion website. Character deletion and retention still need explaining. Revisit this if accounts are added. [Account-deletion scope](https://support.google.com/googleplay/android-developer/answer/10144311)

## 8 Check the release build against current Android requirements

The current Google Play requirement for new phone apps and updates is **Android 16 / API 36 or higher**, effective 31 August 2026. Our `targetSdk = 36` meets that requirement today. `minSdk = 36` is our separate choice to support Android 16 onward; it limits who can install and test the app. Recheck the target requirement at submission rather than automatically raising the minimum Android version. [Target API requirements](https://support.google.com/googleplay/android-developer/answer/11926878)

Check **16 KB memory-page compatibility** on the final bundle and a suitable emulator. Although our code is Kotlin, alpha 6 contains `libandroidx.graphics.path.so` in its dependencies. We therefore cannot assume there is no native-code requirement. Inspect packaged native libraries, their alignment and 64-bit support, and address any Play bundle warnings. [Android 16 KB compatibility guidance](https://developer.android.com/guide/practices/page-sizes)

Our release check should cover:

- Clean install and update from an earlier **Play-signed** test build, with characters preserved.
- Android 16 and your Android 17 S24 FE; a second manufacturer where available.
- Small screens, landscape, large text, TalkBack, keyboard entry and Android system Back gestures.
- Cold start, the five-second dismissible notice, backgrounding, process restoration and offline use.
- Guided creation, an unfinished Ventrue, Finish/Leave, XP purchases/refunds, all trackers and sorcery.
- Export/import and backup restore, if included; malformed and future-version files must remain safe.
- No development fixtures, debug labels, sample personal data or temporary functionality in the public build.

Run the existing checks with the configured JDK and SDK:

```sh
android/gradlew -p android :rules:test :app:testDebugUnitTest :app:lintRelease :app:bundleRelease
android/gradlew -p android :app:connectedDebugAndroidTest
scripts/check-save-contract
```

The interaction suite targets the debug variant. It does not replace manual testing of the release artifact delivered by Play. The exchange script also needs the documented Swift environment. Resolve errors and assess warnings; do not treat a successful debug build as proof that signing, release packaging or store policy checks have passed.

## 9 Create the app record in Play Console

Once account setup is complete, use **Create app**. Suggested initial choices are:

| Field | Proposed value |
| --- | --- |
| Name | Requiem Character Sheet |
| Package | `ie.requiem.sheet`, if available and retained |
| Default language | English, using the regional variant you want to maintain |
| App or game | App: this is a tabletop companion, not a standalone video game |
| Category | Entertainment, subject to the available category descriptions |
| Price | Free |
| Support email | Confirm `app@oisinmccolgan.com` |
| Countries | Your chosen launch markets; include your testers' locations in closed testing |

Accept the required agreements after reviewing them and work through the app Dashboard. Choose supported form factors deliberately; do not opt into TV, Wear OS or other surfaces that have not been designed and tested. The Console may offer distribution beyond phones, so inspect those settings instead of assuming the release is phone-only.

## 10 Prepare the store listing and graphics

The current text limits are **30 characters for the name, 80 for the short description and 4,000 for the full description**. [Store listing setup](https://support.google.com/googleplay/android-developer/answer/9859152)

Suggested starting copy:

**Name:** Requiem Character Sheet

**Short description:** An unofficial character sheet for Vampire: The Requiem Second Edition.

The full description should lead with the tabletop use, then describe guided creation, on-sheet editing, play trackers, advancement and offline saving. State that it is unofficial and intended to accompany the game, not replace the rulebooks. Explain Android 16 compatibility and include the required rights notice. Only advertise export/import once implemented. Do not promise cloud synchronisation, account sharing or automatic transfer from iOS.

Prepare these graphics:

| Asset | Required format or our proposed delivery |
| --- | --- |
| Store icon | 512 × 512, 32-bit PNG, at most 1,024 KB |
| Feature graphic | 1,024 × 500, JPEG or 24-bit PNG without alpha |
| Phone screenshots | At least two; prepare six to eight useful examples |
| Screenshot format | JPEG or 24-bit PNG without alpha; dimensions 320–3,840 pixels, longest side no more than twice the shortest |
| Preferred screenshot canvas | 1,080 × 1,920 portrait, using actual Android screens |
| Preview video | Optional; defer for the first release |

Check the finished files against [Google's preview-asset specifications](https://support.google.com/googleplay/android-developer/answer/9866151) before uploading them.

Our existing portrait QA images are **1,080 × 2,400 RGBA**. Prepare new captures or properly composed store images rather than uploading those files unchanged. The current launcher source is **216 × 216**, so obtain a suitable original for the store icon rather than enlarging it blindly. Keep Android launcher assets and the separate Play icon consistent.

A useful screenshot sequence is: character library; guided checklist; Attributes and Skills; Disciplines and Merits; Health/Willpower/Vitae; Humanity/Touchstones; XP history; sorcery. Use synthetic characters and current Android UI, not the iOS screenshots. Add tablet screenshots if supporting and presenting that experience. Keep imagery suitable for a general store audience and avoid graphic gore or imagery implying official publisher endorsement. [Listing presentation guidance](https://support.google.com/googleplay/android-developer/answer/13393723)

## 11 Complete the app declarations

Use **App content** and clear its outstanding tasks. Exact labels can change; answer for the build being submitted. The following are the expected positions for our proposed release, subject to the final audit:

| Declaration | Expected approach |
| --- | --- |
| Privacy policy | Link the Android policy also accessible inside the app |
| Ads | No, provided we keep the build and listing free of ads |
| App access or sign-in | All functionality is available without authentication; no reviewer credentials needed |
| Target audience | Choose the actual intended ages; my proposal is adult tabletop players, not children |
| Content rating | Complete the IARC questionnaire honestly for the content actually present |
| Data safety | Submit the outcome of the final data-flow review in section 7 |
| Advertising ID and sensitive permissions | Declare actual use; none is intended, but inspect the merged release manifest |
| Health features | No health features: the Health tracker represents fictional game damage |
| Financial features | No financial features: Resources, Beats and Experiences are game values |
| Other requested declarations | Complete applicable no-feature answers; do not leave Dashboard tasks unresolved |

Audience selection and the content rating are different. An adult intended audience does not let us choose a rating ourselves. Review the bundled text and artwork for horror, violence, blood and other themes, then answer the rating questions as written. Being a character-sheet utility does not automatically mean “Everyone.” [Review preparation and declarations](https://support.google.com/googleplay/android-developer/answer/9859455) · [Health declaration](https://support.google.com/googleplay/android-developer/answer/14738291) · [Financial declaration](https://support.google.com/googleplay/android-developer/answer/13849271)

Prepare short reviewer instructions if a field or review response calls for them: dismiss or wait through the notice, choose Blank Sheet or Guided character creation, use Sections to navigate, and note that no login or network connection is required. Use an ordinary blank sheet to demonstrate unrestricted editing; guided mode intentionally limits legal starting purchases.

## 12 Run a small internal test through Google Play

First upload the signed candidate to **Testing → Internal testing**, add a small email list including you, provide release notes and use the tester opt-in link. Install from Play after preserving the old alpha's data. Internal testing supports up to 100 testers. Allow for first-upload processing or review rather than assuming instant availability. Internal testing is a useful delivery check, not the qualifying closed test. [Testing tracks](https://support.google.com/googleplay/android-developer/answer/9845334)

Check the actual download, launcher icon, offline behaviour, restore/import, privacy link and key gameplay flows. Then upload a second build with a higher version code and install its update from Play without uninstalling. Compare character IDs, ratings, creation progress, damage and the paid-dot ledger before and after. This validates the update path public users will receive.

Inspect **Latest releases and bundles**, the device catalogue and any generated pre-launch reports. Resolve crashes, startup failures, accessibility problems and compatibility warnings. Automated exploration may not reach the more specialised sorcery or creation paths, so retain the manual scenario checks.

**Done when:** two successive Play-delivered builds install and update correctly, preserving the same characters and history.

## 13 Complete the qualifying closed test

For a new personal account, Google currently requires **at least 12 testers continuously opted in for at least 14 days** before applying for production access. The eligible testers must still meet that continuity requirement when applying. Google also reviews engagement and feedback; meeting the count alone does not guarantee access. Our S24 FE testing and sideloaded APK sessions do not fulfil this Play-track requirement. [Personal-account testing requirements](https://support.google.com/googleplay/android-developer/answer/14151465)

Recruit around **15–20 real prospective users** as a practical buffer. Confirm they have Android 16 or later, a Google account they can use in Play, and time to try the app. Our chosen minimum makes checking device versions worthwhile before sending invitations.

Create a closed track, set the tester email list or Google Group, include the relevant countries, and publish the test release. Give each tester its opt-in link and installation instructions. People who used the internal track must opt out of that track before opting into closed testing. Adding an email address to a list is not the same as that person opting in. [Track membership and setup](https://support.google.com/googleplay/android-developer/answer/9845334)

Use this proposed test schedule rather than asking people merely to leave the app installed:

| Session | What testers should try | Evidence to collect |
| --- | --- | --- |
| First session | Install from Play; create and resume a guided character | Device/Android version; unclear steps; any blocked choices |
| Creation session | Clan dot, priorities, three Specialties, Merits, sorcery, Finish and Leave | Incorrect limits, missing explanations or duplicate XP |
| Ordinary play | Enter an existing character; track damage, Willpower, Vitae and Humanity | Editing difficulties or incorrect derived values |
| Advancement | Buy/refund traits and rituals; check the change log | Reproduction steps and expected/actual costs |
| Recovery | Rotate, background, reopen and try backup/export as supported | Lost state, duplicated changes or restore problems |
| Update session | Install a newer closed-test version without uninstalling | Confirmation that characters and history survived |

Keep a simple feedback log: date, build, device, scenario, issue, resolution and whether the tester confirmed the fix. Ask people to avoid sending real personal information; synthetic sheets are usually sufficient. Use a support mailbox, issue form or existing tester group that you can monitor.

Once the Console says the test qualifies, apply for production access. Describe who tested, the features they used, their actual feedback, changes made and why the build is ready. The application is distinct from review of the public release. Allow time for Google to request further testing. An organisation account does not use this specific new-personal-account gate, but should still complete meaningful release testing.

## 14 Submit the public release

After production access is granted and the candidate is ready:

1. Confirm the final countries, listing, privacy link, declarations and rating.
2. Freeze and tag the release commit; run the final tests and archive the signed bundle.
3. Use **Production → Create new release**, selecting the tested artifact or uploading a newer tested bundle.
4. Enter concise public release notes and resolve every blocking validation error.
5. Review **Publishing overview** and explicitly send the relevant changes for review.
6. Follow review messages. Fix the stated issue and resubmit, or provide evidence when the finding is incorrect.
7. Publish when the Console's review and publishing state allow it, then verify the public listing and installation from an eligible account outside the test tracks.

The first production release has **no percentage rollout option**; it becomes available in the selected countries. Use the closed test and intentional country selection to control initial exposure. Percentage-based staged rollouts are available for later updates. [Release rollout behaviour](https://support.google.com/googleplay/android-developer/answer/9859348)

For launch timing, inspect **Managed publishing** after the app is available on a test track. It cannot be used for an app's very first publication; Google recommends publishing a closed test first when planning to use it for launch. When enabled and applicable, it holds approved changes until you publish them. Otherwise approval may publish changes automatically. Leave at least a week of review buffer and avoid promising a precise launch date. [Review and publishing controls](https://support.google.com/googleplay/android-developer/answer/9859654)

## 15 Maintain the published app

Monitor Android vitals, review messages, support email and user reports after launch. Prioritise lost characters, broken saves, startup failures and incorrect XP changes. Record the affected app version and device before diagnosing a report; request a character file only when necessary and explain how it will be handled.

For each update, use the same app identity and Play signing setup, increase the version code, test existing saves, and run the internal update check. Promote the tested artifact and use a staged rollout where appropriate. If a problem appears, halt the rollout while preparing a fix. Halting does not remove the faulty version from phones that already received it; a corrective update needs a higher version code. [Staged updates](https://support.google.com/googleplay/android-developer/answer/6346149)

Review privacy declarations when adding SDKs, online features, accounts or new file handling. Keep support links and account verification current. Monitor Play's target-API and policy deadlines. Continue shipping iOS independently, with shared catalog/save tests guarding parity. Automatic release uploads, crash-reporting SDKs and additional marketplaces can be later improvements rather than requirements for this first launch.

## 16 Responsibilities and suggested order

| Work | Primary owner | Completion evidence |
| --- | --- | --- |
| Registration, legal identity and account verification | You | Console tasks complete |
| Publisher name, markets, audience and trader declaration | You, with the guide as preparation | Accurate account and app settings |
| Artwork/font permissions and final legal/privacy wording | You | Rights records and approved public policy |
| Alpha migration, export/import and backup configuration | Us working in the Android codebase | Restored files match originals |
| Release build and signing integration | Us; you retain control of credentials | Signed AAB and reproducible build notes |
| Store text, screenshots and graphics | We can prepare; you review | Complete store listing assets |
| Tester recruitment and feedback | You and your testers | Meaningful test sessions and issue log |
| Rules, UI, compatibility and update verification | Us and testers | Passing tests and device evidence |
| Declarations, submission and launch | You as publisher | Console approval and verified public listing |

**Suggested sequence:** finish account verification and recruit testers now; prepare migration, privacy and signing together; run internal Play installation/update tests; run the qualifying closed test; apply for production access; complete public review and launch. A planning allowance of roughly **four to six weeks** is sensible for a new personal account once preparation and recruitment are underway. Verification, finding compatible testers or review requests may extend it; it is not a guaranteed Google turnaround.

The known platform registration cost is US$25. Signing tools and our existing build tools do not require a separate purchase. Budget separately for any missing font/artwork rights and optional domain or hosting services. A simple public support/privacy site is enough; this offline release does not need an app backend.

## 17 Release checklist

- [ ] Account type, identity, contacts and device verification complete.
- [ ] Public publisher details and trader status reviewed.
- [ ] Permanent package name and initial markets chosen.
- [ ] Asset/font permissions and Dark Pack presentation reviewed.
- [ ] Android privacy policy published and linked inside the app.
- [ ] Backup and device-transfer behaviour explicitly configured and tested.
- [ ] Alpha characters exported or otherwise preserved and restore verified.
- [ ] Upload key backed up securely; Play App Signing configured.
- [ ] Release AAB signed, non-debuggable and archived with its commit/checksum.
- [ ] Target API, native-library compatibility and device support checked.
- [ ] Listing text, store icon, feature graphic and Android screenshots ready.
- [ ] App-content declarations and rating completed accurately.
- [ ] Two Play-delivered builds tested for installation and data-preserving updates.
- [ ] Closed test qualifies and real feedback has been acted on.
- [ ] Production access granted where required.
- [ ] Final release reviewed, publishing settings understood and launch approved.
- [ ] Public listing/install verified; support and maintenance routine in place.

The next engineering task is a release-preparation change covering **character migration/export and import, Android privacy access, explicit backup rules, and release signing configuration**. Account verification and tester recruitment can proceed alongside that work.
