import AppIntents
import SwiftUI
import WidgetKit

private let appGroup = "group.com.kamilunavo.schon-erledigt"
private let widgetKind = "SchonErledigtWidget"

struct WidgetRoutine: Codable, Identifiable {
    let id: UUID; var title: String; var detail: String; var symbol: String; var tintHex: String
    var resetRule: WidgetResetRule; var completedAt: Date?; var sortOrder: Int; var createdAt: Date; var updatedAt: Date?
    func isCompleted(at date: Date = .now) -> Bool { guard let completedAt else { return false }; guard let reset = resetRule.nextReset(after: completedAt) else { return true }; return date < reset }
}
enum WidgetResetRule: Codable {
    case manual
    case afterHours(Int)
    case daily(hour: Int, minute: Int)
    func nextReset(after completion: Date) -> Date? {
        switch self { case .manual: nil; case .afterHours(let hours): Calendar.current.date(byAdding: .hour, value: hours, to: completion); case .daily(let hour, let minute): Calendar.current.nextDate(after: completion, matching: DateComponents(hour: hour, minute: minute), matchingPolicy: .nextTime) }
    }
}
struct WidgetEvent: Codable, Identifiable {
    let id: UUID; let routineID: UUID; let routineTitle: String; let symbol: String; let tintHex: String
    let completedAt: Date; let completedBy: String; let evidenceFileName: String?; let evidenceJPEG: Data?
}
struct WidgetSnapshot: Codable {
    var routines: [WidgetRoutine]; var history: [WidgetEvent]; var displayName: String; var hasCompletedOnboarding: Bool
    var householdName: String?; var notificationsEnabled: Bool?; var iCloudEnabled: Bool?; var modifiedAt: Date?
}
enum WidgetDataStore {
    static var fileURL: URL? { FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)?.appendingPathComponent("SchonErledigt", isDirectory: true).appendingPathComponent("app-state.json") }
    static func load() -> WidgetSnapshot? { guard let fileURL, let data = try? Data(contentsOf: fileURL) else { return nil }; let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601; return try? decoder.decode(WidgetSnapshot.self, from: data) }
    static func complete(routineID: UUID) {
        guard let fileURL, var snapshot = load(), let index = snapshot.routines.firstIndex(where: { $0.id == routineID }) else { return }
        let date = Date.now; snapshot.routines[index].completedAt = date; snapshot.routines[index].updatedAt = date; let routine = snapshot.routines[index]
        snapshot.history.insert(WidgetEvent(id: UUID(), routineID: routine.id, routineTitle: routine.title, symbol: routine.symbol, tintHex: routine.tintHex, completedAt: date, completedBy: snapshot.displayName.isEmpty ? String(localized: "Ich") : snapshot.displayName, evidenceFileName: nil, evidenceJPEG: nil), at: 0)
        snapshot.modifiedAt = date; let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601; encoder.outputFormatting = [.sortedKeys]
        if let data = try? encoder.encode(snapshot) { try? data.write(to: fileURL, options: .atomic) }
    }
}
struct CompleteRoutineIntent: AppIntent {
    static let title: LocalizedStringResource = "Als erledigt bestätigen"
    static let description = IntentDescription("Bestätigt eine offene Karte direkt aus dem Widget.")
    static let isDiscoverable = false
    static let openAppWhenRun = false
    @Parameter(title: "Karte") var routineID: String
    init() {}; init(routineID: String) { self.routineID = routineID }
    func perform() async throws -> some IntentResult { if let id = UUID(uuidString: routineID) { WidgetDataStore.complete(routineID: id); WidgetCenter.shared.reloadAllTimelines() }; return .result() }
}
struct SchonErledigtEntry: TimelineEntry { let date: Date; let routines: [WidgetRoutine] }
struct SchonErledigtProvider: TimelineProvider {
    func placeholder(in context: Context) -> SchonErledigtEntry { SchonErledigtEntry(date: .now, routines: []) }
    func getSnapshot(in context: Context, completion: @escaping (SchonErledigtEntry) -> Void) { completion(entry()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<SchonErledigtEntry>) -> Void) { completion(Timeline(entries: [entry()], policy: .after(.now.addingTimeInterval(900)))) }
    private func entry() -> SchonErledigtEntry { let routines = WidgetDataStore.load()?.routines.filter { !$0.isCompleted() }.sorted { $0.sortOrder < $1.sortOrder } ?? []; return SchonErledigtEntry(date: .now, routines: Array(routines.prefix(3))) }
}
struct SchonErledigtWidgetView: View {
    @Environment(\.widgetFamily) private var family; let entry: SchonErledigtEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack { Label("Schon erledigt?", systemImage: "checkmark.seal.fill").font(.headline).foregroundStyle(Color(hex: "6C63FF")); Spacer(); Text("\(entry.routines.count) offen").font(.caption).foregroundStyle(.secondary) }
            if entry.routines.isEmpty { Spacer(); Label("Alles erledigt", systemImage: "sparkles").font(.headline).frame(maxWidth: .infinity); Spacer() }
            else { ForEach(entry.routines.prefix(family == .systemSmall ? 2 : 3)) { routine in HStack(spacing: 8) { Image(systemName: routine.symbol).foregroundStyle(Color(hex: routine.tintHex)).frame(width: 22); Text(routine.title).font(.subheadline.weight(.semibold)).lineLimit(1); Spacer(); Button(intent: CompleteRoutineIntent(routineID: routine.id.uuidString)) { Image(systemName: "checkmark.circle.fill").font(.title3) }.buttonStyle(.plain).tint(Color(hex: "6C63FF")) } }; Spacer(minLength: 0) }
        }.containerBackground(for: .widget) { Color.white }
    }
}
struct SchonErledigtWidget: Widget { var body: some WidgetConfiguration { StaticConfiguration(kind: widgetKind, provider: SchonErledigtProvider()) { SchonErledigtWidgetView(entry: $0) }.configurationDisplayName("Schon erledigt?").description("Offene Karten sehen und direkt bestätigen.").supportedFamilies([.systemSmall, .systemMedium]) } }
@main struct SchonErledigtWidgetBundle: WidgetBundle { var body: some Widget { SchonErledigtWidget() } }
private extension Color { init(hex: String) { var value: UInt64 = 0; Scanner(string: hex).scanHexInt64(&value); self.init(.sRGB, red: Double(value >> 16) / 255, green: Double((value >> 8) & 255) / 255, blue: Double(value & 255) / 255, opacity: 1) } }
