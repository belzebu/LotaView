import Foundation

/// Checks GitHub Releases API for newer versions of LotaView.
@MainActor
@Observable
final class UpdateChecker {
    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case available(version: String, url: URL)
        case error(String)
    }

    private(set) var state: State = .idle

    private static let repo = "belzebu/LotaView"
    private static let apiURL = "https://api.github.com/repos/\(repo)/releases/latest"

    private var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    func check() async {
        state = .checking

        guard let url = URL(string: Self.apiURL) else {
            state = .error("Invalid API URL")
            return
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                state = .error("Invalid response")
                return
            }

            guard httpResponse.statusCode == 200 else {
                if httpResponse.statusCode == 404 {
                    state = .upToDate // No releases yet
                } else {
                    state = .error("HTTP \(httpResponse.statusCode)")
                }
                return
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tagName = json["tag_name"] as? String,
                  let htmlURL = json["html_url"] as? String,
                  let releaseURL = URL(string: htmlURL) else {
                state = .error("Invalid response format")
                return
            }

            let latestVersion = tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))

            if isNewer(latestVersion, than: currentVersion) {
                state = .available(version: latestVersion, url: releaseURL)
            } else {
                state = .upToDate
            }
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    /// Semantic version comparison: returns true if `a` is newer than `b`.
    private func isNewer(_ a: String, than b: String) -> Bool {
        let aParts = a.split(separator: ".").compactMap { Int($0) }
        let bParts = b.split(separator: ".").compactMap { Int($0) }

        for i in 0..<max(aParts.count, bParts.count) {
            let av = i < aParts.count ? aParts[i] : 0
            let bv = i < bParts.count ? bParts[i] : 0
            if av > bv { return true }
            if av < bv { return false }
        }
        return false
    }
}
