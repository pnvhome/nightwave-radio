import Foundation

public struct ModelDownloadProgress {
    // File sizes of the supported YuE2 8-bit repository; count only model payloads.
    public static let sizes: [String: Int64] = ["config.json": 1042, "model.safetensors": 4264488042,
        "qwen.tiktoken": 2561218, "vae.safetensors": 265441814, "vae_config.json": 1378,
        "yue2_generation_config.json": 466]
    public let received: Int64
    public var total: Int64 { Self.sizes.values.reduce(0, +) }
    public var remaining: Int64 { max(0, total - received) }
    public var fraction: Double { Double(received) / Double(total) }
    public init(directory: URL) {
        received = Self.sizes.reduce(Int64(0)) { sum, file in
            let bytes = [file.key, file.key + ".partial"].map { name -> Int64 in
                let attrs = try? FileManager.default.attributesOfItem(atPath: directory.appendingPathComponent(name).path)
                return (attrs?[.size] as? NSNumber)?.int64Value ?? 0
            }.max() ?? 0
            return sum + min(file.value, max(0, bytes))
        }
    }
    public var detail: String {
        func format(_ bytes: Int64) -> String { ByteCountFormatter.string(fromByteCount: bytes, countStyle: .decimal) }
        return "Downloaded \(format(received)) of \(format(total)) · \(format(remaining)) remaining"
    }
}
