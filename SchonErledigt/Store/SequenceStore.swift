import Foundation
import Combine

@MainActor final class SequenceStore: ObservableObject {
    @Published private(set) var sequences: [HouseholdSequence] = []
    @Published private(set) var loadFailed = false
    @Published var errorKey: String?
    private let archive: SequenceArchive
    init() {
        let manager = FileManager.default
        let base = manager.containerURL(forSecurityApplicationGroupIdentifier: AppStore.appGroupIdentifier)
            ?? manager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        archive = SequenceArchive(url: base.appendingPathComponent("SchonErledigt/sequences.json"))
        reload()
    }
    func reload() {
        do { sequences = try archive.load(); loadFailed = false; errorKey = nil }
        catch { loadFailed = true; errorKey = "sequence.loadError" }
    }
    @discardableResult func commit(_ values: [HouseholdSequence]) -> Bool {
        guard !loadFailed else { errorKey = "sequence.loadError"; return false }
        do { try archive.save(values); sequences = values; errorKey = nil; return true }
        catch { errorKey = "sequence.saveError"; return false }
    }
    func observe(cards: [SequenceCardState], at date: Date) {
        guard !loadFailed else { return }
        var next = sequences
        var changed = false
        do {
            for index in next.indices {
                if date >= next[index].startedAt,
                   try next[index].recordObservedConfirmations(cards: cards, at: date) { changed = true }
            }
            if changed { _ = commit(next) }
        } catch { errorKey = "sequence.saveError" }
    }
    @discardableResult func save(_ value: HouseholdSequence) -> Bool {
        var next = sequences
        if let index = next.firstIndex(where: { $0.id == value.id }) { next[index] = value }
        else { next.append(value) }
        return commit(next)
    }
}
