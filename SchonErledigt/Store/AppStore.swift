import Foundation
import SwiftUI
import UIKit
import WidgetKit

@MainActor final class AppStore: ObservableObject {
    static let appGroupIdentifier = "group.com.kamilunavo.schon-erledigt"
    @Published private(set) var routines: [RoutineItem] = []
    @Published private(set) var history: [CompletionEvent] = []
    @Published var displayName = "Ich" { didSet { save() } }
    @Published var hasCompletedOnboarding = false { didSet { save() } }
    @Published var householdName = "Unser Zuhause" { didSet { save() } }
    @Published var notificationsEnabled = false
    @Published var iCloudEnabled = false
    @Published private(set) var cloudState: CloudSyncState = .disabled

    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var modifiedAt = Date.now
    private var isLoading = true
    private var cloudUploadTask: Task<Void, Never>?

    init(fileManager: FileManager = .default) {
        let base = fileManager.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier)
            ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folder = base.appendingPathComponent("SchonErledigt", isDirectory: true)
        try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        fileURL = folder.appendingPathComponent("app-state.json")
        encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        load(); refreshExpiredItems(); isLoading = false
        if iCloudEnabled { Task { await syncCloud() } }
    }

    var openRoutines: [RoutineItem] { routines.filter { !$0.isCompleted() }.sorted { $0.sortOrder < $1.sortOrder } }
    var completedRoutines: [RoutineItem] { routines.filter { $0.isCompleted() }.sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) } }

    func complete(_ routine: RoutineItem, at date: Date = .now, evidenceImage: UIImage? = nil) {
        guard let index = routines.firstIndex(where: { $0.id == routine.id }) else { return }
        routines[index].completedAt = date; routines[index].updatedAt = date
        history.insert(CompletionEvent(routineID: routine.id, routineTitle: routine.title, symbol: routine.symbol, tintHex: routine.tintHex, completedAt: date,
                                       completedBy: displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? String(localized: "Ich") : displayName,
                                       evidenceJPEG: optimizedEvidence(evidenceImage)), at: 0)
        save()
        if notificationsEnabled { let updated = routines[index]; Task { await NotificationService.shared.scheduleResetReminder(for: updated) } }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    func reopen(_ routine: RoutineItem) {
        guard let index = routines.firstIndex(where: { $0.id == routine.id }) else { return }
        routines[index].completedAt = nil; routines[index].updatedAt = .now; save()
        Task { await NotificationService.shared.cancel(for: routine.id) }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func add(_ routine: RoutineItem) { var item = routine; item.sortOrder = (routines.map(\.sortOrder).max() ?? -1) + 1; item.updatedAt = .now; routines.append(item); save() }
    func update(_ routine: RoutineItem) { guard let index = routines.firstIndex(where: { $0.id == routine.id }) else { return }; var item = routine; item.updatedAt = .now; routines[index] = item; save() }
    func delete(_ routine: RoutineItem) { routines.removeAll { $0.id == routine.id }; save(); Task { await NotificationService.shared.cancel(for: routine.id) } }

    func refreshExpiredItems(at date: Date = .now) {
        var changed = false
        for index in routines.indices where routines[index].completedAt != nil && !routines[index].isCompleted(at: date) { routines[index].completedAt = nil; changed = true }
        if changed { save() }
    }

    func reloadFromDiskIfNeeded() {
        guard let data = try? Data(contentsOf: fileURL), let snapshot = try? decoder.decode(AppSnapshot.self, from: data), (snapshot.modifiedAt ?? .distantPast) > modifiedAt else { return }
        apply(snapshot); refreshExpiredItems()
    }
    func resetToSamples() { routines = Self.samples; history = []; save() }

    func setNotificationsEnabled(_ enabled: Bool) async -> Bool {
        if enabled {
            let granted = await NotificationService.shared.requestAuthorization(); notificationsEnabled = granted
            if granted { for routine in completedRoutines { await NotificationService.shared.scheduleResetReminder(for: routine) } }
            save(); return granted
        }
        notificationsEnabled = false; save(); return true
    }

    func setICloudEnabled(_ enabled: Bool) async { iCloudEnabled = enabled; cloudState = enabled ? .syncing : .disabled; save(scheduleCloudUpload: false); if enabled { await syncCloud() } }
    func syncCloud() async {
        guard iCloudEnabled else { cloudState = .disabled; return }
        cloudState = .syncing
        do {
            let local = try encodedSnapshot()
            let result = try await CloudKitService.shared.synchronize(localData: local, householdName: householdName, localModifiedAt: modifiedAt)
            if result != local, let remote = try? decoder.decode(AppSnapshot.self, from: result) { apply(remote); save(scheduleCloudUpload: false) }
            cloudState = .synced(.now)
        } catch { cloudState = .unavailable(error.localizedDescription) }
    }

    func snapshotData() -> Data? { try? encodedSnapshot() }
    func evidenceImage(for event: CompletionEvent) -> UIImage? {
        if let data = event.evidenceJPEG { return UIImage(data: data) }
        guard let name = event.evidenceFileName else { return nil }
        return UIImage(contentsOfFile: fileURL.deletingLastPathComponent().appendingPathComponent("Evidence").appendingPathComponent(name).path)
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL), let snapshot = try? decoder.decode(AppSnapshot.self, from: data) else { routines = Self.samples; return }
        routines = snapshot.routines; history = snapshot.history.sorted { $0.completedAt > $1.completedAt }; displayName = snapshot.displayName
        hasCompletedOnboarding = snapshot.hasCompletedOnboarding; householdName = snapshot.householdName ?? "Unser Zuhause"
        notificationsEnabled = snapshot.notificationsEnabled ?? false; iCloudEnabled = snapshot.iCloudEnabled ?? false; modifiedAt = snapshot.modifiedAt ?? .distantPast
    }
    private func save(scheduleCloudUpload: Bool = true) {
        guard !isLoading else { return }; modifiedAt = .now; guard let data = try? encodedSnapshot() else { return }; write(data)
        if scheduleCloudUpload && iCloudEnabled {
            cloudUploadTask?.cancel(); cloudUploadTask = Task { try? await Task.sleep(for: .seconds(1.2)); guard !Task.isCancelled else { return }; await syncCloud() }
        }
    }
    private func encodedSnapshot() throws -> Data { try encoder.encode(AppSnapshot(routines: routines, history: history, displayName: displayName, hasCompletedOnboarding: hasCompletedOnboarding, householdName: householdName, notificationsEnabled: notificationsEnabled, iCloudEnabled: iCloudEnabled, modifiedAt: modifiedAt)) }
    private func write(_ data: Data) {
        let temporaryURL = fileURL.appendingPathExtension("tmp")
        do { try data.write(to: temporaryURL, options: .atomic); if FileManager.default.fileExists(atPath: fileURL.path) { _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: temporaryURL) } else { try FileManager.default.moveItem(at: temporaryURL, to: fileURL) } }
        catch { try? FileManager.default.removeItem(at: temporaryURL) }
        WidgetCenter.shared.reloadAllTimelines()
    }
    private func apply(_ snapshot: AppSnapshot) {
        isLoading = true; routines = snapshot.routines; history = snapshot.history.sorted { $0.completedAt > $1.completedAt }; displayName = snapshot.displayName
        hasCompletedOnboarding = snapshot.hasCompletedOnboarding; householdName = snapshot.householdName ?? householdName
        notificationsEnabled = snapshot.notificationsEnabled ?? notificationsEnabled; iCloudEnabled = snapshot.iCloudEnabled ?? iCloudEnabled
        modifiedAt = snapshot.modifiedAt ?? .now; isLoading = false
    }
    private func optimizedEvidence(_ image: UIImage?) -> Data? {
        guard let image else { return nil }; let longest = max(image.size.width, image.size.height); guard longest > 0 else { return nil }
        let scale = min(1, 1280 / longest); let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        return UIGraphicsImageRenderer(size: target).image { _ in image.draw(in: CGRect(origin: .zero, size: target)) }.jpegData(compressionQuality: 0.62)
    }

    static let samples: [RoutineItem] = [
        RoutineItem(title: "Haustür abgeschlossen", detail: "Beim Verlassen kurz bestätigen", symbol: "lock.fill", tintHex: "6C63FF", resetRule: .daily(hour: 5, minute: 0), sortOrder: 0),
        RoutineItem(title: "Herd ausgeschaltet", detail: "Nach dem Kochen prüfen", symbol: "flame.fill", tintHex: "FF6B57", resetRule: .afterHours(8), sortOrder: 1),
        RoutineItem(title: "Haustier gefüttert", detail: "Morgens und abends", symbol: "pawprint.fill", tintHex: "28BFA3", resetRule: .afterHours(12), sortOrder: 2),
        RoutineItem(title: "Medikament genommen", detail: "Persönliche Dokumentation", symbol: "pills.fill", tintHex: "FFB84D", resetRule: .daily(hour: 5, minute: 0), sortOrder: 3),
        RoutineItem(title: "Pflanzen gegossen", detail: "Danach vier Tage Ruhe", symbol: "leaf.fill", tintHex: "53B86B", resetRule: .afterHours(96), sortOrder: 4)
    ]
}
