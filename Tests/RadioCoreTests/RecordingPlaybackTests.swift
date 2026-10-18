import XCTest
@testable import RadioCore

final class RecordingPlaybackTests: XCTestCase {
    func testSettingsMatchExcludesVolumeButIncludesGenerationChoices() {
        let settings = RadioSettings()
        var other = settings; other.volume = 0.1
        XCTAssertTrue(settings.matchesGeneration(other))
        other.duration = 120; XCTAssertFalse(settings.matchesGeneration(other))
        other = settings; other.vinyl.toggle(); XCTAssertFalse(settings.matchesGeneration(other))
        other = settings; other.customPrompt = "Rain"; XCTAssertFalse(settings.matchesGeneration(other))
        other = settings; other.station = .ambient; XCTAssertFalse(settings.matchesGeneration(other))
    }
    func testLegacyMatchNeedsRequestedDurationAndExactPrompt() {
        var settings = RadioSettings(); settings.selectStation(.ambient)
        let track = SavedTrack(title: "Untrusted title", path: "/missing", prompt: settings.prompt(index: 4, salt: 9, attempt: 2), seed: 4)
        XCTAssertTrue(track.matches(settings, legacyRequestedDuration: 180))
        XCTAssertFalse(track.matches(settings, legacyRequestedDuration: 120))
        XCTAssertFalse(track.matches(settings))
        settings.space.toggle(); XCTAssertFalse(track.matches(settings, legacyRequestedDuration: 180))
    }
    func testOldHistoryDecodesAndSnapshotRoundTrips() throws {
        var track = SavedTrack(title: "Old", path: "/old", prompt: "ambient", seed: 1)
        let old = try JSONEncoder().encode(track)
        XCTAssertNil(try JSONDecoder().decode(SavedTrack.self, from: old).generationSettings)
        track.generationSettings = RadioSettings()
        let decoded = try JSONDecoder().decode(SavedTrack.self, from: JSONEncoder().encode(track))
        XCTAssertEqual(decoded.generationSettings, track.generationSettings)
    }
    func testBackThenForwardRetainsOrderAndNewSelectionClearsForward() {
        let a = SavedTrack(title: "A", path: "a", prompt: "", seed: 1)
        let b = SavedTrack(title: "B", path: "b", prompt: "", seed: 2)
        let c = SavedTrack(title: "C", path: "c", prompt: "", seed: 3)
        var trail = PlaybackTrail(); trail.seed(older: [a, b])
        XCTAssertEqual(trail.previous(from: c)?.id, b.id)
        XCTAssertEqual(trail.previous(from: b)?.id, a.id)
        XCTAssertEqual(trail.next(from: a)?.id, b.id)
        XCTAssertEqual(trail.next(from: b)?.id, c.id)
        _ = trail.previous(from: c); trail.record(b)
        XCTAssertTrue(trail.forward.isEmpty)
        XCTAssertEqual(trail.back.last?.id, b.id)
    }
}
