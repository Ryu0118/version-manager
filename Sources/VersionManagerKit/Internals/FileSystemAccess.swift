import FileManagerProtocol
import Foundation
import Glob

package struct FileSystemAccess {
    private let fileManager: any FileManagerProtocol

    package init(fileManager: some FileManagerProtocol) {
        self.fileManager = fileManager
    }

    package func expandGlob(pattern: String, relativeTo root: String) async throws -> [String] {
        let encodedRoot = root.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? root
        guard let rootURL = URL(string: encodedRoot) else {
            return []
        }

        var matches: [String] = []
        for try await url in try Glob.search(
            directory: rootURL,
            include: [Pattern(pattern)],
            skipHiddenFiles: false
        ) {
            let path = url.absoluteString.removingPercentEncoding ?? url.absoluteString
            matches.append(path)
        }
        return matches.sorted()
    }
}
