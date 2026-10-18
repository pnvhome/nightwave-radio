import Foundation

public extension RadioSettings {
    func matchesGeneration(_ other: RadioSettings) -> Bool {
        var a = self, b = other
        a.volume = 0; b.volume = 0
        return a == b
    }
    func matchesLegacyPrompt(_ prompt: String) -> Bool {
        for salt in station.variations.indices {
            for attempt in 1...3 {
                if self.prompt(index: 0, salt: salt, attempt: attempt) == prompt { return true }
            }
        }
        return false
    }
}

public extension SavedTrack {
    func matches(_ settings: RadioSettings, legacyRequestedDuration: Int? = nil) -> Bool {
        if let generationSettings { return settings.matchesGeneration(generationSettings) }
        return legacyRequestedDuration == settings.duration && settings.matchesLegacyPrompt(prompt)
    }
}

/// Playback navigation is separate from the queue of freshly generated tracks.
public struct PlaybackTrail {
    public private(set) var back: [SavedTrack] = []
    public private(set) var forward: [SavedTrack] = []
    public init() {}
    public mutating func seed(older: [SavedTrack]) { back = older; forward = [] }
    public mutating func record(_ previous: SavedTrack?) {
        if let previous, back.last?.id != previous.id { back.append(previous) }
        forward = []
    }
    @discardableResult public mutating func previous(from current: SavedTrack?) -> SavedTrack? {
        guard let track = back.popLast() else { return nil }
        if let current { forward.append(current) }
        return track
    }
    @discardableResult public mutating func next(from current: SavedTrack?) -> SavedTrack? {
        guard let track = forward.popLast() else { return nil }
        if let current { back.append(current) }
        return track
    }
    public mutating func discardMissingPrevious() { _ = back.popLast() }
    public mutating func discardMissingNext() { _ = forward.popLast() }
}
