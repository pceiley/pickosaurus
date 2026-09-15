import Foundation

@main
struct VerifyReleaseIdentity {
    static func main() {
        guard CommandLine.arguments.count == 2 else {
            fputs("Usage: verify-release-identity <Pickosaurus.app>\n", stderr)
            exit(2)
        }
        let url = URL(fileURLWithPath: CommandLine.arguments[1])
        guard ReleaseIdentity.isValid(at: url, teamIdentifier: ProcessInfo.processInfo.environment["APPLE_TEAM_ID"]) else {
            fputs("Release rejected: invalid Pickosaurus bundle, signature, or designated requirement. Set APPLE_TEAM_ID to your release team.\n", stderr)
            exit(1)
        }
        print("Verified Pickosaurus release signature and permission identity: \(url.path)")
    }
}
