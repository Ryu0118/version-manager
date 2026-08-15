import Testing
@testable import VersionManagerKit
import Yams

@Test("occurrences decodes the string \"all\"")
func occurrencesDecodesAll() throws {
    let yaml = "occurrences: all"
    struct Wrapper: Decodable { let occurrences: Config.Occurrences }
    let wrapper = try YAMLDecoder().decode(Wrapper.self, from: yaml)
    #expect(wrapper.occurrences == .all)
}

@Test("occurrences decodes an integer")
func occurrencesDecodesInteger() throws {
    let yaml = "occurrences: 2"
    struct Wrapper: Decodable { let occurrences: Config.Occurrences }
    let wrapper = try YAMLDecoder().decode(Wrapper.self, from: yaml)
    #expect(wrapper.occurrences == .exactly(2))
}

@Test("minimal config decodes")
func minimalConfigDecodes() throws {
    let yaml = """
    version:
      format: semver
    files:
      - id: version-swift
        path: Sources/MyToolCLI/Version.swift
        pattern: 'static let current = "(\\d+\\.\\d+\\.\\d+)"'
    """
    let config = try YAMLDecoder().decode(Config.self, from: yaml)
    #expect(config.version.format == .semver)
    #expect(config.files.count == 1)
    #expect(config.files[0].id == "version-swift")
    #expect(config.files[0].occurrences == .all)
    #expect(config.renames == nil)
    #expect(config.hooks == nil)
}

@Test("full config decodes with renames and hooks")
func fullConfigDecodes() throws {
    let yaml = """
    version:
      format: semver
      strict: true
    source_of_truth: xcodeproj
    files:
      - id: xcodeproj
        path: "*.xcodeproj/project.pbxproj"
        pattern: 'MARKETING_VERSION = (\\d+\\.\\d+\\.\\d+);'
        occurrences: all
    renames:
      - id: version-xcconfig
        directory: Configs
        format: "{version}.xcconfig"
        transform:
          run: "echo \\"$APPVERSION_VALUE\\" | tr '.' '-'"
    hooks:
      pre:
        - name: ensure-clean-worktree
          run: "git diff --quiet"
      post:
        - name: update-changelog
          run: "./scripts/insert-changelog-entry.sh"
    """
    let config = try YAMLDecoder().decode(Config.self, from: yaml)
    #expect(config.sourceOfTruth == "xcodeproj")
    #expect(config.version.strict == true)
    #expect(config.renames?.count == 1)
    #expect(config.renames?[0].transform?.run.contains("tr") == true)
    #expect(config.hooks?.pre?.count == 1)
    #expect(config.hooks?.post?[0].name == "update-changelog")
}
