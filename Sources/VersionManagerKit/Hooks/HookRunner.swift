import Foundation
import ProcessRunning
import Subprocess

package enum HookRunnerError: Error, LocalizedError, Equatable {
    case hookFailed(name: String, exitCode: Int32, stderr: String)

    package var errorDescription: String? {
        switch self {
        case let .hookFailed(name, exitCode, stderr):
            "hook \"\(name)\" failed with exit code \(exitCode): \(stderr)"
        }
    }
}

package struct HookRunner {
    private let processRunner: any ProcessRunning

    package init(processRunner: some ProcessRunning) {
        self.processRunner = processRunner
    }

    package func run(_ hooks: [Config.Hooks.Hook], old: String, new: String, configDir: String) async throws {
        let environment = Environment.inherit.updating([
            Environment.Key(stringLiteral: HookEnvironmentKey.old.rawValue): old,
            Environment.Key(stringLiteral: HookEnvironmentKey.new.rawValue): new,
            Environment.Key(stringLiteral: HookEnvironmentKey.configDir.rawValue): configDir,
        ])

        for hook in hooks {
            let result = try await processRunner.run(
                .name("/bin/sh"),
                arguments: ["-c", hook.run],
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
                throw HookRunnerError.hookFailed(
                    name: hook.name,
                    exitCode: exitCode,
                    stderr: result.standardError ?? ""
                )
            }
        }
    }
}
