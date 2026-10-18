import SwiftUI
import AppKit
import AVFoundation
import RadioCore

@MainActor
final class RadioController: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var settings = RadioSettings() { didSet { saveSettings(); player?.volume = settings.volume } }
    @Published var running = false
    @Published var downloading = false
    @Published var downloadProgress = ModelDownloadProgress(directory: ModelLibrary.defaultURL)
    @Published var paused = false
    @Published var modelAvailable = false
    @Published var status = "Your music. Your rhythm."
    @Published var generationProgress: Double?
    @Published var error: String?
    @Published var current: SavedTrack?
    @Published var queued: SavedTrack?
    private var reserve: SavedTrack?
    private var longestGenerationSeconds: Double = 0
    @Published var history: [SavedTrack] = []
    @Published var usage = UsageTotals()
    @Published var sessionUsage = UsageTotals()
    @Published var resources = ResourceSnapshot()
    @Published var lastGenerationSeconds: Double?
    private let resourceMonitor = ResourceMonitor()
    private var lastResourceSample: Double = 0
    private var lastUsageSave: Double = 0
    private var lastPlaybackTick: Double = ProcessInfo.processInfo.systemUptime
    private var folderScanPending = false
    private var lastFolderScan: Double = 0
    @Published var elapsed: TimeInterval = 0
    @Published var total: TimeInterval = 0
    let dataDirectory: URL
    let tracksDirectory: URL
    let engine: LocalEngine
    private var modelURL: URL = ModelLibrary.defaultURL
    private var player: AVAudioPlayer?
    private var task: Task<Void, Never>?
    private var timer: Timer?
    private var runID = UUID()
    private var salt = Int.random(in: 0...10_000)
    private var index = 0
    private var generationAttempt = 1
    init(dataDirectory customData: URL? = nil, tracksDirectory customTracks: URL? = nil, modelURL customModel: URL? = nil) {
        let fm = FileManager.default
        dataDirectory = customData ?? fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Nightwave Radio")
        tracksDirectory = customTracks ?? fm.homeDirectoryForCurrentUser.appendingPathComponent("Music/Nightwave Radio")
        try? fm.createDirectory(at: dataDirectory, withIntermediateDirectories: true)
        try? fm.createDirectory(at: tracksDirectory, withIntermediateDirectories: true)
        engine = LocalEngine(dataDirectory: dataDirectory)
        super.init()
        if let data = try? Data(contentsOf: dataDirectory.appendingPathComponent("settings.json")), let saved = try? JSONDecoder().decode(RadioSettings.self, from: data) { settings = saved }
        if let customModel { modelURL = customModel }
        else {
            let saved = UserDefaults.standard.string(forKey: "modelPath").map { URL(fileURLWithPath: $0) }
            modelURL = ModelLibrary.preferredURL(saved: saved)
        }
        if let data = try? Data(contentsOf: dataDirectory.appendingPathComponent("history.json")), let saved = try? JSONDecoder().decode([SavedTrack].self, from: data) { history = saved }
        if let data = try? Data(contentsOf: dataDirectory.appendingPathComponent("usage.json")),
           let saved = try? JSONDecoder().decode(UsageTotals.self, from: data) { usage = saved }
        else {
            // Existing archives predate usage counters. Import completed files
            // without inventing historical listening or generation time.
            for index in history.indices {
                if history[index].durationSeconds == nil,
                   let audio = try? AVAudioFile(forReading: URL(fileURLWithPath: history[index].path)) {
                    history[index].durationSeconds = Double(audio.length) / audio.processingFormat.sampleRate
                }
                usage.recordTrack(duration: history[index].durationSeconds ?? 0,
                                  generation: history[index].generationSeconds ?? 0)
            }
            saveUsage()
        }
        refreshModel()
        sampleResources()
        timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }
    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        let delta = now - lastPlaybackTick
        if player?.isPlaying == true, delta > 0, delta < 5 {
            usage.listeningSeconds += delta; sessionUsage.listeningSeconds += delta
        }
        lastPlaybackTick = now
        elapsed = player?.currentTime ?? 0
        if now - lastResourceSample >= 2 {
            if downloading { downloadProgress = ModelDownloadProgress(directory: ModelLibrary.defaultURL) }
            sampleResources()
        }
        if now - lastUsageSave >= 30 { saveUsage() }
    }
    private func saveUsage() {
        if let data = try? JSONEncoder().encode(usage) {
            try? data.write(to: dataDirectory.appendingPathComponent("usage.json"), options: .atomic)
        }
        lastUsageSave = ProcessInfo.processInfo.systemUptime
    }
    private func sampleResources() {
        let now = ProcessInfo.processInfo.systemUptime
        var sample = resourceMonitor.sample(enginePID: engine.processID, tracksURL: tracksDirectory)
        sample.tracksBytes = resources.tracksBytes
        resources = sample; lastResourceSample = now
        if !folderScanPending && (lastFolderScan == 0 || now - lastFolderScan > 30) {
            folderScanPending = true; lastFolderScan = now
            let directory = tracksDirectory
            Task {
                let bytes = await Task.detached(priority: .utility) { ResourceMonitor.folderBytes(directory) }.value
                resources.tracksBytes = bytes; folderScanPending = false
            }
        }
    }
    var modelPath: String { modelURL.path }
    var isPlaying: Bool { player != nil && !paused }
    var busy: Bool { running || downloading }
    func openModelFolder() {
        var folder = downloading ? ModelLibrary.defaultURL : modelURL
        var isDirectory: ObjCBool = false
        while !FileManager.default.fileExists(atPath: folder.path, isDirectory: &isDirectory) || !isDirectory.boolValue {
            let parent = folder.deletingLastPathComponent()
            guard parent != folder else { return }
            folder = parent
        }
        NSWorkspace.shared.open(folder)
    }
    func refreshModel() { modelAvailable = ModelLibrary.isComplete(modelURL) }
    private func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) { try? data.write(to: dataDirectory.appendingPathComponent("settings.json"), options: .atomic) }
    }
    private func saveHistory() throws {
        try JSONEncoder().encode(history).write(to: dataDirectory.appendingPathComponent("history.json"), options: .atomic)
    }
    func chooseModel() {
        let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false
        panel.message = "Choose the YuE2 3B MLX-Serve 8-bit model folder"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard ModelLibrary.isComplete(url) else { error = "This folder does not contain a complete YuE2 model. Choose the MLX-Serve format with its VAE and tokenizer."; return }
        modelURL = url; UserDefaults.standard.set(url.path, forKey: "modelPath"); refreshModel()
    }
    func download() {
        guard !busy else { return }
        downloadProgress = ModelDownloadProgress(directory: ModelLibrary.defaultURL)
        error = nil; downloading = true; status = "Downloading YuE2 · about 4.5 GB"
        let id = UUID(); runID = id
        task = Task {
            defer { if runID == id { downloading = false } }
            do {
                try await engine.download()
                try Task.checkCancellation()
                modelURL = ModelLibrary.defaultURL; UserDefaults.standard.set(modelURL.path, forKey: "modelPath")
                refreshModel(); status = "YuE2 is ready. Start your radio."
            } catch is CancellationError { }
            catch { if runID == id { self.error = error.localizedDescription; status = "Download paused" } }
        }
    }
    func start() {
        guard !busy else { return }
        refreshModel(); guard modelAvailable else { error = "Download YuE2 first or choose an existing model folder."; return }
        guard settings.customPrompt.count <= 3000 else { error = "Shorten the description to 3,000 characters."; return }
        error = nil; running = true; paused = false; queued = nil; reserve = nil; longestGenerationSeconds = 0; generationProgress = nil
        salt = Int.random(in: 0...10_000); index = 0
        let id = UUID(); runID = id
        task = Task {
            do {
                status = "Loading YuE2 into memory"
                try await engine.prepare(model: modelURL)
                while !Task.isCancelled && runID == id {
                    while let next = queued {
                        if reserve == nil && PrefetchPolicy.needsReserve(nextDuration: next.durationSeconds ?? Double(settings.duration), longestGeneration: longestGenerationSeconds) { break }
                        try await Task.sleep(nanoseconds: 300_000_000)
                    }
                    try Task.checkCancellation()
                    let snapshot = settings
                    let output = tracksDirectory.appendingPathComponent("\(Date().formatted(.iso8601).replacingOccurrences(of: ":", with: "-"))-\(UUID().uuidString.prefix(6)).m4a")
                    let generationStarted = ProcessInfo.processInfo.systemUptime
                    var track = try await generateTrack(settings: snapshot, output: output, id: id)
                    try Task.checkCancellation()
                    guard runID == id else { return }
                    track.generationSeconds = ProcessInfo.processInfo.systemUptime - generationStarted
                    if let audio = try? AVAudioFile(forReading: output) {
                        track.durationSeconds = Double(audio.length) / audio.processingFormat.sampleRate
                    }
                    lastGenerationSeconds = track.generationSeconds
                    longestGenerationSeconds = max(longestGenerationSeconds, track.generationSeconds ?? 0)
                    usage.recordTrack(duration: track.durationSeconds ?? 0, generation: track.generationSeconds ?? 0)
                    sessionUsage.recordTrack(duration: track.durationSeconds ?? 0, generation: track.generationSeconds ?? 0)
                    saveUsage(); lastFolderScan = 0
                    index += 1; history.insert(track, at: 0); try saveHistory()
                    generationProgress = nil
                    if player == nil { try play(track) } else if queued == nil { queued = track } else { reserve = track }
                    status = queued == nil ? "Composing the next track" : "Next track ready"
                }
            } catch is CancellationError { }
            catch {
                if runID == id { self.error = error.localizedDescription; status = "Could not prepare the next track"; running = false; engine.stop() }
            }
        }
    }
    private func generateTrack(settings: RadioSettings, output: URL, id: UUID) async throws -> SavedTrack {
        generationAttempt = 1
        return try await GenerationRetry.perform(operation: {
            try await self.engine.generate(settings: settings, model: self.modelURL, index: self.index, salt: self.salt, output: output, attempt: self.generationAttempt) { stage, progress in
                guard self.runID == id else { return }
                self.status = stage + (self.generationAttempt > 1 ? " · attempt \(self.generationAttempt)/3" : "")
                self.generationProgress = progress
            }
        }, onRetry: { attempt in
            self.generationAttempt = attempt
            self.status = "Composing a fresh score · attempt \(attempt)/3"
            self.generationProgress = nil
        })
    }
    private func play(_ track: SavedTrack) throws {
        let audio = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: track.path))
        audio.delegate = self; audio.volume = settings.volume
        audio.prepareToPlay()
        guard audio.play() else { throw RadioFailure("Could not start playback. Check your audio output device.") }
        player = audio; current = track; elapsed = 0; total = audio.duration; paused = false
    }
    func togglePause() {
        guard let player else { return }
        if paused { player.play() } else { player.pause() }
        paused.toggle(); saveUsage()
    }
    func skip() {
        player?.stop(); player = nil; paused = false; elapsed = 0; total = 0
        if let next = queued {
            queued = reserve; reserve = nil
            do { try play(next) } catch { self.error = error.localizedDescription }
        } else { current = nil; if running { status = "Waiting for the next track" } }
    }
    func seek(_ seconds: TimeInterval) { player?.currentTime = min(max(0, seconds), total); elapsed = player?.currentTime ?? 0 }
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            guard self.player === player else { return }
            self.skip()
        }
    }
    func stop() {
        runID = UUID(); task?.cancel(); task = nil
        player?.stop(); player = nil; engine.stop()
        running = false; downloading = false; paused = false; current = nil; queued = nil; reserve = nil
        elapsed = 0; total = 0; generationProgress = nil; status = "Radio stopped · releasing memory"
        saveUsage(); sampleResources(); refreshModel()
    }
    func openTracks() { NSWorkspace.shared.open(tracksDirectory) }
    func openLog() { NSWorkspace.shared.open(engine.logURL) }
    func reveal(_ track: SavedTrack) { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: track.path)]) }
    deinit { timer?.invalidate() }
}
