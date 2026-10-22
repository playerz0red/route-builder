import Foundation

public enum APIConfiguration {
    /// Info.plist key that holds the base URL (filled from `API_BASE_URL` in App.xcconfig).
    public static let infoPlistKey = "APIBaseURL"

    /// Returns a URL only for a string with an `http`/`https` scheme and a non-empty host.
    public static func baseURL(fromInfoValue value: Any?) -> URL? {
        guard let string = value as? String else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = url.host, !host.isEmpty
        else { return nil }
        return url
    }
}
