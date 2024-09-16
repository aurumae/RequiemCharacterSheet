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
