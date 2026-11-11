import UIKit

/// Confirms a link, adds it as a transfer in the account's default folder, and
/// reports the result. The app has no Transfers screen, so the result alert is
/// the only sign the transfer started.
enum TransferAddPresenter {
    static func present(_ incoming: TransferLink.Incoming, from root: UIViewController?) {
        guard var presenter = root else {
            return InternalFailurePresenter.log("Unable to present transfer prompt", context: "TransferAddPresenter.present")
        }
        while let presented = presenter.presentedViewController {
            presenter = presented
        }
        // A prompt already on screen wins; the later link is dropped.
        guard !(presenter is UIAlertController) else {
            return InternalFailurePresenter.log("Unable to present transfer prompt", context: "TransferAddPresenter.present")
        }

        switch incoming {
        case .unsupported:
            presenter.present(
                alert(
                    title: NSLocalizedString("Unsupported link", comment: ""),
                    message: NSLocalizedString("put.io can add http, https, and magnet links.", comment: "")
                ),
                animated: true
            )
        case .link(let link):
            presentConfirmation(for: link, from: presenter)
        }
    }

    private static func presentConfirmation(for link: TransferLink, from presenter: UIViewController) {
        let message: String
        if let name = link.displayName {
            message = name
        } else if link.isMagnet {
            message = NSLocalizedString("Magnet link", comment: "")
        } else {
            message = link.truncatedURL
        }

        let confirmation = UIAlertController(
            title: NSLocalizedString("Add to put.io?", comment: ""),
            message: message,
            preferredStyle: .alert
        )
        confirmation.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel))
        confirmation.addAction(UIAlertAction(title: NSLocalizedString("Add", comment: ""), style: .default) { _ in
            add(link, from: presenter)
        })
        presenter.present(confirmation, animated: true)
    }

    private static func add(_ link: TransferLink, from presenter: UIViewController) {
        let loadingAlert = UIAlertController(
            title: NSLocalizedString("Adding...", comment: ""),
            message: nil,
            preferredStyle: .alert
        )
        presenter.present(loadingAlert, animated: true) {
            api.addTransfer(url: link.url.absoluteString) { result in
                loadingAlert.dismiss(animated: true) {
                    switch result {
                    case .success(let transfer):
                        presenter.present(
                            alert(
                                title: NSLocalizedString("Transfer started", comment: ""),
                                message: String(
                                    format: NSLocalizedString("%@ was added to put.io. It will appear in your files when it finishes.", comment: ""),
                                    transfer.name
                                )
                            ),
                            animated: true
                        )
                    case .failure(let error):
                        let localizedError = api.localizeError(error: error)
                        presenter.present(
                            alert(title: localizedError.message, message: localizedError.recoverySuggestion.description),
                            animated: true
                        )
                    }
                }
            }
        }
    }

    private static func alert(title: String, message: String) -> UIAlertController {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .cancel))
        return alert
    }
}
