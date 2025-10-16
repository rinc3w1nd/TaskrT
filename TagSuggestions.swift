import SwiftData

struct TagSuggestions {
    static func allTagNames(modelContext: ModelContext) -> [String] {
        let descriptor = FetchDescriptor<Tag>(predicate: nil, sortBy: [SortDescriptor(\.name, order: .forward)])
        let tags = (try? modelContext.fetch(descriptor)) ?? []
        return tags.map { $0.name }
    }

    static func ensureTags(from rawInput: String, in ctx: ModelContext) -> [Tag] {
        let pieces = rawInput
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var result: [Tag] = []
        for p in Set(pieces) {
            if let existing = try? ctx.fetch(FetchDescriptor<Tag>(predicate: #Predicate { $0.name == p }, fetchLimit: 1)).first {
                result.append(existing)
            } else {
                let t = Tag(name: p)
                ctx.insert(t)
                result.append(t)
            }
        }
        return result
    }
}