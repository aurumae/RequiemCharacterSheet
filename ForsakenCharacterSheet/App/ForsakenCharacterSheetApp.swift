//
//  ForsakenCharacterSheetApp.swift
//  ForsakenCharacterSheet
//

import SwiftUI

@main
struct ForsakenCharacterSheetApp: App {
    @State private var store = CharacterFileStore<ForsakenCharacter>()

    var body: some Scene {
        WindowGroup {
            SplashContainer {
                CharacterListView(store: store) { character in
                    ForsakenSheetView(character: character, store: store)
                }
            }
        }
    }
}
