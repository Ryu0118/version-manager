import Testing
@testable import VersionManagerKit

@Test("strict semver accepts a release version")
func strictAcceptsRelease() throws {
    let validator = VersionFormatValidator()
    let format = Config.VersionFormat(format: .semver, pattern: nil, strict: true)
    try validator.validate("1.18.0", against: format)
}

@Test("strict semver rejects a pre-release version")
func strictRejectsPreRelease() {
    let validator = VersionFormatValidator()
    let format = Config.VersionFormat(format: .semver, pattern: nil, strict: true)
    #expect(throws: (any Error).self) {
        try validator.validate("1.18.0-beta.1", against: format)
    }
}

@Test("non-strict semver accepts a pre-release version")
func nonStrictAcceptsPreRelease() throws {
    let validator = VersionFormatValidator()
    let format = Config.VersionFormat(format: .semver, pattern: nil, strict: false)
    try validator.validate("1.18.0-beta.1", against: format)
}

@Test("strict defaults to true when unspecified")
func strictDefaultsToTrue() {
    let validator = VersionFormatValidator()
    let format = Config.VersionFormat(format: .semver, pattern: nil, strict: nil)
    #expect(throws: (any Error).self) {
        try validator.validate("1.18.0-beta.1", against: format)
    }
}

@Test("malformed semver string is rejected")
func malformedSemVerRejected() {
    let validator = VersionFormatValidator()
    let format = Config.VersionFormat(format: .semver, pattern: nil, strict: true)
    #expect(throws: (any Error).self) {
        try validator.validate("1.18", against: format)
    }
}
