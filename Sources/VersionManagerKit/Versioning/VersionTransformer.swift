import Foundation
import ProcessRunning
import Subprocess

package enum HookEnvironmentKey: String {
    case value = "APPVERSION_VALUE"
    case old = "APPVERSION_OLD"
    case new = "APPVERSION_NEW"
    case configDir = "APPVERSION_CONFIG_DIR"
}

package enum VersionTransformerError: Error, LocalizedError, Equatable {
    case nonZeroExit(command: String, exitCode: Int32, stderr: String)
    case emptyOutput(command: String)
    case multiLineOutput(command: String, output: String)

    package var errorDescription: String? {
        switch self {
        case let .nonZeroExit(command, exitCode, stderr):
            "transform script \"\(command)\" exited with code \(exitCode): \(stderr)"
        case let .emptyOutput(command):
            "transform script \"\(command)\" produced empty output"
        case let .multiLineOutput(command, output):
            "transform script \"\(command)\" produced multi-line output: \(output)"
        }
    }
}

package struct VersionTransformer {
    private let processRunner: any ProcessRunning

    package init(processRunner: some ProcessRunning) {
        self.processRunner = processRunner
    }

    package func transform(
        _ rule: Config.RenameRule,
        value: String,
        old: String,
        new: String,
        configDir: String
    ) async throws -> String {
        guard let transform = rule.transform else {
            return value
        }

        let environment = Environment.inherit.updating([
            Environment.Key(stringLiteral: HookEnvironmentKey.value.rawValue): value,
            Environment.Key(stringLiteral: HookEnvironmentKey.old.rawValue): old,
            Environment.Key(stringLiteral: HookEnvironmentKey.new.rawValue): new,
            Environment.Key(stringLiteral: HookEnvironmentKey.configDir.rawValue): configDir,
        ])

        let result = try await processRunner.run(
            .name("/bin/sh"),
            arguments: ["-c", transform.run],
            environment: environment,
            output: .string(limit: 1 << 20),
            error: .string(limit: 1 << 20)
        )

        guard result.terminationStatus.isSuccess else {
            let exitCode: Int32 = if case let .exited(code) = result.terminationStatus {
                code
            } else {
                -1
            }
            throw VersionTransformerError.nonZeroExit(
                command: transform.run,
                exitCode: exitCode,
                stderr: result.standardError ?? ""
            )
        }

        let output = result.standardOutput ?? ""
        let lines = output.split(separator: "\n", omittingEmptySubsequences: false).filter { !$0.isEmpty }
        guard lines.count == 1 else {
            if lines.isEmpty {
                throw VersionTransformerError.emptyOutput(command: transform.run)
            }
            throw VersionTransformerError.multiLineOutput(command: transform.run, output: output)
        }

        return String(lines[0])
    }
}
