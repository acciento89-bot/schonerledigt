import Foundation
import UserNotifications

actor NotificationService {
    static let shared = NotificationService()
    func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }
    func scheduleResetReminder(for routine: RoutineItem) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier(for: routine.id)])
        guard let resetDate = routine.nextResetDate(), resetDate > .now else { return }
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Wieder offen")
        content.body = String.localizedStringWithFormat(NSLocalizedString("„%@“ wartet auf eine neue Bestätigung.", comment: "Reset reminder"), routine.title)
        content.sound = .default
        content.userInfo = ["routineID": routine.id.uuidString]
        let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: resetDate)
        try? await center.add(UNNotificationRequest(identifier: identifier(for: routine.id), content: content, trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)))
    }
    func cancel(for routineID: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier(for: routineID)])
    }
    private func identifier(for id: UUID) -> String { "routine-reset-\(id.uuidString)" }
}
