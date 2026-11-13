//
//  Extensions.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 20/09/2024.
//

extension Array {
    package func chunked(into size: Int) -> [[Element]] {
        var chunks = [[Element]]()
        var index = 0
        while index < self.count {
            let chunk = Array(self[index..<Swift.min(index + size, self.count)])
            chunks.append(chunk)
            index += size
        }
        return chunks
    }
}

extension KeyedDecodingContainer {
    /// Decodes the value for `key`, or returns `defaultValue` when the key is missing or null.
    /// Lets saves written before a field existed still load.
    package func decode<T: Decodable>(_ key: Key, default defaultValue: @autoclosure () -> T) throws -> T {
        try decodeIfPresent(T.self, forKey: key) ?? defaultValue()
    }
}

extension String {
    /// The text as VoiceOver should say it: dots as a count ("Crúac 2 dots" for "Crúac ••") and arrows as "to"
    /// ("1 to 3" for "1 → 3"), rather than "bullet bullet" or "right arrow".
    package var spokenForVoiceOver: String {
        var spoken = replacingOccurrences(of: " → ", with: " to ")
        while let range = spoken.range(of: "[•●]+", options: .regularExpression) {
            let count = spoken[range].count
            spoken.replaceSubrange(range, with: "\(count) \(count == 1 ? "dot" : "dots")")
        }
        return spoken.replacingOccurrences(of: "–", with: " to ")
    }
}
