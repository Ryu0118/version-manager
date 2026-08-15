import Foundation

package enum ConfigDecodingErrorFormatter {
    package static func message(for error: Error) -> String {
        guard let decodingError = error as? DecodingError else {
            return String(describing: error)
        }
        switch decodingError {
        case let .keyNotFound(key, context):
            return "Missing required key \"\(key.stringValue)\" at \(context.codingPath.map(\.stringValue).joined(separator: "."))"
        case let .typeMismatch(_, context):
            return "Type mismatch at \(context.codingPath.map(\.stringValue).joined(separator: ".")): \(context.debugDescription)"
        case let .valueNotFound(_, context):
            return "Missing value at \(context.codingPath.map(\.stringValue).joined(separator: ".")): \(context.debugDescription)"
        case let .dataCorrupted(context):
            return "Corrupted data at \(context.codingPath.map(\.stringValue).joined(separator: ".")): \(context.debugDescription)"
        @unknown default:
            return String(describing: decodingError)
        }
    }
}
