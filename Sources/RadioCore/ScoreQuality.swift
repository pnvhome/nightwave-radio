import Foundation

/// A conservative symbolic check, not an audio similarity detector.
public enum ScoreQuality {
    public static func hasDominantMelodicLoop(_ abc: String) -> Bool {
        var instrument = false
        var bars: [String] = []
        for raw in abc.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.hasPrefix("V:") { instrument = line.dropFirst(2).trimmingCharacters(in: .whitespaces).hasPrefix("Ins"); continue }
            guard instrument, !line.isEmpty, !line.hasPrefix("%"), !line.contains(":") else { continue }
            let notes = line.replacingOccurrences(of: "\"[^\"]*\"", with: "", options: .regularExpression)
                .replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
            bars.append(contentsOf: notes.split(separator: "|").map(String.init))
        }
        guard bars.count >= 32 else { return false }
        // Non-overlapping four-bar phrases avoid counting one sustained note
        // or one long phrase several times at adjacent offsets.
        for offset in 0..<4 {
            var counts: [String: Int] = [:]
            for start in stride(from: offset, through: bars.count - 4, by: 4) {
                let phrase = bars[start..<start + 4].joined(separator: "|")
                let pitches = Set(phrase.filter { "ABCDEFGabcdefg".contains($0) })
                guard pitches.count >= 3 else { continue } // allow rests and drones
                counts[phrase, default: 0] += 1
            }
            if counts.values.contains(where: { $0 >= 5 && $0 * 4 * 4 >= bars.count }) { return true }
        }
        return false
    }
    public struct Repetitive: LocalizedError {
        public init() {}
        public var errorDescription: String? { "Instrumental score repeats the same melodic phrase too often" }
    }
}
