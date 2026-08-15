import FileManagerProtocol
import Foundation
import Yams

package struct ConfigLoader {
    private let fileManager: any FileManagerProtocol

    package init(fileManager: some FileManagerProtocol) {
        self.fileManager = fileManager
    }

    package func load(from path: String) throws -> Config {
        guard fileManager.fileExists(atPath: path), let data = fileManager.contents(atPath: path) else {
            throw ConfigLoaderError.configNotFound(path: path)
        }
        let yamlString = String(bytes: data, encoding: .utf8) ?? ""
        do {
            return try YAMLDecoder().decode(Config.self, from: yamlString)
        } catch {
            throw ConfigLoaderError.decodingFailed(
                path: path,
                underlying: ConfigDecodingErrorFormatter.message(for: error)
            )
        }
    }
}

package enum ConfigLoaderError: Error, LocalizedError, Equatable {
    case configNotFound(path: String)
    case decodingFailed(path: String, underlying: String)

    package var errorDescription: String? {
        switch self {
        case let .configNotFound(path):
            "Config file not found: \(path)"
        case let .decodingFailed(path, underlying):
            "Failed to decode \(path): \(underlying)"
        }
    }
}
