import Rainbow

package struct DiffRenderer {
    private let useColor: Bool

    package init(useColor: Bool) {
        self.useColor = useColor
    }

    package func render(_ plan: BumpPlan) -> String {
        var lines: [String] = []

        for replacement in plan.replacements {
            lines.append(replacement.path)
            let oldLine = "-\(replacement.originalContent)"
            let newLine = "+\(replacement.newContent)"
            lines.append(useColor ? oldLine.red : oldLine)
            lines.append(useColor ? newLine.green : newLine)
        }

        for rename in plan.renames {
            lines.append("rename: \(rename.oldPath) -> \(rename.newPath)")
        }

        for hook in plan.preHooks + plan.postHooks {
            lines.append("would run: \(hook.name)")
        }

        return lines.joined(separator: "\n")
    }
}
