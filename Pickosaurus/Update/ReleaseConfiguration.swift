import Foundation

/// Empty in development. Distribution builds explicitly supply the fork's identity.
enum ReleaseConfiguration {
    static var repository: String? {
        let value = Bundle.main.object(forInfoDictionaryKey: "PickosaurusUpdateRepository") as? String ?? ""
        return isValidRepository(value) ? value : nil
    }

    static var teamIdentifier: String? {
        let value = Bundle.main.object(forInfoDictionaryKey: "PickosaurusUpdateTeamIdentifier") as? String ?? ""
        return isValidTeamIdentifier(value) ? value : nil
    }

    static var isConfigured: Bool { repository != nil && teamIdentifier != nil }

    static func isValidRepository(_ value: String) -> Bool {
        value.range(of: #"^[A-Za-z0-9][A-Za-z0-9-]*/[A-Za-z0-9][A-Za-z0-9._-]*\z"#, options: .regularExpression) != nil
    }

    static func isValidTeamIdentifier(_ value: String) -> Bool {
        value.range(of: #"^[A-Z0-9]{10}\z"#, options: .regularExpression) != nil
    }

    static func isReleaseAssetURL(_ url: URL, repository: String) -> Bool {
        isValidRepository(repository) && url.scheme == "https" && url.host == "github.com"
            && url.user == nil && url.password == nil && url.port == nil
            && url.path.hasPrefix("/\(repository)/releases/download/")
            && url.path.hasSuffix(".dmg") && url.query == nil && url.fragment == nil
    }
}
