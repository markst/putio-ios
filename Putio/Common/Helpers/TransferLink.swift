import Foundation

/// A link put.io can start a transfer from: http, https, or a magnet with a
/// BitTorrent info hash. Compiled into the app and the share extension, so it
/// imports only Foundation.
struct TransferLink: Equatable {
    enum Incoming: Equatable {
        case link(TransferLink)
        case unsupported
    }

    private static let maximumDisplayLength = 200

    let url: URL

    var isMagnet: Bool {
        url.scheme?.lowercased() == "magnet"
    }

    /// A magnet's `dn` name, when it has one.
    var displayName: String? {
        guard isMagnet,
              let name = url.queryValue("dn"),
              !name.isEmpty
        else { return nil }
        return name
    }

    var truncatedURL: String {
        let text = url.absoluteString
        guard text.count > Self.maximumDisplayLength else { return text }
        return String(text.prefix(Self.maximumDisplayLength)) + "…"
    }

    /// The link that opens this app on the confirm prompt.
    var appURL: URL {
        var components = URLComponents()
        components.scheme = "putio"
        components.host = "transfers"
        components.path = "/add"
        components.queryItems = [URLQueryItem(name: "url", value: url.absoluteString)]
        return components.url ?? url
    }

    /// The first valid link among the whitespace-separated words of `text`.
    static func parse(_ text: String) -> TransferLink? {
        for word in text.components(separatedBy: .whitespacesAndNewlines) where !word.isEmpty {
            if let url = URL(string: word), isTransferable(url) {
                return TransferLink(url: url)
            }
        }
        return nil
    }

    /// `nil` when `url` is not a transfer link at all.
    static func incoming(_ url: URL) -> Incoming? {
        switch url.scheme?.lowercased() {
        case "magnet":
            return parse(url.absoluteString).map(Incoming.link) ?? .unsupported
        case "putio":
            guard url.host?.lowercased() == "transfers", url.path == "/add" else { return nil }
            return url.queryValue("url").flatMap(parse).map(Incoming.link) ?? .unsupported
        default:
            return nil
        }
    }

    private static func isTransferable(_ url: URL) -> Bool {
        switch url.scheme?.lowercased() {
        case "http", "https":
            return !(url.host ?? "").isEmpty
        case "magnet":
            let hash = url.queryValue("xt")?.lowercased()
            return hash?.hasPrefix("urn:btih:") == true || hash?.hasPrefix("urn:btmh:") == true
        default:
            return false
        }
    }
}
