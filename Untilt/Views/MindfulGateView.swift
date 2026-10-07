import SwiftUI
import SwiftData
import UserNotifications

// MARK: - Mindful Gate View
// Shown when the iOS Shortcut launches Untilt via URL scheme before a gambling app.
// Wraps BoxBreathingView and persists an UrgeEvent on completion or abandonment.

struct MindfulGateView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    var onComplete: () -> Void

    var body: some View {
        BoxBreathingView {
            recordUrgeEvent(completed: true)
            onComplete()
        }
        .onDisappear {
            // If dismissed without completing the breathing, it's a Slip
            // We detect this via the BoxBreathingView's completion callback not firing
        }
        .interactiveDismissDisabled(false)
    }
}

// MARK: - UrgeEvent persistence helpers
extension MindfulGateView {
    private func recordUrgeEvent(completed: Bool) {
        let event = UrgeEvent(completed: completed)
        modelContext.insert(event)
        try? modelContext.save()

        clearReturnURL()

        if !completed {
            scheduleSlipCheckIn()
        }
    }

    private func clearReturnURL() {
        UserDefaults.standard.removeObject(forKey: "returnAppURL")
    }

    private func scheduleSlipCheckIn() {
        // With Compass off, don't promise Compass (it would open the consent
        // screen); send them to Resources, where the helplines are.
        let compassEnabled = UserDefaults.standard.bool(forKey: CompassConsent.storageKey)
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            // Neutral wording: this shows on the lock screen.
            content.title = "A gentle check-in"
            if compassEnabled {
                content.body = "Compass is here whenever you're ready to talk."
                content.userInfo = ["deepLink": "compass"]
            } else {
                content.body = "Support is here whenever you're ready."
                content.userInfo = ["deepLink": "resources"]
            }
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: false)
            let request = UNNotificationRequest(identifier: "slip-\(Date().timeIntervalSince1970)",
                                                content: content,
                                                trigger: trigger)
            UNUserNotificationCenter.current().add(request)
        }
    }
}
