import XCTest
import AVFoundation
import AudioToolbox
@testable import RadioCore
final class RadioCoreTests: XCTestCase {
    func testPrivateModelLocationAndSavedExternalModel() throws {
        XCTAssertTrue(ModelLibrary.defaultURL.path.contains("Application Support/Nightwave Radio/Models/"))
        XCTAssertNotEqual(ModelLibrary.defaultURL, ModelLibrary.legacyURL)
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        for name in ModelLibrary.requiredFiles { try Data([1]).write(to: folder.appendingPathComponent(name)) }
        XCTAssertEqual(ModelLibrary.preferredURL(saved: folder), folder)
    }

    func testDownloadProgressCountsPartialOnceAndCapsAtExpectedSize() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        XCTAssertEqual(ModelDownloadProgress(directory: folder).received, 0)
        try Data(repeating: 0, count: 500).write(to: folder.appendingPathComponent("config.json.partial"))
        XCTAssertEqual(ModelDownloadProgress(directory: folder).received, 500)
        try Data(repeating: 0, count: 2000).write(to: folder.appendingPathComponent("config.json"))
        let progress = ModelDownloadProgress(directory: folder)
        XCTAssertEqual(progress.received, 1042)
        XCTAssertEqual(progress.remaining + progress.received, progress.total)
        XCTAssertGreaterThan(progress.fraction, 0)
    }

    func testEveryStationUsesInstrumentalAdapterAndFreshFullScore() throws {
        for station in Station.allCases {
            var settings = RadioSettings()
            settings.station = station
            let body = settings.request(model: "installed-yue2", index: 2, salt: 17, seed: 42)
            XCTAssertEqual(body["instrumental"] as? Bool, true)
            XCTAssertEqual(body["cot"] as? String, "full")
            XCTAssertEqual(body["steps"] as? Int, 32)
            XCTAssertEqual(body["stream"] as? Bool, true)
            XCTAssertNil(body["lyrics"])
            XCTAssertNil(body["abc"])
            XCTAssertEqual(body["model"] as? String, "installed-yue2")
        }
    }
    func testQuietLofiPreservesItsCharacterAndCustomPrompt() {
        var s = RadioSettings()
        s.customPrompt = "Warm Rhodes, rainy evening"
        s.beatless = true
        s.softDrums = true
        let first = s.prompt(index: 0, salt: 1)
        XCTAssertTrue(first.contains("Warm Rhodes, rainy evening"))
        XCTAssertTrue(first.contains("no drums"))
        XCTAssertFalse(first.contains("brushed drums"))
        XCTAssertNotEqual(first, s.prompt(index: 1, salt: 1))
        XCTAssertFalse(first.contains("fast, driving"))
    }
    func testPresetsChooseSuitableTextureWithoutDiscardingCustomPrompt() {
        var s = RadioSettings(); s.customPrompt = "rain"
        s.selectStation(.ambient)
        XCTAssertTrue(s.beatless); XCTAssertFalse(s.softDrums); XCTAssertFalse(s.vinyl)
        s.selectStation(.cyberpunk)
        XCTAssertTrue(s.darkMood); XCTAssertFalse(s.beatless)
        XCTAssertEqual(s.customPrompt, "rain")
    }
    func testSettingsRoundTrip() throws {
        var s = RadioSettings(); s.station = .synthwave; s.space = false; s.customPrompt = "analog synths"
        XCTAssertEqual(try JSONDecoder().decode(RadioSettings.self, from: JSONEncoder().encode(s)), s)
    }
    func testModelDiscoveryRejectsPartialDownloads() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        XCTAssertFalse(ModelLibrary.isComplete(root))
        for file in ModelLibrary.requiredFiles { try Data([1]).write(to: root.appendingPathComponent(file)) }
        XCTAssertTrue(ModelLibrary.isComplete(root))
        try Data().write(to: root.appendingPathComponent("model.safetensors"))
        XCTAssertFalse(ModelLibrary.isComplete(root))
    }
    func testTransferArtifactsMatchWavStem() {
        let url = URL(fileURLWithPath: "/tmp/track.wav")
        XCTAssertEqual(TrackFiles.sidecar(url, extension: "original.abc").path, "/tmp/track.original.abc")
    }
}

