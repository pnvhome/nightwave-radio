import Foundation

public struct UsageTotals: Codable, Equatable {
    public var tracks = 0
    public var musicSeconds: Double = 0
    public var generationSeconds: Double = 0
    public var listeningSeconds: Double = 0
    public var timedMusicSeconds: Double = 0
    public init() {}
    public mutating func recordTrack(duration: Double, generation: Double) {
        tracks += 1
        musicSeconds += max(0, duration)
        generationSeconds += max(0, generation)
        if generation > 0 { timedMusicSeconds += max(0, duration) }
    }
    public var generationSpeed: Double? { generationSeconds > 0 ? timedMusicSeconds / generationSeconds : nil }
}

public struct ProcessCounters {
    public let pid: Int32
    public let residentBytes: UInt64
    public let cpuNanoseconds: UInt64
    public let uptime: Double
    public init(pid: Int32, residentBytes: UInt64, cpuNanoseconds: UInt64, uptime: Double) {
        self.pid = pid; self.residentBytes = residentBytes; self.cpuNanoseconds = cpuNanoseconds; self.uptime = uptime
    }
    /// 100% means one fully occupied CPU core, matching Activity Monitor.
    public func cpuPercent(since previous: ProcessCounters?) -> Double? {
        guard let previous, previous.pid == pid, uptime > previous.uptime, cpuNanoseconds >= previous.cpuNanoseconds else { return nil }
        return Double(cpuNanoseconds - previous.cpuNanoseconds) / 1_000_000_000 / (uptime - previous.uptime) * 100
    }
}
