import Foundation
import UserNotifications
import AppKit

/// Desktop-notification wrapper over `UNUserNotificationCenter`. Used
/// by `DashboardPoller` to surface new moments, race results, and
/// imminent races without demanding the app is frontmost.
///
/// Authorization is requested lazily on the first notification attempt
/// rather than at app launch — a cold-start permission prompt for a
/// dashboard app is poor UX. The first notification the user would
/// otherwise receive becomes the moment we ask for permission.
///
/// Notification categories (for grouping + future action buttons):
///   - `moment`   — a new milestone/achievement was detected
///   - `result`   — a race finished and appeared in the session list
///   - `upcoming` — a next-race-ideas suggestion starts within N minutes
@MainActor
final class NotificationCoordinator {
    static let shared = NotificationCoordinator()

    enum Category: String {
        case moment   = "moment"
        case result   = "result"
        case upcoming = "upcoming"

        /// Seed SF Symbol for the notification body (the system doesn't
        /// use this, but leaving it here as documentation of intent).
        var symbol: String {
            switch self {
            case .moment:   return "sparkles"
            case .result:   return "flag.checkered"
            case .upcoming: return "clock"
            }
        }
    }

    private var didRequestAuthorization = false
    private var isAuthorized = false

    private init() {}

    /// Fire a notification. Returns silently if the user has denied
    /// permission or the system rejects the request — we never throw
    /// back into the caller because notifications are a best-effort
    /// side-channel, not part of the primary data flow.
    func post(
        category: Category,
        title: String,
        body: String,
        deduplicationKey: String? = nil
    ) async {
        await ensureAuthorization()
        guard isAuthorized else { return }

        // Dedup: if we've already fired a notification with this key,
        // skip. Prevents multiple notifications for the same moment
        // when the poller sees it across consecutive ticks.
        let identifier = deduplicationKey ?? UUID().uuidString
        if Self.firedIdentifiers.contains(identifier) { return }
        Self.firedIdentifiers.insert(identifier)

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = category.rawValue

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil    // fire immediately
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            Log.error("[NOTIF] Failed to post \(category.rawValue): \(error)")
        }
    }

    /// Permission request is one-shot. If the user declines we remember
    /// that for the process lifetime and stop trying.
    private func ensureAuthorization() async {
        guard !didRequestAuthorization else { return }
        didRequestAuthorization = true

        let center = UNUserNotificationCenter.current()
        do {
            let settings = await center.notificationSettings()
            switch settings.authorizationStatus {
            case .authorized, .provisional:
                isAuthorized = true
            case .notDetermined:
                isAuthorized = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            default:
                isAuthorized = false
            }
        } catch {
            Log.error("[NOTIF] authorization failed: \(error)")
            isAuthorized = false
        }
    }

    /// In-memory dedup set — survives across app-lifetime poll cycles,
    /// resets on relaunch. Good enough for "don't spam the user about
    /// the same moment three times in a row". A persistent store would
    /// be better but that's follow-up work.
    private static var firedIdentifiers: Set<String> = []
}
