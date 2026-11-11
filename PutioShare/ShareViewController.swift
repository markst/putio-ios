import UIKit
import UniformTypeIdentifiers

/// Hands a shared http, https, or magnet link to the put.io app, which confirms
/// and adds it. It holds no credentials and never calls the API.
final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        Task {
            await handle(await loadSharedText())
        }
    }

    private func loadSharedText() async -> String? {
        let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? [])
            .flatMap { $0.attachments ?? [] }

        if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.url.identifier) }) {
            let item = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier)
            return (item as? URL)?.absoluteString ?? (item as? String)
        } else if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) }) {
            let item = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier)
            return item as? String
        }
        return nil
    }

    private func handle(_ text: String?) async {
        guard let link = text.flatMap(TransferLink.parse) else {
            return showAlert(
                title: NSLocalizedString("Nothing to add", comment: ""),
                message: NSLocalizedString("put.io can add http, https, and magnet links.", comment: "")
            )
        }

        guard await openHostApp(link.appURL) else {
            return showAlert(
                title: NSLocalizedString("Couldn't open put.io", comment: ""),
                message: NSLocalizedString("Open the app and try sharing again.", comment: "")
            )
        }
        extensionContext?.completeRequest(returningItems: nil)
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .cancel) { [weak self] _ in
            self?.extensionContext?.cancelRequest(withError: NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError))
        })
        present(alert, animated: true)
    }

    /// Extensions cannot use `UIApplication.shared`, so this asks the responder
    /// chain's `UIApplication` to open the URL. The legacy `openURL:` is a no-op
    /// on current iOS, so only the options variant is called.
    private func openHostApp(_ url: URL) async -> Bool {
        typealias OpenURL = @convention(c) (
            AnyObject, Selector, URL, [UIApplication.OpenExternalURLOptionsKey: Any], ((Bool) -> Void)?
        ) -> Void
        let selector = Selector(("openURL:options:completionHandler:"))

        var responder: UIResponder? = self
        while let current = responder {
            if current.responds(to: selector) {
                let implementation = current.method(for: selector)
                return await withCheckedContinuation { continuation in
                    unsafeBitCast(implementation, to: OpenURL.self)(current, selector, url, [:]) { continuation.resume(returning: $0) }
                }
            }
            responder = current.next
        }
        return false
    }
}
