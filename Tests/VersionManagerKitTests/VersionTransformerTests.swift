import Testing
@testable import VersionManagerKit

@Test("runs the transform script and captures single-line stdout")
func runsTransformScript() async throws {
    let mock = MockProcessRunner()
    mock.stubbedOutput = "1-18-0\n"
    let rule = Config.RenameRule(
        id: "r",
        directory: "Configs",
        format: "{version}.xcconfig",
        transform: .init(run: "echo \"$APPVERSION_VALUE\" | tr '.' '-'")
    )
    let transformer = VersionTransformer(processRunner: mock)
    let result = try await transformer.transform(
        rule, value: "1.18.0", old: "1.17.2", new: "1.18.0", configDir: "/project"
    )
    #expect(result == "1-18-0")
}

@Test("passes through APPVERSION_VALUE unchanged when transform is nil")
func passesThroughWhenNoTransform() async throws {
    let mock = MockProcessRunner()
    let rule = Config.RenameRule(id: "r", directory: "Configs", format: "{version}.xcconfig", transform: nil)
    let transformer = VersionTransformer(processRunner: mock)
    let result = try await transformer.transform(
        rule, value: "1.18.0", old: "1.17.2", new: "1.18.0", configDir: "/project"
    )
    #expect(result == "1.18.0")
}

@Test("passes environment variables correctly")
func passesEnvironmentVariables() async throws {
    let mock = MockProcessRunner()
    mock.stubbedOutput = "ok\n"
    let rule = Config.RenameRule(
        id: "r", directory: "Configs", format: "{version}.xcconfig", transform: .init(run: "true")
    )
    let transformer = VersionTransformer(processRunner: mock)
    _ = try await transformer.transform(rule, value: "1.18.0", old: "1.17.2", new: "1.18.0", configDir: "/project")
    #expect(mock.capturedEnvironment?[HookEnvironmentKey.value.rawValue] == "1.18.0")
    #expect(mock.capturedEnvironment?[HookEnvironmentKey.old.rawValue] == "1.17.2")
    #expect(mock.capturedEnvironment?[HookEnvironmentKey.new.rawValue] == "1.18.0")
    #expect(mock.capturedEnvironment?[HookEnvironmentKey.configDir.rawValue] == "/project")
}

@Test("non-zero exit fails")
func nonZeroExitFails() async {
    let mock = MockProcessRunner()
    mock.stubbedExitCode = 1
    mock.stubbedOutput = ""
    let rule = Config.RenameRule(
        id: "r", directory: "Configs", format: "{version}.xcconfig", transform: .init(run: "exit 1")
    )
    let transformer = VersionTransformer(processRunner: mock)
    await #expect(throws: (any Error).self) {
        try await transformer.transform(rule, value: "1.18.0", old: "1.17.2", new: "1.18.0", configDir: "/project")
    }
}

@Test("empty stdout fails")
func emptyStdoutFails() async {
    let mock = MockProcessRunner()
    mock.stubbedOutput = ""
    let rule = Config.RenameRule(
        id: "r", directory: "Configs", format: "{version}.xcconfig", transform: .init(run: "true")
    )
    let transformer = VersionTransformer(processRunner: mock)
    await #expect(throws: (any Error).self) {
        try await transformer.transform(rule, value: "1.18.0", old: "1.17.2", new: "1.18.0", configDir: "/project")
    }
}

@Test("multi-line stdout fails")
func multiLineStdoutFails() async {
    let mock = MockProcessRunner()
    mock.stubbedOutput = "line1\nline2\n"
    let rule = Config.RenameRule(
        id: "r", directory: "Configs", format: "{version}.xcconfig", transform: .init(run: "true")
    )
    let transformer = VersionTransformer(processRunner: mock)
    await #expect(throws: (any Error).self) {
        try await transformer.transform(rule, value: "1.18.0", old: "1.17.2", new: "1.18.0", configDir: "/project")
    }
}
