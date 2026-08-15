import Testing
@testable import VersionManagerKit

@Test("valid single-capture-group pattern passes")
func validPatternPasses() throws {
    let config = Config(
        version: .init(format: .semver, pattern: nil, strict: nil),
        sourceOfTruth: nil,
        files: [.init(id: "f1", path: "a.txt", pattern: "v(\\d+)", occurrences: .all)],
        renames: nil,
        hooks: nil
    )
    let validator = ConfigValidator()
    try validator.validate(config) // should not throw
}

@Test("zero capture groups fails with context")
func zeroCaptureGroupsFails() {
    let config = Config(
        version: .init(format: .semver, pattern: nil, strict: nil),
        sourceOfTruth: nil,
        files: [.init(id: "bad-rule", path: "a.txt", pattern: "v\\d+", occurrences: .all)],
        renames: nil,
        hooks: nil
    )
    let validator = ConfigValidator()
    #expect(throws: (any Error).self) {
        try validator.validate(config)
    }
    do {
        try validator.validate(config)
        Issue.record("expected throw")
    } catch let failure as ConfigValidationFailure {
        #expect(failure.errors.contains(.captureGroupCountMismatch(ruleID: "bad-rule", found: 0)))
    } catch {
        Issue.record("wrong error type: \(error)")
    }
}

@Test("two capture groups fails")
func twoCaptureGroupsFails() {
    let config = Config(
        version: .init(format: .semver, pattern: nil, strict: nil),
        sourceOfTruth: nil,
        files: [.init(id: "bad-rule", path: "a.txt", pattern: "(v)(\\d+)", occurrences: .all)],
        renames: nil,
        hooks: nil
    )
    let validator = ConfigValidator()
    #expect(throws: (any Error).self) {
        try validator.validate(config)
    }
}

@Test("duplicate rule IDs fail")
func duplicateRuleIDsFail() {
    let config = Config(
        version: .init(format: .semver, pattern: nil, strict: nil),
        sourceOfTruth: nil,
        files: [
            .init(id: "dup", path: "a.txt", pattern: "v(\\d+)", occurrences: .all),
            .init(id: "dup", path: "b.txt", pattern: "v(\\d+)", occurrences: .all),
        ],
        renames: nil,
        hooks: nil
    )
    let validator = ConfigValidator()
    #expect(throws: (any Error).self) {
        try validator.validate(config)
    }
}

@Test("absolute path escapes project root")
func absolutePathFails() {
    let config = Config(
        version: .init(format: .semver, pattern: nil, strict: nil),
        sourceOfTruth: nil,
        files: [.init(id: "f1", path: "/etc/passwd", pattern: "v(\\d+)", occurrences: .all)],
        renames: nil,
        hooks: nil
    )
    let validator = ConfigValidator()
    #expect(throws: (any Error).self) {
        try validator.validate(config)
    }
}

@Test("parent-relative path escapes project root")
func parentRelativePathFails() {
    let config = Config(
        version: .init(format: .semver, pattern: nil, strict: nil),
        sourceOfTruth: nil,
        files: [.init(id: "f1", path: "../outside.txt", pattern: "v(\\d+)", occurrences: .all)],
        renames: nil,
        hooks: nil
    )
    let validator = ConfigValidator()
    #expect(throws: (any Error).self) {
        try validator.validate(config)
    }
}

@Test("invalid regex fails with underlying message")
func invalidRegexFails() {
    let config = Config(
        version: .init(format: .semver, pattern: nil, strict: nil),
        sourceOfTruth: nil,
        files: [.init(id: "f1", path: "a.txt", pattern: "(unclosed", occurrences: .all)],
        renames: nil,
        hooks: nil
    )
    let validator = ConfigValidator()
    #expect(throws: (any Error).self) {
        try validator.validate(config)
    }
}

@Test("rename format missing {version} placeholder fails")
func renameFormatMissingPlaceholderFails() {
    let config = Config(
        version: .init(format: .semver, pattern: nil, strict: nil),
        sourceOfTruth: nil,
        files: [.init(id: "f", path: "a.txt", pattern: "v(\\d+\\.\\d+\\.\\d+)", occurrences: .all)],
        renames: [.init(id: "r", directory: "Configs", format: "static.xcconfig", transform: nil)],
        hooks: nil
    )
    let validator = ConfigValidator()
    #expect(throws: (any Error).self) {
        try validator.validate(config)
    }
}

@Test("rename format with {version} placeholder passes")
func renameFormatWithPlaceholderPasses() throws {
    let config = Config(
        version: .init(format: .semver, pattern: nil, strict: nil),
        sourceOfTruth: nil,
        files: [.init(id: "f", path: "a.txt", pattern: "v(\\d+\\.\\d+\\.\\d+)", occurrences: .all)],
        renames: [.init(id: "r", directory: "Configs", format: "{version}.xcconfig", transform: nil)],
        hooks: nil
    )
    let validator = ConfigValidator()
    try validator.validate(config)
}
