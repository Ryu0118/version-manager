import Testing
@testable import VersionManagerKit

@Test("parses a plain release version", arguments: [
    ("1.18.0", 1, 18, 0),
    ("0.0.1", 0, 0, 1),
    ("10.20.30", 10, 20, 30),
])
func parsesPlainVersion(input: String, major: Int, minor: Int, patch: Int) throws {
    let version = try SemanticVersion(parsing: input)
    #expect(version.major == major)
    #expect(version.minor == minor)
    #expect(version.patch == patch)
    #expect(version.preRelease.isEmpty)
    #expect(version.buildMetadata == nil)
}

@Test("parses pre-release identifiers")
func parsesPreRelease() throws {
    let version = try SemanticVersion(parsing: "1.18.0-beta.1")
    #expect(version.preRelease == [.alphanumeric("beta"), .numeric(1)])
}

@Test("parses build metadata")
func parsesBuildMetadata() throws {
    let version = try SemanticVersion(parsing: "1.18.0+build.5")
    #expect(version.buildMetadata == "build.5")
    #expect(version.preRelease.isEmpty)
}

@Test("parses pre-release plus build metadata")
func parsesPreReleaseAndBuild() throws {
    let version = try SemanticVersion(parsing: "1.18.0-beta.1+build.5")
    #expect(version.preRelease == [.alphanumeric("beta"), .numeric(1)])
    #expect(version.buildMetadata == "build.5")
}

@Test("parses mixed numeric and alphanumeric pre-release identifiers")
func parsesMixedPreRelease() throws {
    let version = try SemanticVersion(parsing: "1.0.0-x.7.z.92")
    #expect(version.preRelease == [.alphanumeric("x"), .numeric(7), .alphanumeric("z"), .numeric(92)])
}

@Test("rejects malformed input", arguments: [
    "1.18",
    "v1.18.0",
    "01.2.3",
    "",
    "1.0.0-",
])
func rejectsMalformedInput(input: String) {
    #expect(throws: (any Error).self) {
        try SemanticVersion(parsing: input)
    }
}

@Test("description round-trips")
func descriptionRoundTrips() throws {
    let version = try SemanticVersion(parsing: "1.18.0-beta.1+build.5")
    #expect(version.description == "1.18.0-beta.1+build.5")
}

@Test(
    "precedence follows SemVer 2.0.0 spec §11 official example chain",
    arguments: zip(
        [
            "1.0.0-alpha", "1.0.0-alpha.1", "1.0.0-alpha.beta", "1.0.0-beta",
            "1.0.0-beta.2", "1.0.0-beta.11", "1.0.0-rc.1",
        ],
        [
            "1.0.0-alpha.1", "1.0.0-alpha.beta", "1.0.0-beta", "1.0.0-beta.2",
            "1.0.0-beta.11", "1.0.0-rc.1", "1.0.0",
        ]
    )
)
func precedenceChain(lower: String, higher: String) throws {
    let lowerVersion = try SemanticVersion(parsing: lower)
    let higherVersion = try SemanticVersion(parsing: higher)
    #expect(lowerVersion < higherVersion)
}

@Test("build metadata does not affect precedence")
func buildMetadataIgnoredInComparison() throws {
    let first = try SemanticVersion(parsing: "1.0.0+a")
    let second = try SemanticVersion(parsing: "1.0.0+b")
    #expect(first == second)
    #expect(!(first < second))
    #expect(!(second < first))
}
