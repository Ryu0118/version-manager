package struct BumpPlanJSON: Encodable, Sendable {
    package let replacements: [ReplacementJSON]
    package let renames: [RenameJSON]
    package let hooks: [String]

    package struct ReplacementJSON: Encodable, Sendable {
        package let ruleID: String
        package let path: String
        package let oldValues: [String]
        package let newContent: String
    }

    package struct RenameJSON: Encodable, Sendable {
        package let ruleID: String
        package let oldPath: String
        package let newPath: String
    }

    package init(_ plan: BumpPlan) {
        replacements = plan.replacements.map {
            ReplacementJSON(
                ruleID: $0.ruleID,
                path: $0.path,
                oldValues: $0.matches.map(\.oldValue),
                newContent: $0.newContent
            )
        }
        renames = plan.renames.map { RenameJSON(ruleID: $0.ruleID, oldPath: $0.oldPath, newPath: $0.newPath) }
        hooks = (plan.preHooks + plan.postHooks).map(\.name)
    }
}
