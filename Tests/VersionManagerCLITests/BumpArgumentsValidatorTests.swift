import Testing
@testable import VersionManagerCLI

@Test("accepts a non-empty version string")
func acceptsNonEmptyVersion() throws {
    let validator = BumpArgumentsValidator()
    try validator.validate(version: "1.18.0")
}

@Test("rejects an empty version string")
func rejectsEmptyVersion() {
    let validator = BumpArgumentsValidator()
    #expect(throws: (any Error).self) {
        try validator.validate(version: "")
    }
}
