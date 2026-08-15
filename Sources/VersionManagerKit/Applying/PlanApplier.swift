import FileManagerProtocol
import Foundation

package struct PlanApplier {
    private let fileManager: any FileManagerProtocol

    package init(fileManager: some FileManagerProtocol) {
        self.fileManager = fileManager
    }

    package func apply(_ plan: BumpPlan) throws {
        var applied: [FileReplacementPlan] = []

        for replacement in plan.replacements {
            do {
                try writeAtomically(replacement.newContent, to: replacement.path)
                applied.append(replacement)
            } catch {
                throw rollbackAndBuildError(
                    applied,
                    writeFailure: .writeFailed(path: replacement.path, underlying: String(describing: error))
                )
            }
        }

        for rename in plan.renames {
            do {
                try fileManager.moveItem(atPath: rename.oldPath, toPath: rename.newPath)
            } catch {
                throw rollbackAndBuildError(
                    applied,
                    writeFailure: .writeFailed(path: rename.newPath, underlying: String(describing: error))
                )
            }
        }
    }

    private func writeAtomically(_ content: String, to path: String) throws {
        let tempPath = path + ".tmp-\(UUID().uuidString)"
        guard fileManager.createFile(atPath: tempPath, contents: Data(content.utf8), attributes: nil) else {
            throw PlanApplierError.writeFailed(path: path, underlying: "createFile returned false")
        }
        if fileManager.fileExists(atPath: path) {
            try fileManager.removeItem(atPath: path)
        }
        try fileManager.moveItem(atPath: tempPath, toPath: path)
    }

    private func rollbackAndBuildError(
        _ applied: [FileReplacementPlan],
        writeFailure: PlanApplierError
    ) -> PlanApplierError {
        let unrecoveredPaths = rollback(applied)
        guard unrecoveredPaths.isEmpty else {
            return .rollbackFailed(unrecoveredPaths: unrecoveredPaths)
        }
        return writeFailure
    }

    private func rollback(_ applied: [FileReplacementPlan]) -> [String] {
        var unrecoveredPaths: [String] = []
        for replacement in applied.reversed() {
            do {
                try writeAtomically(replacement.originalContent, to: replacement.path)
            } catch {
                unrecoveredPaths.append(replacement.path)
            }
        }
        return unrecoveredPaths
    }
}

package enum PlanApplierError: Error, LocalizedError, Equatable {
    case writeFailed(path: String, underlying: String)
    case rollbackFailed(unrecoveredPaths: [String])

    package var errorDescription: String? {
        switch self {
        case let .writeFailed(path, underlying):
            "Failed to write \(path): \(underlying)"
        case let .rollbackFailed(unrecoveredPaths):
            "Rollback incomplete — manually restore with git checkout: \(unrecoveredPaths.joined(separator: ", "))"
        }
    }
}
