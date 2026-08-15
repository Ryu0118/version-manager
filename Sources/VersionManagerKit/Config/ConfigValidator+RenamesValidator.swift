extension ConfigValidator {
    func validateRenames(_ renames: [Config.RenameRule]?) -> [ConfigValidatorError] {
        guard let renames else { return [] }
        var errors: [ConfigValidatorError] = []
        for rule in renames where !rule.format.contains(Regexes.versionPlaceholder) {
            errors.append(.missingVersionPlaceholder(ruleID: rule.id, format: rule.format))
        }
        return errors
    }
}
