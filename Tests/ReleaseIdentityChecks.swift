import Foundation
import Security
@testable import Pickosaurus

@main
struct ReleaseIdentityChecks {
    static func main() {
        for team in ["286A3PVLVL", "ABC1234567", "1234567890"] {
            let source = ReleaseIdentity.requirementString(teamIdentifier: team)!
            var requirement: SecRequirement?
            precondition(SecRequirementCreateWithString(source as CFString, [], &requirement) == errSecSuccess,
                         "Release requirement must parse for Team ID \(team)")
            precondition(requirement != nil)
        }
        for team in ["", "YOUR_TEAM_ID", "BAD\" OR true", "TEAM123456\n"] {
            precondition(ReleaseIdentity.requirementString(teamIdentifier: team) == nil)
        }
        print("PASS: release requirements accept numeric-leading Team IDs and reject invalid values")
    }
}
