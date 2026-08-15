import Testing
@testable import VersionManagerKit

@Test("renders a replacement as a unified-diff-style change")
func rendersReplacement() {
    let plan = BumpPlan(replacements: [
        FileReplacementPlan(
            ruleID: "f", path: "/p/a.txt", matches: [], originalContent: "v1.0.0", newContent: "v1.1.0"
        ),
    ])
    let renderer = DiffRenderer(useColor: false)
    let output = renderer.render(plan)
    #expect(output.contains("/p/a.txt"))
    #expect(output.contains("-v1.0.0"))
    #expect(output.contains("+v1.1.0"))
}

@Test("renders a rename")
func rendersRename() {
    var plan = BumpPlan(replacements: [])
    plan.renames = [RenamePlan(ruleID: "r", oldPath: "/p/Configs/1-0-0.xcconfig", newPath: "/p/Configs/1-1-0.xcconfig")]
    let renderer = DiffRenderer(useColor: false)
    let output = renderer.render(plan)
    #expect(output.contains("rename: /p/Configs/1-0-0.xcconfig -> /p/Configs/1-1-0.xcconfig"))
}

@Test("renders hooks as would-run entries")
func rendersHooks() {
    var plan = BumpPlan(replacements: [])
    plan.postHooks = [Config.Hooks.Hook(name: "update-changelog", run: "./scripts/x.sh")]
    let renderer = DiffRenderer(useColor: false)
    let output = renderer.render(plan)
    #expect(output.contains("would run: update-changelog"))
}
