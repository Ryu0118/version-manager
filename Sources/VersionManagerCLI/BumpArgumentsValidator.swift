import Foundation

package enum BumpArgumentsValidatorError: Error, LocalizedError, Equatable {
    case invalidVersionArgument(String)

    package var errorDescription: String? {
        switch self {
        case let .invalidVersionArgument(value):
            "Invalid version argument: \"\(value)\""
        }
    }
}

package struct BumpArgumentsValidator {
    package init() {}

    package func validate(version: String) throws {
        guard !version.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw BumpArgumentsValidatorError.invalidVersionArgument(version)
        }
    }
}
