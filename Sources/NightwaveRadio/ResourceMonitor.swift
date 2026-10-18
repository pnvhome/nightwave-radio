import Foundation
import Darwin
import IOKit
import RadioCore

struct ResourceSnapshot {
    var engineRunning = false
    var engineBytes: UInt64?
    var applicationBytes: UInt64?
    var cpuPercent: Double?
    var gpuPercent: Double?
    var diskFreeBytes: UInt64?
    var tracksBytes: UInt64 = 0
}

/// Local OS counters only. No telemetry, subprocesses, or network requests.
final class ResourceMonitor {
    private var previousApp: ProcessCounters?
    private var previousEngine: ProcessCounters?
    func sample(enginePID: Int32?, tracksURL: URL) -> ResourceSnapshot {
        let app = Self.counters(pid: getpid())
        let engine = enginePID.flatMap(Self.counters)
        let appCPU = app?.cpuPercent(since: previousApp)
        let engineCPU = engine?.cpuPercent(since: previousEngine)
        previousApp = app; previousEngine = engine
        var value = ResourceSnapshot()
        value.engineRunning = enginePID != nil
        value.engineBytes = engine?.residentBytes
        value.applicationBytes = app?.residentBytes
        // An unavailable sample stays unknown instead of being shown as zero.
        if let appCPU, enginePID == nil || engineCPU != nil { value.cpuPercent = appCPU + (engineCPU ?? 0) }
        value.gpuPercent = Self.gpuPercent()
        if let attributes = try? FileManager.default.attributesOfFileSystem(forPath: tracksURL.path) {
            value.diskFreeBytes = (attributes[.systemFreeSize] as? NSNumber)?.uint64Value
        }
        return value
    }
    static func counters(pid: Int32) -> ProcessCounters? {
        var info = proc_taskinfo()
        let size = MemoryLayout<proc_taskinfo>.size
        guard proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info, Int32(size)) == size else { return nil }
        return ProcessCounters(pid: pid, residentBytes: info.pti_resident_size,
                               cpuNanoseconds: info.pti_total_user + info.pti_total_system,
                               uptime: ProcessInfo.processInfo.systemUptime)
    }
    private static func gpuPercent() -> Double? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AGXAccelerator"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        var properties: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let values = properties?.takeRetainedValue() as? [String: Any],
              let stats = values["PerformanceStatistics"] as? [String: Any],
              let number = stats["Device Utilization %"] as? NSNumber else { return nil }
        let value = number.doubleValue
        return (0...100).contains(value) ? value : nil
    }
    static func folderBytes(_ url: URL) -> UInt64 {
        guard let iterator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey], options: [.skipsHiddenFiles]) else { return 0 }
        var bytes: UInt64 = 0
        for case let file as URL in iterator {
            if let values = try? file.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]), values.isRegularFile == true {
                bytes += UInt64(max(0, values.fileSize ?? 0))
            }
        }
        return bytes
    }
}
