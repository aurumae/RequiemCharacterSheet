//
//  RequiemCharacterSheetApp.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 16/09/2024.
//

import SwiftUI

@main
struct RequiemCharacterSheetApp: App {
    @State private var store = CharacterStore()

    var body: some Scene {
        WindowGroup {
            SplashContainer {
                CharacterListView(store: store) { character in
                    CharacterSheetView(character: character, store: store)
                }
            }
            .task {
                // Earlier versions saved a single character in UserDefaults; move it into the store.
                // If it can't be read it's left where it is, so nothing is lost.
                do {
                    try store.migrateLegacySaveIfNeeded()
                } catch {
                    print("Couldn't move the previously saved character: \(error)")
                }
            }
        }
    }
}
