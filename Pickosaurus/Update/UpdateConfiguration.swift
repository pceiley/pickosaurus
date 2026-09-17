import Foundation

enum UpdateConfiguration {
    static var isConfigured: Bool {
        isValidFeedURL(Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String)
            && isValidPublicKey(Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String)
    }

    static func isValidFeedURL(_ value: String?) -> Bool {
        guard let value, let url = URL(string: value) else { return false }
        return url.scheme == "https" && url.host == "github.com"
            && url.user == nil && url.password == nil && url.port == nil
            && url.path.hasSuffix("/releases/latest/download/appcast.xml")
            && url.query == nil && url.fragment == nil
    }

    static func isValidPublicKey(_ value: String?) -> Bool {
        guard let value, let data = Data(base64Encoded: value) else { return false }
        return data.count == 32
    }
}
