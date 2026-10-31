//
//  Extensions.swift
//  RequiemCharacterSheet
//
//  Created by Oisín McColgan on 20/09/2024.
//

extension Array {
    func chunked(into size: Int) -> [[Element]] {
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
    func decode<T: Decodable>(_ key: Key, default defaultValue: @autoclosure () -> T) throws -> T {
        try decodeIfPresent(T.self, forKey: key) ?? defaultValue()
    }
}
