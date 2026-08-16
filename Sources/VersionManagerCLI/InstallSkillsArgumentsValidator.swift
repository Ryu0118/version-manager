import Foundation

package enum InstallSkillsArgumentsValidatorError: Error, LocalizedError, Equatable {
    case dirCombinedWithGlobal

    package var errorDescription: String? {
        switch self {
        case .dirCombinedWithGlobal:
            "--dir cannot be combined with --global"
        }
    }
}

package struct InstallSkillsArgumentsValidator {
    package init() {}

    package func validate(dir: String, global: Bool) throws {
        guard !(global && dir != ".") else {
            throw InstallSkillsArgumentsValidatorError.dirCombinedWithGlobal
        }
    }
}
