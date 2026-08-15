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
                try write(replacement.newContent, to: replacement.path)
                applied.append(replacement)
            } catch {
                rollback(applied)
                throw PlanApplierError.writeFailed(path: replacement.path, underlying: String(describing: error))
            }
        }

        for rename in plan.renames {
            do {
                try fileManager.moveItem(atPath: rename.oldPath, toPath: rename.newPath)
            } catch {
                rollback(applied)
                throw PlanApplierError.writeFailed(path: rename.newPath, underlying: String(describing: error))
            }
        }
    }

    private func write(_ content: String, to path: String) throws {
        guard fileManager.createFile(atPath: path, contents: Data(content.utf8), attributes: nil) else {
            throw PlanApplierError.writeFailed(path: path, underlying: "createFile returned false")
        }
    }

    private func rollback(_ applied: [FileReplacementPlan]) {
        for replacement in applied.reversed() {
            let originalData = Data(replacement.originalContent.utf8)
            _ = fileManager.createFile(atPath: replacement.path, contents: originalData, attributes: nil)
        }
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
