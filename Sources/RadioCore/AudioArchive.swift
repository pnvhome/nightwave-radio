import Foundation
import AVFoundation
import AudioToolbox

public enum AudioArchive {
    /// AAC 256 kbit/s in an M4A container, using the macOS audio encoder.
    /// Temporary files are private to this conversion; existing WAV archives
    /// and existing destinations are never replaced or removed.
    public static func saveM4A(wav: Data, to destination: URL) throws {
        let files = FileManager.default
        let source = files.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
        let encoded = destination.deletingLastPathComponent().appendingPathComponent("." + UUID().uuidString + ".m4a")
        defer { try? files.removeItem(at: source); try? files.removeItem(at: encoded) }
        try wav.write(to: source, options: .atomic)
        try encode(source: source, destination: encoded)
        let check = try AVAudioFile(forReading: encoded)
        guard check.length > 0 else { throw ArchiveError.emptyOutput }
        try Task.checkCancellation()
        try files.moveItem(at: encoded, to: destination)
    }
    private static func encode(source: URL, destination: URL) throws {
        let input = try AVAudioFile(forReading: source, commonFormat: .pcmFormatFloat32, interleaved: false)
        let format = input.processingFormat
        let settings: [String: Any] = [AVFormatIDKey: kAudioFormatMPEG4AAC,
                                      AVSampleRateKey: format.sampleRate,
                                      AVNumberOfChannelsKey: format.channelCount,
                                      AVEncoderBitRateKey: 256_000]
        let output = try AVAudioFile(forWriting: destination, settings: settings, commonFormat: .pcmFormatFloat32, interleaved: false)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 48_000) else { throw ArchiveError.buffer }
        while input.framePosition < input.length {
            try Task.checkCancellation()
            try input.read(into: buffer)
            guard buffer.frameLength > 0 else { break }
            try output.write(from: buffer)
        }
        // The writer is released here, finalizing the M4A before validation.
    }
    public enum ArchiveError: LocalizedError {
        case emptyOutput, buffer
        public var errorDescription: String? {
            switch self {
            case .emptyOutput: return "The macOS encoder returned an empty M4A file."
            case .buffer: return "Could not prepare the M4A recording buffer."
            }
        }
    }
}
