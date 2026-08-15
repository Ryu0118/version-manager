import Testing
@testable import VersionManagerKit

@Test("runs each hook in order with correct environment")
func runsHooksInOrder() async throws {
    let mock = MockProcessRunner()
    mock.stubbedOutput = ""
    let hooks = [
        Config.Hooks.Hook(name: "first", run: "true"),
        Config.Hooks.Hook(name: "second", run: "true"),
    ]
    let runner = HookRunner(processRunner: mock)
    try await runner.run(hooks, old: "1.0.0", new: "1.1.0", configDir: "/project")
    #expect(mock.capturedCommands == ["true", "true"])
    #expect(mock.capturedEnvironments.count == 2)
    #expect(mock.capturedEnvironments[0][HookEnvironmentKey.old.rawValue] == "1.0.0")
    #expect(mock.capturedEnvironments[0][HookEnvironmentKey.new.rawValue] == "1.1.0")
    #expect(mock.capturedEnvironments[0][HookEnvironmentKey.configDir.rawValue] == "/project")
}

@Test("a failing hook stops execution and throws with the hook name")
func failingHookStops() async {
    let mock = MockProcessRunner()
    mock.stubbedExitCode = 1
    let hooks = [Config.Hooks.Hook(name: "bad-hook", run: "exit 1")]
    let runner = HookRunner(processRunner: mock)
    await #expect(throws: (any Error).self) {
        try await runner.run(hooks, old: "1.0.0", new: "1.1.0", configDir: "/project")
    }
}

@Test("a failing hook does not run subsequent hooks")
func failingHookStopsExecutionOfRemainingHooks() async {
    let mock = MockProcessRunner()
    mock.stubbedExitCode = 1
    let hooks = [
        Config.Hooks.Hook(name: "bad-hook", run: "exit 1"),
        Config.Hooks.Hook(name: "never-runs", run: "true"),
    ]
    let runner = HookRunner(processRunner: mock)
    _ = try? await runner.run(hooks, old: "1.0.0", new: "1.1.0", configDir: "/project")
    #expect(mock.capturedCommands == ["exit 1"])
}

@Test("empty hooks list runs nothing without error")
func emptyHooksListNoOp() async throws {
    let mock = MockProcessRunner()
    let runner = HookRunner(processRunner: mock)
    try await runner.run([], old: "1.0.0", new: "1.1.0", configDir: "/project")
    #expect(mock.capturedCommands.isEmpty)
}
