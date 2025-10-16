import Foundation
import SwiftData

struct TagSuggestions {
    static func allTagNames(modelContext: ModelContext) -> [String] {
        let descriptor = FetchDescriptor<Tag>()
        let tags = (try? modelContext.fetch(descriptor)) ?? []
        return tags
            .sorted { lhs, rhs in
                lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            .map { $0.name }
    }

    static func ensureTags(from rawInput: String, in ctx: ModelContext) -> [Tag] {
        let pieces = rawInput
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !pieces.isEmpty else { return [] }

        let descriptor = FetchDescriptor<Tag>()
        let existing = (try? ctx.fetch(descriptor)) ?? []
        var cache = Dictionary(uniqueKeysWithValues: existing.map { ($0.name, $0) })

        var seen = Set<String>()
        var orderedNames: [String] = []
        for piece in pieces {
            if seen.insert(piece).inserted {
                orderedNames.append(piece)
            }
        }

        var result: [Tag] = []
        for name in orderedNames {
            if let found = cache[name] {
                result.append(found)
                continue
            }

            let newTag = Tag(name: name)
            ctx.insert(newTag)
            cache[name] = newTag
            result.append(newTag)
        }
        return result
    }
}
