import SwiftUI

struct ShareDestination: Hashable {
    let name: String
    let icon: Image
    let action: ((SharingModal.Option, ShareImageStyle) -> Void)?

    enum Constants {
        static let displayedAppsCount = 3
    }

    static func ==(lhs: ShareDestination, rhs: ShareDestination) -> Bool {
        lhs.name == rhs.name && lhs.icon == rhs.icon
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }

    enum Destination: CaseIterable {
        case instagram

        var name: String {
            switch self {
            case .instagram:
                "Stories"
            }
        }

        var icon: Image {
            switch self {
            case .instagram:
                Image("instagram")
            }
        }

        func share(_ option: SharingModal.Option, style: ShareImageStyle) async {
            switch self {
            case .instagram:
                await instagramShare(image: Self.shareImage(option, style: style), url: option.shareURL)
            }
        }

        @MainActor
        static fileprivate func shareImage(_ option: SharingModal.Option, style: ShareImageStyle) -> UIImage {
            let imageView = ShareImageView(info: option.imageInfo, style: style, angle: .constant(0))
            return imageView.snapshot()
        }

        @MainActor
        private func instagramShare(image: UIImage, url: String) {
            guard let pngImage = image.pngData() else {
                return
            }

            let backgroundImage = pngImage
            let attributionURL = url
            let appID = ApiCredentials.instagramAppID

            guard let urlScheme = URL(string: "instagram-stories://share?source_application=\(appID)"),
                UIApplication.shared.canOpenURL(urlScheme) else {
                return
            }

            let pasteboardItems = [["com.instagram.sharedSticker.backgroundImage": backgroundImage,
                                    "com.instagram.sharedSticker.contentURL": attributionURL]]
            let pasteboardOptions: [UIPasteboard.OptionsKey: Any] = [.expirationDate: Date().addingTimeInterval(60 * 5)]

            UIPasteboard.general.setItems(pasteboardItems, options: pasteboardOptions)

            UIApplication.shared.open(urlScheme)
        }

        var isIncluded: Bool {
            return true
        }
    }

    static var displayedApps: Array<ShareDestination>.SubSequence {
        apps.prefix(Constants.displayedAppsCount)
    }

    private static var apps: [ShareDestination] {
        return Destination.allCases.compactMap({ destination in
            guard destination.isIncluded else { return nil }
            return ShareDestination(name: destination.name, icon: destination.icon, action: { option, style in
                Task.detached {
                    await destination.share(option, style: style)
                }
            })
        })
    }

    static func moreOption(vc: UIViewController) -> ShareDestination {
        let icon = Image(systemName: "ellipsis")

        if #available(iOS 16, *) {
            return ShareDestination(name: L10n.shareMoreActions, icon: icon, action: nil)
        } else {
            return ShareDestination(name: L10n.shareMoreActions, icon: icon, action: { option, style in
                Task.detached {
                    let activityItems = option.itemProviders(style: style)
                    let activityViewController = await UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
                    await vc.presentedViewController?.present(activityViewController, animated: true, completion: nil)
                }
            })
        }
    }

    static var copyLinkOption: ShareDestination {
        return ShareDestination(name: L10n.shareCopyLink, icon: Image("pocketcasts"), action: { option, _ in
            UIPasteboard.general.string = option.shareURL
            Toast.show(L10n.shareCopiedToClipboard)
        })
    }
}
