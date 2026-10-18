import Foundation

public enum Station: String, CaseIterable, Codable, Identifiable {
    case lofi, quiet, cyberpunk, synthwave, ambient, custom
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .lofi: return "Lo-Fi Lounge"
        case .quiet: return "Quiet Instrumental"
        case .cyberpunk: return "Cyberpunk City"
        case .synthwave: return "Synthwave Drive"
        case .ambient: return "Ambient Space"
        case .custom: return "Your Station"
        }
    }
    public var subtitle: String {
        switch self {
        case .lofi: return "Warm keys · mellow grooves"
        case .quiet: return "Calm · piano · unwind"
        case .cyberpunk: return "Neon · dark electronica"
        case .synthwave: return "Analog synths · retro waves"
        case .ambient: return "Airy textures · deep immersion"
        case .custom: return "Describe your own sound"
        }
    }
    public var symbol: String {
        switch self { case .lofi: return "cup.and.saucer.fill"; case .quiet: return "moon.stars.fill"; case .cyberpunk: return "building.2.fill"; case .synthwave: return "sun.haze.fill"; case .ambient: return "sparkles"; case .custom: return "slider.horizontal.3" }
    }
    public var style: String {
        switch self {
        case .lofi: return "Instrumental lo-fi chillhop, warm Rhodes piano, mellow bass, relaxed slow groove, cozy late-night atmosphere"
        case .quiet: return "Quiet instrumental music, gentle felt piano, soft strings, slow tempo, peaceful intimate arrangement, low energy"
        case .cyberpunk: return "Instrumental cyberpunk electronica, dark analog synths, deep electronic bass, futuristic neon city, cinematic atmosphere, steady mid-tempo pulse"
        case .synthwave: return "Instrumental synthwave, 1980s analog synthesizers, warm arpeggios, retro electronic bass, nostalgic night drive, steady mid-tempo groove"
        case .ambient: return "Instrumental ambient, slowly evolving soft synth pads, spacious soundscapes, delicate textures, calm meditative atmosphere"
        case .custom: return "Instrumental music"
        }
    }
    public var variations: [String] {
        switch self {
        case .lofi: return ["gentle electric piano motif", "soft jazz chords and muted guitar", "warm tape-textured keys", "delicate mellow mallet melody", "intimate Rhodes improvisation", "subtle acoustic guitar accents"]
        case .quiet: return ["delicate piano melody", "soft sustained cello", "gentle fingerpicked guitar", "warm felt piano harmonies", "sparse music-box accents"]
        case .cyberpunk: return ["pulsing sub bass and glassy synth lead", "industrial textures and minor-key arpeggios", "rainy neon atmosphere and restrained electronic groove", "dark cinematic pads and resonant bass", "glitch accents and distant analog melody"]
        case .synthwave: return ["dreamy analog lead", "warm polysynth chords", "sparkling arpeggiated sequence", "cinematic retro synth melody", "rounded bass and nostalgic pads"]
        case .ambient: return ["slow shimmering textures", "deep warm drones", "delicate bell-like tones", "soft evolving harmonic layers", "distant piano fragments"]
        case .custom: return ["a fresh melodic theme", "a new harmonic progression", "a different arrangement within the same style", "subtle variation in texture", "a fresh instrumental motif"]
        }
    }
}

public struct RadioSettings: Codable, Equatable {
    public var station: Station = .lofi
    public var customPrompt = ""
    public var vinyl = true
    public var softDrums = true
    public var beatless = false
    public var space = true
    public var darkMood = false
    public var duration = 180
    public var volume: Float = 0.7
    public init() {}
    public mutating func selectStation(_ station: Station) {
        self.station = station
        vinyl = station == .lofi
        softDrums = station == .lofi
        beatless = station == .quiet || station == .ambient
        space = true
        darkMood = station == .cyberpunk
    }
    public func prompt(index: Int, salt: Int, attempt: Int = 1) -> String {
        let variations = station.variations
        let offset = max(0, min(attempt, 3) - 1)
        let variation = variations[((index % variations.count) + (salt % variations.count) + variations.count + offset) % variations.count]
        var parts = [station.style, variation]
        if !customPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { parts.append(customPrompt) }
        if vinyl { parts.append("subtle vinyl crackle and warm tape saturation") }
        if beatless { parts.append("beatless texture, no drums") }
        else if softDrums { parts.append("soft restrained brushed drums") }
        if space { parts.append("spacious gentle reverb") }
        if darkMood { parts.append("darker minor-key mood") }
        if station == .ambient {
            parts.append("gradually changing harmonies, evolving melodic phrases, contrasting middle section, gentle resolved ending")
        }
        if attempt > 1 {
            parts.append(attempt == 2
                ? "concise arrangement, clear introduction, two contrasting themes, short outro"
                : "simple sparse arrangement, short melodic phrases with variation, clear ending")
        }
        return parts.joined(separator: ", ")
    }
    public func request(model: String, index: Int, salt: Int, seed: Int, attempt: Int = 1) -> [String: Any] {
        ["model": model, "prompt": prompt(index: index, salt: salt, attempt: attempt), "instrumental": true,
         "cot": "full", "duration_seconds": duration, "steps": 32, "seed": seed, "stream": true]
    }
}

public enum ModelLibrary {
    public static let repo = "ddalcu/YuE2-3B-MLX-Serve-8bit"
    public static let requiredFiles = ["config.json", "model.safetensors", "qwen.tiktoken", "vae.safetensors", "vae_config.json", "yue2_generation_config.json"]
    public static var libraryRoot: URL { FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Nightwave Radio/Models") }
    public static var defaultURL: URL { libraryRoot.appendingPathComponent(repo) }
    public static var legacyURL: URL { FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".mlx-serve/models/" + repo) }
    public static func preferredURL(saved: URL? = nil) -> URL {
        if let saved, isComplete(saved) { return saved }
        if isComplete(defaultURL) { return defaultURL }
        if isComplete(legacyURL) { return legacyURL }
        return defaultURL
    }
    public static func isComplete(_ url: URL) -> Bool {
        requiredFiles.allSatisfy { name in
            guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.appendingPathComponent(name).path),
                  let size = attributes[.size] as? NSNumber else { return false }
            return size.int64Value > 0
        }
    }
}
public enum TrackFiles {
    public static func sidecar(_ wav: URL, extension suffix: String) -> URL { wav.deletingPathExtension().appendingPathExtension(suffix) }
}
public struct SavedTrack: Codable, Identifiable {
    public var id: UUID
    public var title: String
    public var path: String
    public var date: Date
    public var prompt: String
    public var seed: Int
    public var durationSeconds: Double?
    public var generationSeconds: Double?
    public var generationSettings: RadioSettings?
    public init(title: String, path: String, prompt: String, seed: Int) {
        id = UUID(); self.title = title; self.path = path; date = Date(); self.prompt = prompt; self.seed = seed
    }
}
