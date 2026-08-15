import FileManagerProtocol
import Foundation

package struct CurrentRunner {
    private let fileManager: any FileManagerProtocol

    package init(fileManager: some FileManagerProtocol) {
        self.fileManager = fileManager
    }

    package func run(configPath: String, projectRoot: String) async throws -> String {
        let config = try ConfigLoader(fileManager: fileManager).load(from: configPath)
        try ConfigValidator().validate(config)
        return config.version
    }
}
