import Foundation

/// Fuzzy matching for file paths with scoring.
public struct FuzzyMatch {

    public struct MatchResult {
        let score: Int
        let matchedIndices: [Int]
    }

    /// Perform a fuzzy match of the query against the target string.
    /// Returns nil if no match, otherwise the score and matched character indices.
    public static func match(_ query: String, against target: String) -> MatchResult? {
        guard !query.isEmpty else { return nil }

        let queryChars = Array(query.lowercased())
        let targetChars = Array(target.lowercased())
        var matchedIndices: [Int] = []
        var queryIndex = 0
        var targetIndex = 0
        var score = 0

        while queryIndex < queryChars.count && targetIndex < targetChars.count {
            let queryChar = queryChars[queryIndex]
            let targetChar = targetChars[targetIndex]

            if queryChar == targetChar {
                matchedIndices.append(targetIndex)

                // Scoring bonuses
                score += 10 // Base score for match

                // Bonus for consecutive matches
                if queryIndex > 0 && matchedIndices.count > 1 {
                    let prevIndex = matchedIndices[matchedIndices.count - 2]
                    if targetIndex == prevIndex + 1 {
                        score += 15 // Consecutive bonus
                    }
                }

                // Bonus for word boundary matches
                if targetIndex == 0 || isWordBoundary(targetChars[targetIndex - 1]) {
                    score += 30 // Word boundary bonus
                }

                // Bonus for path separator matches
                if targetChar == "/" || targetChar == "\\" {
                    score += 20 // Path separator bonus
                }

                // Bonus for camelCase matches
                if targetIndex > 0 && isUpperCase(targetChars[targetIndex]) && !isUpperCase(targetChars[targetIndex - 1]) {
                    score += 25 // CamelCase bonus
                }

                queryIndex += 1
            }
            targetIndex += 1
        }

        // Only return a match if all query characters were matched
        guard queryIndex == queryChars.count else { return nil }

        // Penalty for longer gaps between matches
        if matchedIndices.count > 1 {
            for i in 1..<matchedIndices.count {
                let gap = matchedIndices[i] - matchedIndices[i - 1]
                score -= gap * 2
            }
        }

        return MatchResult(score: score, matchedIndices: matchedIndices)
    }

    private static func isWordBoundary(_ char: Character) -> Bool {
        return char == "_" || char == "-" || char == "/" || char == "\\" || char == "."
    }

    private static func isUpperCase(_ char: Character) -> Bool {
        return char.isASCII && char.isUppercase
    }

    /// Filter and sort items based on fuzzy match against the query.
    public static func filterAndSort(_ items: [String], query: String) -> [(item: String, indices: [Int])] {
        guard !query.isEmpty else { return items.map { ($0, []) } }

        var results: [(item: String, score: Int, indices: [Int])] = []

        for item in items {
            if let match = match(query, against: item) {
                results.append((item, match.score, match.matchedIndices))
            }
        }

        // Sort by score (descending)
        results.sort { $0.score > $1.score }

        return results.map { ($0.item, $0.indices) }
    }
}
