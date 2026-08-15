package struct MatchSlice: Sendable, Equatable {
    package let range: Range<String.Index>
    package let oldValue: String
}

package struct FileReplacementPlan: Sendable, Equatable {
    package let ruleID: String
    package let path: String
    package let matches: [MatchSlice]
    package let originalContent: String
    package let newContent: String
}

package struct RenamePlan: Sendable, Equatable {
    package let ruleID: String
    package let oldPath: String
    package let newPath: String
}

package struct BumpPlan: Sendable, Equatable {
    package var replacements: [FileReplacementPlan]
    package var renames: [RenamePlan] = []
    package var preHooks: [Config.Hooks.Hook] = []
    package var postHooks: [Config.Hooks.Hook] = []

    package init(
        replacements: [FileReplacementPlan],
        renames: [RenamePlan] = [],
        preHooks: [Config.Hooks.Hook] = [],
        postHooks: [Config.Hooks.Hook] = []
    ) {
        self.replacements = replacements
        self.renames = renames
        self.preHooks = preHooks
        self.postHooks = postHooks
    }
}
