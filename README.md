# Requiem Character Sheet

Native character-sheet apps for Vampire: The Requiem, Second Edition.

| Platform | Project | Development guide |
| --- | --- | --- |
| iOS | `RequiemCharacterSheet.xcodeproj`, Swift/SwiftUI | Open the existing Xcode project. |
| Android 16+ | `android/`, Kotlin/Jetpack Compose | [Build, run and test Android](android/README.md) |

Both applications use the JSON books in `RequiemCharacterSheet/Catalogs/` and the compatibility examples in `shared/fixtures/`. They read character schemas 1–10 and write schema 10. Shared-file compatibility does not provide automatic device synchronization; Android export/import remains release-preparation work.

Use short-lived `ios/…`, `android/…` or `shared/…` feature branches, then integrate tested changes into `main` through a pull request. Separate working folders keep Xcode and Android Studio independent. Each platform can release from its own tested commit with its own version number. GitHub CI checks the Kotlin app, Swift/Kotlin save exchange, and the Xcode app with its iOS unit tests. iOS UI tests run in Xcode Cloud and locally; GitHub skips that target because its macOS runner can time out on UI snapshot queries.

- [Android port history and architecture](docs/android-port-plan.md)
- [iOS 1.3 parity implementation and acceptance](docs/ios-1.3-parity-plan.md)
- [Google Play release guide](docs/play-store-release-guide.md)

The existing [iOS privacy policy](https://gist.github.com/aurumae/5a83610184c4f0e4b14b514ac508a1a9) covers the iOS release. An Android policy and in-app link are still required before Play publication.
