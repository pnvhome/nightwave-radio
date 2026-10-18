import Foundation
import Darwin
import RadioCore

struct RadioFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
    init(_ message: String) { self.message = message }
}

@MainActor
final class LocalEngine {
    private var server: Process?
    private var downloader: Process?
    private var logHandle: FileHandle?
    private(set) var port: Int = 0
    private var loadedModelID: String?
    var processID: Int32? {
        if let server, server.isRunning { return server.processIdentifier }
        if let downloader, downloader.isRunning { return downloader.processIdentifier }
        return nil
    }
    private let session: URLSession
    let libraryRoot: URL
    let logURL: URL
    init(dataDirectory: URL) {
        libraryRoot = ModelLibrary.libraryRoot
        logURL = dataDirectory.appendingPathComponent("engine.log")
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 1800
        config.timeoutIntervalForResource = 3600
        session = URLSession(configuration: config)
    }
    private func process(_ arguments: [String]) throws -> Process {
        guard let resources = Bundle.main.resourceURL, let frameworks = Bundle.main.privateFrameworksURL else { throw RadioFailure("Application components are missing. Reinstall Nightwave Radio.") }
        let binary = Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/mlx-serve")
        guard FileManager.default.isExecutableFile(atPath: binary.path) else { throw RadioFailure("The music engine is missing from the app.") }
        let p = Process(); p.executableURL = binary; p.arguments = arguments
        var env = ProcessInfo.processInfo.environment
        // Always the shipped adapter; never inherit a different user's override.
        env["YUE2_INSTRUMENTAL_LORA"] = resources.appendingPathComponent("ar_lora_inst_v3abc.bf16.safetensors").path
        env["YUE2_INSTRUMENTAL_PYTHON"] = resources.appendingPathComponent("instrumental-python").path
        env["MLX_SERVE_MODELS_DIR"] = libraryRoot.path
        env["DYLD_LIBRARY_PATH"] = frameworks.path
        env["MLX_METAL_PATH"] = frameworks.path
        p.environment = env
        if !FileManager.default.fileExists(atPath: logURL.path) { FileManager.default.createFile(atPath: logURL.path, contents: nil) }
        let handle = try FileHandle(forWritingTo: logURL); try handle.seekToEnd()
        logHandle = handle
        p.standardOutput = handle; p.standardError = handle
        return p
    }
    func download() async throws {
        let p = try process(["pull", ModelLibrary.repo]); downloader = p
        defer { if downloader === p { downloader = nil } }
        try p.run()
        do {
            while p.isRunning { try Task.checkCancellation(); try await Task.sleep(nanoseconds: 500_000_000) }
        } catch { if p.isRunning { p.terminate() }; throw error }
        guard p.terminationStatus == 0, ModelLibrary.isComplete(ModelLibrary.defaultURL) else {
            throw RadioFailure("Download incomplete. Check your connection and free disk space (about 5 GB required), then retry. Downloaded files are retained.")
        }
    }
    private func availablePort() throws -> Int {
        let fd = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { throw RadioFailure("Could not open a local port.") }
        defer { Darwin.close(fd) }
        var address = sockaddr_in(); address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size); address.sin_family = sa_family_t(AF_INET)
        address.sin_addr.s_addr = inet_addr("127.0.0.1"); address.sin_port = 0
        let bound = withUnsafePointer(to: &address) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) } }
        guard bound == 0 else { throw RadioFailure("Could not select a local port.") }
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let got = withUnsafeMutablePointer(to: &address) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(fd, $0, &length) } }
        guard got == 0 else { throw RadioFailure("Could not determine the local port.") }
        return Int(UInt16(bigEndian: address.sin_port))
    }
    func prepare(model: URL) async throws {
        guard ModelLibrary.isComplete(model) else { throw RadioFailure("YuE2 is missing or incomplete. Click Download model.") }
        if server?.isRunning != true {
            port = try availablePort()
            let p = try process(["--serve", "--host", "127.0.0.1", "--port", String(port), "--model-dir", libraryRoot.path])
            server = p
            try p.run()
            var ready = false
            for _ in 0..<100 {
                try Task.checkCancellation()
                guard p.isRunning else { throw RadioFailure("The music engine did not start. Open the log for details.") }
                if let (_, response) = try? await session.data(from: endpoint("/health")), (response as? HTTPURLResponse)?.statusCode == 200 { ready = true; break }
                try await Task.sleep(nanoseconds: 150_000_000)
            }
            guard ready else { throw RadioFailure("The engine did not respond. Try stopping and restarting the radio.") }
        }
        let loaded = try await json("/v1/load-model", body: ["model": model.path])
        let loadObject = try JSONSerialization.jsonObject(with: loaded) as? [String: Any]
        guard let identity = (loadObject?["model"] as? [String: Any])?["id"] as? String else {
            throw RadioFailure("The engine did not return the loaded model name.")
        }
        loadedModelID = identity
        let data = try await json("/v1/models")
        guard let result = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = result["data"] as? [[String: Any]],
              models.contains(where: { ($0["id"] as? String) == identity && ($0["state"] as? String) == "ready" }) else {
            throw RadioFailure("Could not load YuE2 into memory. Check available memory and the log.")
        }
    }
    private func endpoint(_ path: String) -> URL { URL(string: "http://127.0.0.1:\(port)\(path)")! }
    private func json(_ path: String, body: [String: Any]? = nil) async throws -> Data {
        var request = URLRequest(url: endpoint(path))
        if let body { request.httpMethod = "POST"; request.setValue("application/json", forHTTPHeaderField: "Content-Type"); request.httpBody = try JSONSerialization.data(withJSONObject: body) }
        let (data, response) = try await session.data(for: request)
        try Self.check(response: response, data: data)
        return data
    }
    private static func check(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            let detail = (object?["error"] as? [String: Any])?["message"] as? String ?? "The local engine reported an error. Check the log."
            throw RadioFailure(detail)
        }
    }
    func generate(settings: RadioSettings, model: URL, index: Int, salt: Int, output: URL, attempt: Int = 1,
                  progress: @escaping (String, Double?) -> Void) async throws -> SavedTrack {
        guard let loadedModelID else { throw RadioFailure("Load the music model first.") }
        let seed = Int.random(in: 1...Int(Int32.max))
        let body = settings.request(model: loadedModelID, index: index, salt: salt, seed: seed, attempt: attempt)
        var request = URLRequest(url: endpoint("/v1/audio/music-generations"))
        request.httpMethod = "POST"; request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (bytes, response) = try await session.bytes(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            var data = Data(); for try await byte in bytes { data.append(byte); if data.count > 100_000 { break } }
            try Self.check(response: response, data: data)
            throw RadioFailure("Could not create the track.")
        }
        for try await line in bytes.lines {
            try Task.checkCancellation()
            guard line.hasPrefix("data: "), let raw = line.dropFirst(6).data(using: .utf8) else { continue }
            let event = try await Task.detached(priority: .userInitiated) { try JSONSerialization.jsonObject(with: raw) as? [String: Any] ?? [:] }.value
            switch event["type"] as? String {
            case "error": throw RadioFailure(event["message"] as? String ?? "Music generation failed.")
            case "progress":
                let stage = event["stage"] as? String ?? ""
                let names = ["abc": "Composing the score", "semantic": "Creating the musical structure", "nar": "Synthesizing sound", "decode": "Preparing audio"]
                let total = (event["total"] as? NSNumber)?.doubleValue ?? 0
                let step = (event["step"] as? NSNumber)?.doubleValue ?? 0
                progress(names[stage] ?? "Creating music", total > 0 ? min(1, step / total) : nil)
            case "complete":
                if settings.station == .ambient, let score = event["abc"] as? String,
                   ScoreQuality.hasDominantMelodicLoop(score) { throw ScoreQuality.Repetitive() }
                guard let base64 = event["data"] as? String else { throw RadioFailure("The engine returned an empty track.") }
                let saved = try await Task.detached(priority: .userInitiated) {
                    guard let wav = Data(base64Encoded: base64), wav.count > 44 else { throw RadioFailure("The audio file is damaged.") }
                    try AudioArchive.saveM4A(wav: wav, to: output)
                    for key in ["abc", "original_abc"] {
                        if let value = event[key] as? String {
                            try value.write(to: TrackFiles.sidecar(output, extension: key == "abc" ? "abc" : "original.abc"), atomically: true, encoding: .utf8)
                        }
                    }
                    if let report = event["instrumental_transfer"] {
                        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: TrackFiles.sidecar(output, extension: "transfer.json"), options: .atomic)
                    }
                    try JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted, .sortedKeys]).write(to: TrackFiles.sidecar(output, extension: "request.json"), options: .atomic)
                    return SavedTrack(title: settings.station.title + " · " + String(index + 1), path: output.path, prompt: settings.prompt(index: index, salt: salt, attempt: attempt), seed: seed)
                }.value
                return saved
            default: break
            }
        }
        throw RadioFailure("The connection closed before the track arrived.")
    }
    func stop() {
        if let downloader, downloader.isRunning { downloader.terminate() }
        if let server, server.isRunning { server.terminate() }
        downloader = nil; server = nil; loadedModelID = nil
        try? logHandle?.close(); logHandle = nil
    }
    deinit { if let server, server.isRunning { server.terminate() }; if let downloader, downloader.isRunning { downloader.terminate() } }
}
