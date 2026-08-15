extension ConfigValidator {
    func validateSourceOfTruth(_ sourceOfTruth: String?, files: [Config.FileRule]) -> [ConfigValidatorError] {
        guard let sourceOfTruth else { return [] }
        guard files.contains(where: { $0.id == sourceOfTruth }) else {
            return [.unknownSourceOfTruth(id: sourceOfTruth)]
        }
        return []
    }
}
