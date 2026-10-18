import XCTest
import AVFoundation
import RadioCore
@testable import NightwaveRadio

@MainActor
final class CrossfadeTests: XCTestCase {
    private func fixture() throws -> (RadioController, SavedTrack, SavedTrack, URL) {
        guard ProcessInfo.processInfo.environment["NIGHTWAVE_AUDIO_TESTS"] == "1" else {
            throw XCTSkip("Set NIGHTWAVE_AUDIO_TESTS=1 on a Mac with an audio output device")
        }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("nightwave-crossfade-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let url = root.appendingPathComponent("silent.caf")
        let format = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 48000 * 8)!
        buffer.frameLength = buffer.frameCapacity
        for channel in 0..<2 { buffer.floatChannelData![channel].initialize(repeating: 0, count: Int(buffer.frameLength)) }
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
        let radio = RadioController(dataDirectory: root, tracksDirectory: root, modelURL: root.appendingPathComponent("no-model"))
        var first = SavedTrack(title: "First", path: url.path, prompt: "", seed: 1)
        var next = SavedTrack(title: "Next", path: url.path, prompt: "", seed: 2)
        first.durationSeconds = 8; next.durationSeconds = 8
        return (radio, first, next, root)
    }
    private func waitForFade(_ radio: RadioController) async throws {
        let deadline = Date().addingTimeInterval(3)
        while radio.fadingPlayer == nil && Date() < deadline { try await Task.sleep(nanoseconds: 50_000_000) }
        XCTAssertNotNil(radio.fadingPlayer)
    }
    func testAutomaticOverlapPauseVolumeAndCompletion() async throws {
        let (radio, first, next, root) = try fixture()
        defer { radio.stop(); try? FileManager.default.removeItem(at: root) }
        try radio.play(first); radio.queued = next
        radio.seek(6.2)
        try await waitForFade(radio)
        XCTAssertEqual(radio.current?.id, next.id)
        XCTAssertNil(radio.queued)
        XCTAssertTrue(radio.player?.isPlaying == true && radio.fadingPlayer?.isPlaying == true)
        radio.togglePause()
        let time = radio.player!.currentTime
        try await Task.sleep(nanoseconds: 150_000_000)
        XCTAssertEqual(radio.player!.currentTime, time, accuracy: 0.05)
        XCTAssertFalse(radio.fadingPlayer!.isPlaying)
        radio.settings.volume = 0.4
        XCTAssertEqual(radio.player!.volume + radio.fadingPlayer!.volume, 0.4, accuracy: 0.001)
        radio.togglePause()
        try await Task.sleep(nanoseconds: 2_100_000_000)
        XCTAssertNil(radio.fadingPlayer)
        XCTAssertEqual(radio.current?.id, next.id) // outgoing delegate cannot skip the new song
        XCTAssertEqual(radio.player!.volume, 0.4, accuracy: 0.001)
    }
    func testSeekAndStopDisposeOfOutgoingPlayer() async throws {
        let (radio, first, next, root) = try fixture()
        defer { radio.stop(); try? FileManager.default.removeItem(at: root) }
        try radio.play(first); radio.queued = next; radio.seek(6.2)
        try await waitForFade(radio)
        let outgoing = radio.fadingPlayer!
        radio.seek(2)
        XCTAssertNil(radio.fadingPlayer); XCTAssertFalse(outgoing.isPlaying)
        radio.queued = first; radio.seek(6.2)
        try await waitForFade(radio)
        let a = radio.player!, b = radio.fadingPlayer!
        radio.stop()
        XCTAssertFalse(a.isPlaying); XCTAssertFalse(b.isPlaying)
        XCTAssertNil(radio.player); XCTAssertNil(radio.fadingPlayer)
    }
    func testManualSkipStaysImmediateAndEmptyQueueDoesNotFade() async throws {
        let (radio, first, next, root) = try fixture()
        defer { radio.stop(); try? FileManager.default.removeItem(at: root) }
        try radio.play(first); radio.seek(6.2)
        try await Task.sleep(nanoseconds: 150_000_000)
        XCTAssertNil(radio.fadingPlayer)
        radio.queued = next; radio.skip()
        XCTAssertEqual(radio.current?.id, next.id)
        XCTAssertNil(radio.fadingPlayer)
        XCTAssertLessThan(radio.player!.currentTime, 0.5)
    }
}
