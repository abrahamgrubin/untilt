import Foundation
import UserNotifications
import Combine

/// Reads the `deepLink` payload from a tapped local notification (the
/// slip check-in in MindfulGateView, and the therapist follow-up in
/// CompassChatView -- architecture doc Section 9) and turns it into a
/// pending "open Compass" request the UI can observe and act on.
/// Registered as UNUserNotificationCenter's delegate at app launch (see
/// UntiltApp.init()).
///
/// Before this existed, both notification types set a `deepLink`
/// userInfo payload but nothing ever read it -- tapping either one just
/// opened the app to whatever screen it was last on, with no connection
/// to what the notification was about. This closes that gap for both,
/// not just the new therapist follow-up.
///
/// A singleton `.shared`, matching this app's existing pattern for
/// app-wide services (AuthService.shared, BackendService.shared) rather
/// than introducing a new environment-object injection path.
@MainActor
final class NotificationRouter: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationRouter()

    /// Set when a notification tap should open Compass. HomeView observes
    /// this, presents CompassChatView with it as the slipContext, then
    /// clears it.
    @Published var pendingCompassContext: String?

    private override init() {
        super.init()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let deepLink = userInfo["deepLink"] as? String, deepLink == "compass" {
            // The notification's own body is the most relevant thing to
            // open Compass with -- reuses whatever copy/context was
            // written for the notification itself (slip check-in or
            // therapist follow-up) rather than duplicating it here.
            pendingCompassContext = response.notification.request.content.body
        }
        completionHandler()
    }

    /// Lets a notification still show as a banner/sound while the app is
    /// in the foreground. No delegate was registered before this, so
    /// foreground notifications were previously silent -- fixed as part
    /// of wiring this up, since it affects both notification flows the
    /// same way.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