final class UsageStatsTests: XCTestCase {
    func testTotalsRecordOnlyCompletedTracksAndComputeSpeed() throws {
        var stats = UsageTotals()
        XCTAssertNil(stats.generationSpeed)
        stats.recordTrack(duration: 180, generation: 90)
        stats.recordTrack(duration: 120, generation: 60)
        XCTAssertEqual(stats.tracks, 2)
        XCTAssertEqual(stats.musicSeconds, 300)
        XCTAssertEqual(stats.generationSpeed, 2)
        stats.recordTrack(duration: 1000, generation: 0)
        XCTAssertEqual(stats.generationSpeed, 2, "Historical files with unknown generation time must not inflate speed")
        XCTAssertEqual(try JSONDecoder().decode(UsageTotals.self, from: JSONEncoder().encode(stats)), stats)
    }
    func testCpuUsesIntervalsAndOneCoreConvention() {
        let old = ProcessCounters(pid: 5, residentBytes: 10, cpuNanoseconds: 1_000_000_000, uptime: 10)
        let new = ProcessCounters(pid: 5, residentBytes: 20, cpuNanoseconds: 4_000_000_000, uptime: 12)
        XCTAssertEqual(new.cpuPercent(since: old), 150)
        XCTAssertNil(new.cpuPercent(since: nil))
        XCTAssertNil(ProcessCounters(pid: 6, residentBytes: 0, cpuNanoseconds: 9_000_000_000, uptime: 14).cpuPercent(since: new))
        XCTAssertNil(old.cpuPercent(since: new))
    }
    func testOldTrackHistoryRemainsDecodable() throws {
        let json = """
        {"id":"12345678-1234-1234-1234-123456789012","title":"Lo-Fi","path":"/tmp/a.wav","date":0,"prompt":"piano","seed":42}
        """
        let track = try JSONDecoder().decode(SavedTrack.self, from: Data(json.utf8))
        XCTAssertNil(track.durationSeconds)
        XCTAssertNil(track.generationSeconds)
    }
}

final class AudioArchiveTests: XCTestCase {
    func testNativeAACPreservesStereoAndDurationAndDoesNotReplaceExistingFiles() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        // Two seconds of PCM16 stereo, 48 kHz.
        let frames = 96_000
        var wav = Data()
        func text(_ s: String) { wav.append(contentsOf: s.utf8) }
        func u16(_ n: UInt16) { var n = n.littleEndian; withUnsafeBytes(of: &n) { wav.append(contentsOf: $0) } }
        func u32(_ n: UInt32) { var n = n.littleEndian; withUnsafeBytes(of: &n) { wav.append(contentsOf: $0) } }
        text("RIFF"); u32(UInt32(36 + frames * 4)); text("WAVEfmt "); u32(16)
        u16(1); u16(2); u32(48_000); u32(192_000); u16(4); u16(16); text("data"); u32(UInt32(frames * 4))
        for i in 0..<frames {
            let value = Int16(sin(Double(i) * 440 * 2 * .pi / 48_000) * 12_000)
            u16(UInt16(bitPattern: value)); u16(UInt16(bitPattern: value))
        }
        let old = root.appendingPathComponent("old.wav"); try wav.write(to: old)
        let target = root.appendingPathComponent("track.m4a")
        try AudioArchive.saveM4A(wav: wav, to: target)
        let file = try AVAudioFile(forReading: target)
        XCTAssertEqual(file.fileFormat.settings[AVFormatIDKey] as? UInt32, kAudioFormatMPEG4AAC)
        XCTAssertEqual(file.processingFormat.channelCount, 2)
        XCTAssertEqual(Double(file.length) / file.processingFormat.sampleRate, 2, accuracy: 0.05)
        XCTAssertLessThan(try Data(contentsOf: target).count, wav.count / 2)
        XCTAssertEqual(try Data(contentsOf: old), wav)
        let before = try Data(contentsOf: target)
        XCTAssertThrowsError(try AudioArchive.saveM4A(wav: wav, to: target))
        XCTAssertEqual(try Data(contentsOf: target), before)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path).sorted(), ["old.wav", "track.m4a"])
    }
}

