import Foundation

/// A single downloadable file attached to a GitHub release.
struct ReleaseAsset: Decodable {
    let name: String
    let browserDownloadURL: URL

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
    }
}

/// The subset of a GitHub release we care about.
struct GitHubRelease: Decodable {
    let tagName: String
    let name: String?
    let body: String?
    let assets: [ReleaseAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case assets
    }

    /// Human-facing release notes (markdown), falling back to an empty string.
    var releaseNotes: String { body ?? "" }

    /// The displayable version string (without a leading `v`).
    var displayVersion: String {
        SemanticVersion(tagName).map(\.description) ?? tagName
    }
}

enum GitHubReleaseError: LocalizedError {
    case notConfigured
    case invalidResponse
    case noDMGAsset

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Updates are not configured for this Pickosaurus build."
        case .invalidResponse:
            return "Could not read the latest release information."
        case .noDMGAsset:
            return "The latest release does not include a downloadable installer."
        }
    }
}

/// Fetches release metadata from the GitHub REST API. Networking + decoding only.
struct GitHubReleaseService {
    static var repository: String? { ReleaseConfiguration.repository }

    private let session: URLSession

    init(session: URLSession = URLSession(configuration: .ephemeral)) {
        self.session = session
    }

    func latestRelease() async throws -> GitHubRelease {
        guard ReleaseConfiguration.isConfigured, let repository = Self.repository,
              let url = URL(string: "https://api.github.com/repos/\(repository)/releases/latest") else {
            throw GitHubReleaseError.notConfigured
        }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Pickosaurus", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw GitHubReleaseError.invalidResponse
        }

        return try JSONDecoder().decode(GitHubRelease.self, from: data)
    }

    /// The first `.dmg` asset in a release, if any.
    func dmgAsset(in release: GitHubRelease) -> ReleaseAsset? {
        guard let repository = Self.repository else { return nil }
        return release.assets.first {
            $0.name.hasPrefix("Pickosaurus-") && $0.name.hasSuffix(".dmg")
                && ReleaseConfiguration.isReleaseAssetURL($0.browserDownloadURL, repository: repository)
        }
    }
}
