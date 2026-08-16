package struct SkillInstallResultJSON: Encodable, Sendable {
    package let installed: [InstalledJSON]
    package let skipped: [SkippedJSON]

    package struct InstalledJSON: Encodable, Sendable {
        package let name: String
        package let paths: [String]
    }

    package struct SkippedJSON: Encodable, Sendable {
        package let name: String
        package let reason: String
    }

    package init(_ result: SkillInstallResult) {
        installed = result.installed.map { InstalledJSON(name: $0.name, paths: $0.paths) }
        skipped = result.skipped.map { SkippedJSON(name: $0.name, reason: $0.reason) }
    }
}
