import Foundation
import Security

/// Require the fork's explicitly configured Developer ID identity.
enum ReleaseIdentity {
    static let bundleIdentifier = "com.pickosaurus.app"

    static func isValid(at url: URL, teamIdentifier: String? = ReleaseConfiguration.teamIdentifier) -> Bool {
        guard let teamIdentifier, ReleaseConfiguration.isValidTeamIdentifier(teamIdentifier) else { return false }
        let designatedRequirement = "anchor apple generic and identifier \"\(bundleIdentifier)\" and (certificate leaf[field.1.2.840.113635.100.6.1.9] exists or certificate 1[field.1.2.840.113635.100.6.2.6] exists and certificate leaf[field.1.2.840.113635.100.6.1.13] exists and certificate leaf[subject.OU] = \(teamIdentifier))"
        guard Bundle(url: url)?.bundleIdentifier == bundleIdentifier else { return false }

        var staticCode: SecStaticCode?
        var expected: SecRequirement?
        guard SecStaticCodeCreateWithPath(url as CFURL, [], &staticCode) == errSecSuccess,
              let code = staticCode,
              SecRequirementCreateWithString(designatedRequirement as CFString, [], &expected) == errSecSuccess,
              let expected else { return false }

        let flags = SecCSFlags(rawValue: UInt32(kSecCSCheckAllArchitectures | kSecCSStrictValidate))
        guard SecStaticCodeCheckValidity(code, flags, expected) == errSecSuccess else { return false }

        var signingInfo: CFDictionary?
        guard SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &signingInfo) == errSecSuccess,
              let info = signingInfo as? [String: Any],
              info[kSecCodeInfoTeamIdentifier as String] as? String == teamIdentifier else { return false }

        // A valid Developer ID signature alone is insufficient: a custom,
        // build-specific DR would change the designated release identity.
        var actual: SecRequirement?
        var actualData: CFData?
        var expectedData: CFData?
        guard SecCodeCopyDesignatedRequirement(code, [], &actual) == errSecSuccess,
              let actual,
              SecRequirementCopyData(actual, [], &actualData) == errSecSuccess,
              SecRequirementCopyData(expected, [], &expectedData) == errSecSuccess,
              let actualData, let expectedData else { return false }
        return actualData == expectedData
    }
}
