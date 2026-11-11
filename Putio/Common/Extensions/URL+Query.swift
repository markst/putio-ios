import Foundation

extension URL {
    /// The value of the first query parameter named `name`, percent-decoded.
    func queryValue(_ name: String) -> String? {
        URLComponents(url: self, resolvingAgainstBaseURL: false)?.queryValue(name)
    }

    /// The value of the first parameter named `name` in a form-encoded fragment,
    /// as OAuth implicit-flow callbacks return (`#access_token=…&state=…`).
    func fragmentValue(_ name: String) -> String? {
        var components = URLComponents()
        components.query = fragment
        return components.queryValue(name)
    }

    /// This URL with `items` added after any existing query items.
    func appendingQueryItems(_ items: [URLQueryItem]) -> URL? {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else { return nil }
        components.queryItems = (components.queryItems ?? []) + items
        return components.url
    }
}

extension URLComponents {
    func queryValue(_ name: String) -> String? {
        queryItems?.first(where: { $0.name == name })?.value
    }
}
