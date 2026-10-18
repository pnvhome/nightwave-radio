import Foundation

public enum GenerationRetry {
    public static let maximumAttempts = 3
    public static func isScoreFailure(_ message: String) -> Bool {
        message.contains("Instrumental score repeats the same melodic phrase too often") || message.contains("Instrumental score validation failed") || message.contains("Instrumental score planning was truncated")
    }
    public static func shouldRetry(_ message: String, completedAttempts: Int) -> Bool {
        completedAttempts > 0 && completedAttempts < maximumAttempts && isScoreFailure(message)
    }
    public struct Exhausted: LocalizedError {
        public let lastFailure: String
        public var errorDescription: String? {
            "Could not create a valid instrumental score after 3 attempts. Try again or change the station description. Last failure: \(lastFailure)"
        }
    }
    @MainActor public static func perform<T>(operation: () async throws -> T, onRetry: (Int) -> Void = { _ in }) async throws -> T {
        for attempt in 1...maximumAttempts {
            try Task.checkCancellation()
            do { return try await operation() }
            catch {
                try Task.checkCancellation()
                if shouldRetry(error.localizedDescription, completedAttempts: attempt) {
                    onRetry(attempt + 1)
                    continue
                }
                if isScoreFailure(error.localizedDescription) { throw Exhausted(lastFailure: error.localizedDescription) }
                throw error
            }
        }
        throw Exhausted(lastFailure: "No valid score was returned.")
    }
}