final class GenerationRetryTests: XCTestCase {
    func testOnlyRejectedOrTruncatedPlansRetryAndAlwaysStopAtThree() {
        for text in ["Instrumental score validation failed; check the native Vocal/Ins ABC format and local Python 3.9+",
                     "Instrumental score planning was truncated; retry with a fresh seed"] {
            XCTAssertTrue(GenerationRetry.shouldRetry(text, completedAttempts: 1))
            XCTAssertTrue(GenerationRetry.shouldRetry(text, completedAttempts: 2))
            XCTAssertFalse(GenerationRetry.shouldRetry(text, completedAttempts: 3))
            XCTAssertFalse(GenerationRetry.shouldRetry(text, completedAttempts: 4))
        }
        for text in ["Instrumental Only requires local Python 3.9+", "Instrumental Only requires the bundled YuE2 instrumental AR LoRA", "Out of memory", "Connection refused"] {
            XCTAssertFalse(GenerationRetry.shouldRetry(text, completedAttempts: 1))
        }
    }
}


final class RetryExecutionTests: XCTestCase {
    private struct Failure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }
    @MainActor func testRejectedScoreIsReplacedBySuccessfulNextAttempt() async throws {
        var calls = 0
        var notices: [Int] = []
        let result: Int = try await GenerationRetry.perform(operation: {
            calls += 1
            if calls == 1 { throw Failure(message: "Instrumental score validation failed") }
            return 42
        }, onRetry: { notices.append($0) })
        XCTAssertEqual(result, 42)
        XCTAssertEqual(calls, 2)
        XCTAssertEqual(notices, [2])
    }
    @MainActor func testRejectedScoresStopAfterThreeActualCalls() async {
        var calls = 0
        do {
            let _: Int = try await GenerationRetry.perform(operation: {
                calls += 1
                throw Failure(message: "Instrumental score validation failed")
            })
            XCTFail("Must stop after three failures")
        } catch {
            XCTAssertTrue(error is GenerationRetry.Exhausted)
            XCTAssertEqual(calls, 3)
        }
    }
    @MainActor func testMissingRuntimeDoesNotLoop() async {
        var calls = 0
        do {
            let _: Int = try await GenerationRetry.perform(operation: {
                calls += 1
                throw Failure(message: "Instrumental Only requires local Python 3.9+")
            })
            XCTFail("Missing runtime must propagate")
        } catch {
            XCTAssertFalse(error is GenerationRetry.Exhausted)
            XCTAssertEqual(calls, 1)
        }
    }
}

final class AdaptiveCompositionTests: XCTestCase {
    func testRetriesChangeArrangementButPreserveUserChoicesAndInstrumentalPipeline() {
        var settings = RadioSettings()
        settings.selectStation(.ambient)
        settings.customPrompt = "soft cello and distant bells"
        settings.vinyl = true
        let requests = (1...3).map { settings.request(model: "yue2", index: 5, salt: 7, seed: 42, attempt: $0) }
        let prompts = requests.map { $0["prompt"] as! String }
        XCTAssertEqual(Set(prompts).count, 3)
        for (request, prompt) in zip(requests, prompts) {
            XCTAssertEqual(request["instrumental"] as? Bool, true)
            XCTAssertEqual(request["cot"] as? String, "full")
            XCTAssertEqual(request["duration_seconds"] as? Int, 180)
            XCTAssertTrue(prompt.contains(settings.customPrompt))
            XCTAssertTrue(prompt.contains("no drums"))
            XCTAssertTrue(prompt.contains("vinyl"))
            XCTAssertTrue(prompt.contains("contrasting middle section"))
        }
    }
    func testFirstAttemptRetainsExistingNonAmbientPrompt() {
        let settings = RadioSettings()
        XCTAssertEqual(settings.prompt(index: 0, salt: 0), "Instrumental lo-fi chillhop, warm Rhodes piano, mellow bass, relaxed slow groove, cozy late-night atmosphere, gentle electric piano motif, subtle vinyl crackle and warm tape saturation, soft restrained brushed drums, spacious gentle reverb")
    }
}

