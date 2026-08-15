import FileManagerProtocol
import Foundation
import Testing
@testable import VersionManagerKit

@Test("loads a valid config file")
func loadsValidConfig() async throws {
    try await FileManager.default.runInTemporaryDirectory { directory in
        let yaml = """
        version: "1.0.0"
        files:
          - id: version-swift
            path: Sources/Version.swift
            pattern: 'static let current = "(\\d+\\.\\d+\\.\\d+)"'
        """
        let configPath = directory.appendingPathComponent(".appversion.yml").path
        try yaml.write(toFile: configPath, atomically: true, encoding: .utf8)

        let loader = ConfigLoader(fileManager: FileManager.default)
        let config = try loader.load(from: configPath)
        #expect(config.files.count == 1)
    }
}

@Test("missing config file throws configNotFound")
func missingConfigThrows() async throws {
    try await FileManager.default.runInTemporaryDirectory { directory in
        let configPath = directory.appendingPathComponent(".appversion.yml").path
        let loader = ConfigLoader(fileManager: FileManager.default)
        #expect(throws: ConfigLoaderError.configNotFound(path: configPath)) {
            try loader.load(from: configPath)
        }
    }
}

@Test("malformed YAML throws decodingFailed")
func malformedYAMLThrows() async throws {
    try await FileManager.default.runInTemporaryDirectory { directory in
        let configPath = directory.appendingPathComponent(".appversion.yml").path
        try "not: valid: : yaml: [".write(toFile: configPath, atomically: true, encoding: .utf8)

        let loader = ConfigLoader(fileManager: FileManager.default)
        #expect(throws: (any Error).self) {
            try loader.load(from: configPath)
        }
    }
}
