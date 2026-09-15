import Foundation

enum WebURL {
    static func isAllowed(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = url.host, !host.isEmpty else { return false }
        return url.absoluteString.utf8.count <= 32_768
            && url.absoluteString.rangeOfCharacter(from: .controlCharacters) == nil
    }
}
