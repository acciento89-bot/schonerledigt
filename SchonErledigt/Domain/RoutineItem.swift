import Foundation

enum ResetRule: Codable, Hashable, Identifiable {
    case manual
    case afterHours(Int)
    case daily(hour: Int, minute: Int)

    var id: String {
        switch self {
        case .manual: "manual"
        case .afterHours(let hours): "hours-\(hours)"
        case .daily(let hour, let minute): "daily-\(hour)-\(minute)"
        }
    }

    var title: String {
        switch self {
        case .manual: String(localized: "Nur manuell")
        case .afterHours(let hours): String.localizedStringWithFormat(NSLocalizedString("Nach %d Stunden", comment: "Reset interval"), hours)
        case .daily(let hour, let minute): String.localizedStringWithFormat(NSLocalizedString("Täglich um %02d:%02d", comment: "Daily reset"), hour, minute)
        }
    }

    static let presets: [ResetRule] = [.daily(hour: 0, minute: 0), .daily(hour: 6, minute: 0), .afterHours(4), .afterHours(8), .afterHours(12), .afterHours(24), .manual]

    func nextReset(after completion: Date, calendar: Calendar = .current) -> Date? {
        switch self {
        case .manual: return nil
        case .afterHours(let hours): return calendar.date(byAdding: .hour, value: hours, to: completion)
        case .daily(let hour, let minute):
            var components = calendar.dateComponents([.year, .month, .day], from: completion)
            components.hour = hour; components.minute = minute; components.second = 0
            guard let today = calendar.date(from: components) else { return nil }
            return today > completion ? today : calendar.date(byAdding: .day, value: 1, to: today)
        }
    }
}

struct RoutineItem: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var detail: String
    var symbol: String
    var tintHex: String
    var resetRule: ResetRule
    var completedAt: Date?
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date?

    init(id: UUID = UUID(), title: String, detail: String = "", symbol: String, tintHex: String, resetRule: ResetRule, completedAt: Date? = nil, sortOrder: Int, createdAt: Date = .now) {
        self.id = id; self.title = title; self.detail = detail; self.symbol = symbol; self.tintHex = tintHex
        self.resetRule = resetRule; self.completedAt = completedAt; self.sortOrder = sortOrder
        self.createdAt = createdAt; self.updatedAt = createdAt
    }

    func isCompleted(at date: Date = .now) -> Bool {
        guard let completedAt else { return false }
        guard let reset = resetRule.nextReset(after: completedAt) else { return true }
        return date < reset
    }

    func nextResetDate() -> Date? {
        guard let completedAt else { return nil }
        return resetRule.nextReset(after: completedAt)
    }
}

struct CompletionEvent: Identifiable, Codable, Hashable {
    let id: UUID
    let routineID: UUID
    let routineTitle: String
    let symbol: String
    let tintHex: String
    let completedAt: Date
    let completedBy: String
    let evidenceFileName: String?
    let evidenceJPEG: Data?

    init(id: UUID = UUID(), routineID: UUID, routineTitle: String, symbol: String, tintHex: String, completedAt: Date = .now, completedBy: String = "Ich", evidenceFileName: String? = nil, evidenceJPEG: Data? = nil) {
        self.id = id; self.routineID = routineID; self.routineTitle = routineTitle; self.symbol = symbol
        self.tintHex = tintHex; self.completedAt = completedAt; self.completedBy = completedBy
        self.evidenceFileName = evidenceFileName; self.evidenceJPEG = evidenceJPEG
    }
}

struct AppSnapshot: Codable {
    var routines: [RoutineItem]
    var history: [CompletionEvent]
    var displayName: String
    var hasCompletedOnboarding: Bool
    var householdName: String?
    var notificationsEnabled: Bool?
    var iCloudEnabled: Bool?
    var modifiedAt: Date?
}

enum CloudSyncState: Equatable {
    case disabled, syncing, synced(Date), unavailable(String)
    var title: String {
        switch self {
        case .disabled: String(localized: "Aus")
        case .syncing: String(localized: "Synchronisierung …")
        case .synced(let date): String.localizedStringWithFormat(NSLocalizedString("Aktuell · %@", comment: "Cloud sync time"), date.formatted(date: .omitted, time: .shortened))
        case .unavailable: String(localized: "Nicht verfügbar")
        }
    }
}
