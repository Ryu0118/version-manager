package struct SkillInstallResultRenderer {
    package init() {}

    package func render(_ result: SkillInstallResult) -> String {
        var lines: [String] = []

        for skill in result.installed {
            for path in skill.paths {
                lines.append("installed: \(skill.name) -> \(path)")
            }
        }
        for skip in result.skipped {
            lines.append("skipped: \(skip.name) (\(skip.reason))")
        }

        return lines.joined(separator: "\n")
    }
}
