import Testing
@testable import VersionManagerKit

@Test("strict semver accepts a release version")
func strictAcceptsRelease() throws {
    let validator = VersionFormatValidator()
    try validator.validate("1.18.0", strict: true)
}

@Test("strict semver rejects a pre-release version")
func strictRejectsPreRelease() {
    let validator = VersionFormatValidator()
    #expect(throws: (any Error).self) {
        try validator.validate("1.18.0-beta.1", strict: true)
    }
}

@Test("non-strict semver accepts a pre-release version")
func nonStrictAcceptsPreRelease() throws {
    let validator = VersionFormatValidator()
    try validator.validate("1.18.0-beta.1", strict: false)
}

@Test("strict defaults to true when unspecified")
func strictDefaultsToTrue() {
    let validator = VersionFormatValidator()
    #expect(throws: (any Error).self) {
        try validator.validate("1.18.0-beta.1", strict: true)
    }
}

@Test("malformed semver string is rejected")
func malformedSemVerRejected() {
    let validator = VersionFormatValidator()
    #expect(throws: (any Error).self) {
        try validator.validate("1.18", strict: true)
    }
}
