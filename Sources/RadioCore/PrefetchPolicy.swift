/// Keep one extra ready track when the next song is shorter than the recent
/// generation budget. Generation remains serial; no rendered track is retried.
public enum PrefetchPolicy {
    public static func needsReserve(nextDuration: Double, longestGeneration: Double) -> Bool {
        nextDuration < max(60, longestGeneration * 1.5)
    }
}
