import Foundation
@testable import Pickosaurus

@main
struct BuildIsolationChecks {
    static func main() {
        precondition(BuildConfiguration.isDebugPreview, "Debug builds must not use release settings or enable release updates")
        precondition(BuildConfiguration.settingsDirectoryName == "Pickosaurus Debug")
        print("PASS: ordinary Debug builds isolate settings and disable release updates")
    }
}
