import SafariServices
import SwiftUI

/// Thin `UIViewControllerRepresentable` wrapper around `SFSafariViewController`,
/// so an external link (e.g. the Compass-driven Psychology Today hand-off,
/// architecture doc Section 9) opens in an in-app browser sheet with a
/// "Done" button back to Untilt, instead of fully backgrounding out to
/// Safari. Deliberately SFSafariViewController rather than a raw WKWebView:
/// it shows Psychology Today's real URL/security indicators (so the user
/// can see they're actually on psychologytoday.com, not something embedded
/// that merely looks like it) and shares Safari's session/cookies, both of
/// which Apple's guidelines prefer over a custom browser UI for this kind
/// of hand-off.
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
