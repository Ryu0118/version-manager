import Foundation

package enum JSONOutputError: Error, LocalizedError, Equatable {
    case encodingFailed

    package var errorDescription: String? {
        switch self {
        case .encodingFailed:
            "failed to encode JSON output as UTF-8"
        }
    }
}
