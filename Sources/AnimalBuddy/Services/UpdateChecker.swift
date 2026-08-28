import Foundation

public struct GitHubReleaseAsset: Codable, Sendable, Equatable {
    public let name: String
    public let browserDownloadURL: String
    public let size: Int

    private enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
        case size
    }

    public init(name: String, browserDownloadURL: String, size: Int = 0) {
        self.name = name
        self.browserDownloadURL = browserDownloadURL
        self.size = size
    }
}

public struct GitHubRelease: Codable, Sendable, Equatable {
    public let tagName: String
    public let name: String?
    public let body: String?
    public let htmlURL: String
    public let publishedAt: String?
    public let assets: [GitHubReleaseAsset]

    private enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlURL = "html_url"
        case publishedAt = "published_at"
        case assets
    }

    public init(tagName: String, name: String? = nil, body: String? = nil, htmlURL: String, publishedAt: String? = nil, assets: [GitHubReleaseAsset] = []) {
        self.tagName = tagName
        self.name = name
        self.body = body
        self.htmlURL = htmlURL
        self.publishedAt = publishedAt
        self.assets = assets
    }

    public var displayTitle: String {
        name ?? "Animal Buddy \(tagName)"
    }

    public var primaryDownloadURL: URL? {
        if let zipAsset = assets.first(where: { $0.name.hasSuffix(".zip") || $0.name.hasSuffix(".dmg") }),
           let url = URL(string: zipAsset.browserDownloadURL) {
            return url
        }
        return URL(string: htmlURL)
    }
}

public enum UpdateCheckResult: Sendable, Equatable {
    case updateAvailable(release: GitHubRelease, currentVersion: String)
    case upToDate(currentVersion: String)
    case skipped(version: String)
    case error(String)
}

public final class UpdateChecker: Sendable {
    public static let shared = UpdateChecker()

    public let repositoryOwner: String
    public let repositoryName: String

    public init(owner: String = "ewanp1997", repository: String = "AnimalBuddy") {
        self.repositoryOwner = owner
        self.repositoryName = repository
    }

    public var apiURL: URL {
        URL(string: "https://api.github.com/repos/\(repositoryOwner)/\(repositoryName)/releases/latest")!
    }

    public func checkForUpdates(currentVersion: String, skippedVersion: String? = nil, ignoreSkipped: Bool = false) async -> UpdateCheckResult {
        var request = URLRequest(url: apiURL)
        request.timeoutInterval = 15
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("AnimalBuddy/\(currentVersion) (macOS)", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return .error("Invalid network response.")
            }
            guard httpResponse.statusCode == 200 else {
                if httpResponse.statusCode == 404 {
                    return .error("No public releases found on GitHub.")
                }
                return .error("GitHub API returned status code \(httpResponse.statusCode).")
            }

            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            let remoteVersion = release.tagName

            if !ignoreSkipped, let skipped = skippedVersion, skipped == remoteVersion {
                return .skipped(version: remoteVersion)
            }

            if VersionComparator.isVersion(remoteVersion, greaterThan: currentVersion) {
                return .updateAvailable(release: release, currentVersion: currentVersion)
            } else {
                return .upToDate(currentVersion: currentVersion)
            }
        } catch {
            return .error(error.localizedDescription)
        }
    }
}
