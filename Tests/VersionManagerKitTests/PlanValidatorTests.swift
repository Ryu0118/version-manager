import Testing
@testable import VersionManagerKit

private func makeConfig(fileRules: [Config.FileRule]) -> Config {
    Config(
        version: "1.0.0",
        files: fileRules,
        renames: nil,
        hooks: nil
    )
}

private func makeSingleRuleConfig(id: String = "f", occurrences: Config.Occurrences = .all) -> Config {
    makeConfig(fileRules: [.init(id: id, path: "a.txt", pattern: "v(\\d+\\.\\d+\\.\\d+)", occurrences: occurrences)])
}

private func makeReplacement(ruleID: String, path: String, oldValue: String, newValue: String) -> FileReplacementPlan {
    FileReplacementPlan(
        ruleID: ruleID,
        path: path,
        matches: [MatchSlice(range: oldValue.startIndex ..< oldValue.endIndex, oldValue: oldValue)],
        originalContent: "v\(oldValue)",
        newContent: "v\(newValue)"
    )
}

@Test("valid plan passes")
func validPlanPasses() throws {
    let config = makeSingleRuleConfig()
    let plan = BumpPlan(replacements: [
        makeReplacement(ruleID: "f", path: "/p/a.txt", oldValue: "1.0.0", newValue: "1.1.0"),
    ])
    let validator = PlanValidator()
    try validator.validate(plan, config: config, newVersion: "1.1.0", force: false)
}

@Test("zero matches for a configured rule fails")
func zeroMatchesFails() {
    let config = makeConfig(fileRules: [
        .init(id: "missing-rule", path: "a.txt", pattern: "v(\\d+\\.\\d+\\.\\d+)", occurrences: .all),
    ])
    let plan = BumpPlan(replacements: [])
    let validator = PlanValidator()
    #expect(throws: (any Error).self) {
        try validator.validate(plan, config: config, newVersion: "1.1.0", force: false)
    }
}

@Test("occurrences count mismatch fails")
func occurrencesMismatchFails() {
    let config = makeConfig(fileRules: [
        .init(id: "f", path: "a.txt", pattern: "v(\\d+\\.\\d+\\.\\d+)", occurrences: .exactly(2)),
    ])
    let plan = BumpPlan(replacements: [
        makeReplacement(ruleID: "f", path: "/p/a.txt", oldValue: "1.0.0", newValue: "1.1.0"),
    ])
    let validator = PlanValidator()
    #expect(throws: (any Error).self) {
        try validator.validate(plan, config: config, newVersion: "1.1.0", force: false)
    }
}

@Test("inconsistent old versions across rules fails without force")
func inconsistentOldVersionsFailsWithoutForce() {
    let config = makeConfig(fileRules: [
        .init(id: "a", path: "a.txt", pattern: "v(\\d+\\.\\d+\\.\\d+)", occurrences: .all),
        .init(id: "b", path: "b.txt", pattern: "v(\\d+\\.\\d+\\.\\d+)", occurrences: .all),
    ])
    let plan = BumpPlan(replacements: [
        makeReplacement(ruleID: "a", path: "/p/a.txt", oldValue: "1.0.0", newValue: "1.1.0"),
        makeReplacement(ruleID: "b", path: "/p/b.txt", oldValue: "0.9.0", newValue: "1.1.0"),
    ])
    let validator = PlanValidator()
    #expect(throws: (any Error).self) {
        try validator.validate(plan, config: config, newVersion: "1.1.0", force: false)
    }
}

@Test("inconsistent old versions across rules passes with force")
func inconsistentOldVersionsPassesWithForce() throws {
    let config = makeConfig(fileRules: [
        .init(id: "a", path: "a.txt", pattern: "v(\\d+\\.\\d+\\.\\d+)", occurrences: .all),
        .init(id: "b", path: "b.txt", pattern: "v(\\d+\\.\\d+\\.\\d+)", occurrences: .all),
    ])
    let plan = BumpPlan(replacements: [
        makeReplacement(ruleID: "a", path: "/p/a.txt", oldValue: "1.0.0", newValue: "1.1.0"),
        makeReplacement(ruleID: "b", path: "/p/b.txt", oldValue: "0.9.0", newValue: "1.1.0"),
    ])
    let validator = PlanValidator()
    try validator.validate(plan, config: config, newVersion: "1.1.0", force: true)
}

@Test("old version equal to new version fails (no-op bump)")
func noOpBumpFails() {
    let config = makeSingleRuleConfig()
    let plan = BumpPlan(replacements: [
        makeReplacement(ruleID: "f", path: "/p/a.txt", oldValue: "1.1.0", newValue: "1.1.0"),
    ])
    let validator = PlanValidator()
    #expect(throws: (any Error).self) {
        try validator.validate(plan, config: config, newVersion: "1.1.0", force: false)
    }
}

@Test("rename target already existing fails")
func renameTargetExistsFails() {
    let config = makeSingleRuleConfig()
    var plan = BumpPlan(replacements: [
        makeReplacement(ruleID: "f", path: "/p/a.txt", oldValue: "1.0.0", newValue: "1.1.0"),
    ])
    plan.renames = [RenamePlan(ruleID: "r", oldPath: "/p/old.txt", newPath: "/p/EXISTS.txt")]
    let validator = PlanValidator()
    #expect(throws: (any Error).self) {
        try validator.validate(
            plan,
            config: config,
            newVersion: "1.1.0",
            force: false,
            existingPaths: ["/p/EXISTS.txt"]
        )
    }
}
