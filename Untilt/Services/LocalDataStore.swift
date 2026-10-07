import Foundation
import SwiftData
import UserNotifications

// MARK: - Local Data Store
// Urge events, journal entries, meditation completions, milestones and the
// profile live only on this device (SwiftData), not on the server, and
// aren't tagged with an account. So that one person's history is never
// shown to another person who signs in on the same phone, the device
// remembers which account its data belongs to and erases it when a
// different account signs in, or when the account is deleted.
//
// Signing out keeps the data: it's usually the same person signing back in,
// and the auth gate hides it in the meantime.
enum LocalDataStore {
    private static let ownerKey = "local_data_owner"

    /// Call whenever the signed-in user changes. Returns true if it erased
    /// another account's data.
    @MainActor
    @discardableResult
    static func claim(for userId: String, context: ModelContext) -> Bool {
        let defaults = UserDefaults.standard
        let owner = defaults.string(forKey: ownerKey)
        defaults.set(userId, forKey: ownerKey)
        // No owner yet: data from before this check existed belongs to
        // whoever signs in first, which on a personal phone is its owner.
        guard let owner, owner != userId else { return false }
        eraseAll(context: context)
        return true
    }

    /// Deletes every on-device record and per-user preference, and forgets
    /// the owner. Used on account deletion and when a different user signs in.
    @MainActor
    static func eraseAll(context: ModelContext) {
        // Fetch-and-delete rather than batch delete, so SwiftData applies
        // relationship rules (JournalEntry → UrgeEvent).
        deleteAll(JournalEntry.self, in: context)
        deleteAll(UrgeEvent.self, in: context)
        deleteAll(MeditationCompletion.self, in: context)
        deleteAll(MilestoneRecord.self, in: context)
        deleteAll(UserProfile.self, in: context)
        try? context.save()

        DailyInsightCache.clear()
        // Slip and therapist follow-ups are about the previous person.
        let notifications = UNUserNotificationCenter.current()
        notifications.removeAllPendingNotificationRequests()
        notifications.removeAllDeliveredNotifications()
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: CompassConsent.storageKey)
        defaults.removeObject(forKey: "returnAppURL")
    }

    /// Account deleted: erase everything and leave the phone unclaimed.
    @MainActor
    static func eraseForDeletedAccount(context: ModelContext) {
        eraseAll(context: context)
        UserDefaults.standard.removeObject(forKey: ownerKey)
    }

    @MainActor
    private static func deleteAll<T: PersistentModel>(_ type: T.Type, in context: ModelContext) {
        guard let items = try? context.fetch(FetchDescriptor<T>()) else { return }
        for item in items { context.delete(item) }
    }
}
