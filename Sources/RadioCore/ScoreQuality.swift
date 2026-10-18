import Foundation

/// A conservative symbolic check, not an audio similarity detector.
public enum ScoreQuality {
    public static func hasDominantMelodicLoop(_ abc: String) -> Bool {
        var voice = ""
        var melody: [String] = []
        var harmony: [String] = []
        for raw in abc.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.hasPrefix("V:") {
                voice = line.dropFirst(2).trimmingCharacters(in: .whitespaces).components(separatedBy: " ")[0]
                continue
            }
            guard !line.isEmpty, !line.hasPrefix("%"), !line.contains(":") else { continue }
            let bars = line.replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
                .split(separator: "|").map(String.init)
            if voice == "Ins" { melody.append(contentsOf: bars) }
            if voice == "Vocal" { harmony.append(contentsOf: bars) }
        }
        guard melody.count >= 32, harmony.isEmpty || harmony.count == melody.count else { return false }
        // Only uninterrupted runs count. Returning themes and changing harmony
        // are musical development, even when the melody itself repeats.
        for offset in 0..<4 {
            var previous = ""
            var run = 0
            for start in stride(from: offset, through: melody.count - 4, by: 4) {
                let notes = melody[start..<start + 4].joined(separator: "|")
                let pitchesOnly = notes.replacingOccurrences(of: "\"[^\"]*\"", with: "", options: .regularExpression)
                let pitches = Set(pitchesOnly.filter { "ABCDEFGabcdefg".contains($0) })
                guard pitches.count >= 3 else { previous = ""; run = 0; continue }
                let chords = harmony.isEmpty ? "" : harmony[start..<start + 4].joined(separator: "|")
                let phrase = notes + "\n" + chords
                run = phrase == previous ? run + 1 : 1
                previous = phrase
                if run >= 8 { return true }
            }
        }
        return false
    }
    public struct Repetitive: LocalizedError {
        public init() {}
        public var errorDescription: String? { "Instrumental score repeats the same melodic phrase too often" }
    }
}
