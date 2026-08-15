import Foundation
import ProcessRunning
import Subprocess

#if canImport(System)
    import System
#else
    import SystemPackage
#endif

final class MockProcessRunner: ProcessRunning, @unchecked Sendable {
    var stubbedOutput = ""
    var stubbedExitCode: Int32 = 0
    var stubbedStandardError = ""
    var capturedEnvironment: [String: String]?
    var capturedCommands: [String] = []
    var capturedEnvironments: [[String: String]] = []

    private struct MockCollectedResult<Output: OutputProtocol, Error: OutputProtocol>: CollectedResultProtocol {
        let processIdentifier = ProcessIdentifier(value: 0)
        let terminationStatus: TerminationStatus
        let standardOutput: Output.OutputType
        let standardError: Error.OutputType
    }

    func run<Output: OutputProtocol, Error: ErrorOutputProtocol>(
        _ executable: Executable,
        arguments: Arguments,
        environment: Environment,
        workingDirectory: FilePath?,
        platformOptions: PlatformOptions,
        input: some InputProtocol,
        output: Output,
        error: Error
    ) async throws -> any CollectedResultProtocol<Output, Error> {
        capturedEnvironment = environment.flattenedForTesting()
        capturedEnvironments.append(environment.flattenedForTesting())
        if let command = arguments.lastArgumentForTesting() {
            capturedCommands.append(command)
        }
        return try MockCollectedResult<Output, Error>(
            terminationStatus: .exited(stubbedExitCode),
            standardOutput: output.output(from: Array(stubbedOutput.utf8)),
            standardError: error.output(from: Array(stubbedStandardError.utf8))
        )
    }

    // swiftlint:disable:next function_parameter_count
    func run<Result, Error: ErrorOutputProtocol>(
        _ executable: Executable,
        arguments: Arguments,
        environment: Environment,
        workingDirectory: FilePath?,
        platformOptions: PlatformOptions,
        input: some InputProtocol,
        output: some OutputProtocol,
        error: Error,
        isolation: isolated (any Actor)?,
        body: (Execution) async throws -> Result
    ) async throws -> any ExecutionResultProtocol<Result> where Error.OutputType == Void {
        fatalError("not used by VersionTransformer tests")
    }

    // swiftlint:disable:next function_parameter_count
    func run<Result, Error: ErrorOutputProtocol>(
        _ executable: Executable,
        arguments: Arguments,
        environment: Environment,
        workingDirectory: FilePath?,
        platformOptions: PlatformOptions,
        input: some InputProtocol,
        error: Error,
        preferredBufferSize: Int?,
        isolation: isolated (any Actor)?,
        body: (Execution, AsyncBufferSequence) async throws -> Result
    ) async throws -> any ExecutionResultProtocol<Result> where Error.OutputType == Void {
        fatalError("not used by VersionTransformer tests")
    }

    // swiftlint:disable:next function_parameter_count
    func run<Result, Error: ErrorOutputProtocol>(
        _ executable: Executable,
        arguments: Arguments,
        environment: Environment,
        workingDirectory: FilePath?,
        platformOptions: PlatformOptions,
        error: Error,
        preferredBufferSize: Int?,
        isolation: isolated (any Actor)?,
        body: (Execution, StandardInputWriter, AsyncBufferSequence) async throws -> Result
    ) async throws -> any ExecutionResultProtocol<Result> where Error.OutputType == Void {
        fatalError("not used by VersionTransformer tests")
    }

    func run<Output: OutputProtocol, Error: ErrorOutputProtocol>(
        _ configuration: Configuration,
        input: some InputProtocol,
        output: Output,
        error: Error
    ) async throws -> any CollectedResultProtocol<Output, Error> {
        fatalError("not used by VersionTransformer tests")
    }

    func run<Result, Error: ErrorOutputProtocol>(
        _ configuration: Configuration,
        input: some InputProtocol,
        output: some OutputProtocol,
        error: Error,
        isolation: isolated (any Actor)?,
        body: (Execution) async throws -> Result
    ) async throws -> any ExecutionResultProtocol<Result> where Error.OutputType == Void {
        fatalError("not used by VersionTransformer tests")
    }
}

extension Environment {
    /// `Environment` exposes no public accessors for its stored key/value pairs, so this
    /// parses the one public surface available (`description`, which interpolates the
    /// underlying `[Key: String?]` dictionary) to recover the overrides for test assertions.
    func flattenedForTesting() -> [String: String] {
        var result: [String: String] = [:]
        for match in description.matches(of: /(\w+): (?:Optional\("([^"]*)"\)|"([^"]*)")/) {
            let key = String(match.output.1)
            let value = String(match.output.2 ?? match.output.3 ?? "")
            result[key] = value
        }
        return result
    }
}

extension Arguments {
    /// `Arguments` exposes no public accessors for its stored values, so this parses its
    /// `description` (a Swift-array-literal-style string, e.g. `["-c", "true"]`) and returns
    /// the last quoted element — the script passed to `/bin/sh -c`.
    func lastArgumentForTesting() -> String? {
        let matches = description.matches(of: /"([^"]*)"/)
        return matches.last.map { String($0.output.1) }
    }
}
