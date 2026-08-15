import Foundation
import Testing
@testable import VersionManagerKit

@Test("BumpPlan encodes to the documented JSON shape")
func bumpPlanEncodesToJSON() throws {
    var plan = BumpPlan(replacements: [
        FileReplacementPlan(
            ruleID: "f",
            path: "/p/a.txt",
            matches: [MatchSlice(range: "1.0.0".startIndex ..< "1.0.0".endIndex, oldValue: "1.0.0")],
            originalContent: "v1.0.0",
            newContent: "v1.1.0"
        ),
    ])
    plan.renames = [RenamePlan(ruleID: "r", oldPath: "/p/old.txt", newPath: "/p/new.txt")]
    plan.postHooks = [Config.Hooks.Hook(name: "notify", run: "true")]

    let json = BumpPlanJSON(plan)
    let data = try JSONEncoder().encode(json)
    let decoded = try JSONSerialization.jsonObject(with: data) as? [String: Any]

    #expect((decoded?["replacements"] as? [[String: Any]])?.count == 1)
    #expect((decoded?["renames"] as? [[String: Any]])?.count == 1)
    #expect((decoded?["hooks"] as? [String])?.first == "notify")
}
