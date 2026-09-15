import Foundation

/// Downloads a file with `URLSession`, reporting fractional progress.
///
/// The download runs on a dedicated session whose delegate forwards byte
/// progress; the returned URL points at a stable temp file the caller owns.
final class UpdateDownloader: NSObject {
    private var lastProgressPercent = -1
    static let maximumBytes: Int64 = 512 * 1024 * 1024
    private var progressHandler: ((Double) -> Void)?
    private var continuation: CheckedContinuation<URL, Error>?
    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 600
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }()

    /// Downloads `url`, invoking `onProgress` (0...1) on the main actor, and
    /// returns a temp file URL that persists until the caller removes it.
    func download(_ url: URL, onProgress: @escaping (Double) -> Void) async throws -> URL {
        guard let repository = ReleaseConfiguration.repository,
              ReleaseConfiguration.isReleaseAssetURL(url, repository: repository) else {
            throw GitHubReleaseError.invalidResponse
        }
        progressHandler = onProgress
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            session.downloadTask(with: url).resume()
        }
    }
}

extension UpdateDownloader: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        guard totalBytesWritten <= Self.maximumBytes,
              totalBytesExpectedToWrite <= Self.maximumBytes else {
            downloadTask.cancel()
            return
        }
        guard totalBytesExpectedToWrite > 0 else { return }
        let fraction = min(1, max(0, Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)))
        let percent = Int(fraction * 100)
        guard percent > lastProgressPercent else { return }
        lastProgressPercent = percent
        let handler = progressHandler
        Task { @MainActor in handler?(fraction) }
    }

    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        guard let response = downloadTask.response as? HTTPURLResponse,
              (200..<300).contains(response.statusCode), response.url?.scheme == "https" else {
            continuation?.resume(throwing: GitHubReleaseError.invalidResponse)
            continuation = nil
            return
        }
        // The system removes `location` once this delegate returns, so move it
        // to a stable temp file synchronously here.
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("Pickosaurus-update-\(UUID().uuidString).dmg")
        do {
            // Enforce the limit on the completed file as well as progress callbacks.
            let attributes = try FileManager.default.attributesOfItem(atPath: location.path)
            guard let size = attributes[.size] as? NSNumber, size.int64Value <= Self.maximumBytes else {
                throw GitHubReleaseError.invalidResponse
            }
            try FileManager.default.moveItem(at: location, to: destination)
            continuation?.resume(returning: destination)
        } catch {
            continuation?.resume(throwing: error)
        }
        continuation = nil
    }

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didCompleteWithError error: Error?) {
        defer {
            progressHandler = nil
            session.finishTasksAndInvalidate()
        }
        if let error {
            continuation?.resume(throwing: error)
            continuation = nil
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        let host = request.url?.host ?? ""
        let allowed = request.url?.scheme == "https"
            && (host == "github.com" || host == "release-assets.githubusercontent.com" || host == "objects.githubusercontent.com")
        completionHandler(allowed ? request : nil)
    }
}