final class ScoreQualityTests: XCTestCase {
    func score(_ phrases: [String]) -> String {
        "X:1\nK:C\n" + phrases.map { "V: Vocal\nz8|z8|z8|z8|\nV: Ins\n" + $0 }.joined(separator: "\n")
    }
    func testAllowsReturningThemeAcrossSeparatedSections() {
        let repeated = "C2D2E2F2|G2A2B2c2|d2e2f2g2|a2b2c2d2|"
        let phrases = (0..<20).map { $0 % 4 == 0 ? repeated : "C8|D8|E8|F\($0 + 1)|" }
        XCTAssertFalse(ScoreQuality.hasDominantMelodicLoop(score(phrases)))
    }
    func testAllowsVariedCompositionAndRestOrDroneTextures() {
        XCTAssertFalse(ScoreQuality.hasDominantMelodicLoop(score((0..<20).map { "C8|D8|E8|F\($0 + 1)|" })))
        XCTAssertFalse(ScoreQuality.hasDominantMelodicLoop(score(Array(repeating: "z8|C8|C8|z8|", count: 20))))
        XCTAssertFalse(ScoreQuality.hasDominantMelodicLoop(score(Array(repeating: "CDEFGABc|C8|D8|E8|", count: 3))))
    }
    func testMusicalRepetitionDoesNotTriggerExpensiveRegeneration() {
        XCTAssertFalse(GenerationRetry.shouldRetry(ScoreQuality.Repetitive().localizedDescription, completedAttempts: 1))
        XCTAssertFalse(GenerationRetry.shouldRetry(ScoreQuality.Repetitive().localizedDescription, completedAttempts: 3))
    }
}

final class ConsecutiveScoreLoopTests: XCTestCase {
    let phrase = "C2D2E2F2|G2A2B2c2|d2e2f2g2|a2b2c2d2|"
    func score(changingHarmony: Bool, variationAt: Int? = nil, count: Int = 8) -> String {
        (0..<count).map { i in
            let chord = changingHarmony && i % 2 == 1 ? "G" : "C"
            let harmony = Array(repeating: "\"\(chord)\"z8|", count: 4).joined()
            let notes = variationAt == i ? "C8|D8|E8|F8|" : phrase
            return "V: Vocal\n" + harmony + "\nV: Ins\n" + notes
        }.joined(separator: "\n")
    }
    func testRejectsOnlyLongUninterruptedUnchangedRuns() {
        XCTAssertTrue(ScoreQuality.hasDominantMelodicLoop(score(changingHarmony: false)))
        XCTAssertFalse(ScoreQuality.hasDominantMelodicLoop(score(changingHarmony: false, count: 7)))
        XCTAssertFalse(ScoreQuality.hasDominantMelodicLoop(score(changingHarmony: false, variationAt: 4, count: 12)))
        XCTAssertFalse(ScoreQuality.hasDominantMelodicLoop(score(changingHarmony: true, count: 20)))
    }
}

final class PlaybackContinuityRetryTests: XCTestCase {
    @MainActor func testMusicalQualityFailureCannotLaunchAnotherFullGeneration() async {
        var generations = 0
        do {
            let _: Int = try await GenerationRetry.perform(operation: {
                generations += 1
                throw ScoreQuality.Repetitive()
            })
            XCTFail("Expected error")
        } catch {
            XCTAssertTrue(error is ScoreQuality.Repetitive)
            XCTAssertEqual(generations, 1)
        }
    }
}
