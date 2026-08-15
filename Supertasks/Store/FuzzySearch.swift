import Foundation

/// Small hand-written fuzzy matcher replacing Fuse.js — this app's lists (tasks, projects,
/// commands) are small enough that a naive scorer is plenty fast.
enum FuzzySearch {
    /// Higher is better; nil means "no match at all".
    static func score(text: String, query: String) -> Int? {
        guard !query.isEmpty else { return 0 }
        let t = text.lowercased()
        let q = query.lowercased()
        if t == q { return 1000 }
        if t.hasPrefix(q) { return 800 }
        if t.contains(q) { return 600 }

        // Subsequence match (letters of the query appear in order, not necessarily adjacent).
        var qIdx = q.startIndex
        var matched = 0
        for ch in t {
            if qIdx == q.endIndex { break }
            if ch == q[qIdx] { qIdx = q.index(after: qIdx); matched += 1 }
        }
        guard qIdx == q.endIndex else { return nil }
        return 200 + matched
    }

    static func matches(_ text: String, query: String) -> Bool {
        score(text: text, query: query) != nil
    }

    /// Filters + ranks `items` against `query`, scored across all of `keys(item)`, best match wins.
    /// Returns `items` unchanged when `query` is blank.
    static func search<T>(_ items: [T], query: String, keys: (T) -> [String]) -> [T] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return items }
        let scored: [(T, Int)] = items.compactMap { item in
            guard let best = keys(item).compactMap({ score(text: $0, query: trimmed) }).max() else { return nil }
            return (item, best)
        }
        return scored.sorted { $0.1 > $1.1 }.map(\.0)
    }
}
