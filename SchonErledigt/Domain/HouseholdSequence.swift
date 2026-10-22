import Foundation

struct SequenceCardState: Equatable {
    let id: String
    let title: String
    let confirmationToken: String?
    let confirmationOrder: Double?
    let confirmedAt: Date?
    init(id: String, title: String, confirmationToken: String?, confirmationOrder: Double?, confirmedAt: Date? = nil) {
        self.id = id; self.title = title; self.confirmationToken = confirmationToken
        self.confirmationOrder = confirmationOrder; self.confirmedAt = confirmedAt
    }
}

struct SequenceConfirmationReceipt: Codable, Equatable {
    let token: String
    let date: Date
}

struct SequenceStep: Identifiable, Codable, Equatable {
    let routineID: String
    let title: String
    var id: String { routineID }
}

struct SequenceHandover: Identifiable, Codable, Equatable {
    var id = UUID().uuidString
    let date: Date
    let from: String?
    let to: String
    let note: String
    let pendingIDs: [String]
}

struct SequenceRoundRecord: Identifiable, Codable, Equatable {
    var id = UUID().uuidString
    let name: String
    let startedAt: Date
    let endedAt: Date
    let responsiblePerson: String?
    let steps: [SequenceStep]
    let completedIDs: [String]
    let handovers: [SequenceHandover]
    var pendingIDs: [String] { steps.dropFirst(completedIDs.count).map(\.routineID) }
}

enum SequenceError: Error { case invalidDefinition, incomplete, invalidTime, invalidArchive, futureVersion }

struct HouseholdSequence: Identifiable, Codable, Equatable {
    var id = UUID().uuidString
    var name: String
    var steps: [SequenceStep]
    var people: [String]
    var rotationIndex = 0
    var startedAt: Date
    var baselineTokens: [String: String]
    var confirmationReceipts: [String: SequenceConfirmationReceipt]?
    var ownerOverride: String?
    var handovers: [SequenceHandover] = []
    var rounds: [SequenceRoundRecord] = []

    init(name: String, steps: [SequenceStep], people: [String], cards: [SequenceCardState], at date: Date) throws {
        guard Set(steps.map(\.routineID)).count == steps.count else { throw SequenceError.invalidDefinition }
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.steps = steps
        self.people = people.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        self.startedAt = date
        self.baselineTokens = Dictionary(uniqueKeysWithValues: steps.map { step in
            (step.routineID, cards.first(where: { $0.id == step.routineID })?.confirmationToken ?? "")
        })
        try validate()
    }

    var responsiblePerson: String? { ownerOverride ?? (people.isEmpty ? nil : people[rotationIndex]) }

    /// Only new confirmations in the actual dependency order form a completed prefix.
    func progress(cards: [SequenceCardState]) -> Int {
        var count = 0
        var previousOrder: Double?
        for step in steps {
            guard let card = cards.first(where: { $0.id == step.routineID }),
                  let token = card.confirmationToken, !token.isEmpty, token != baselineTokens[step.routineID],
                  isFresh(card),
                  let order = card.confirmationOrder, order.isFinite,
                  previousOrder.map({ order > $0 }) ?? true else { break }
            count += 1; previousOrder = order
        }
        return count
    }

    private func isFresh(_ card: SequenceCardState) -> Bool {
        guard let date = card.confirmedAt, date.timeIntervalSince1970.isFinite else { return false }
        if date > startedAt { return true }
        // The legacy app file truncates ISO8601 fractions. Recover only the exact
        // event previously observed with a real post-start timestamp.
        guard let receipt = confirmationReceipts?[card.id], receipt.token == card.confirmationToken,
              receipt.date > startedAt else { return false }
        return floor(receipt.date.timeIntervalSince1970) == floor(date.timeIntervalSince1970)
    }

    @discardableResult mutating func recordObservedConfirmations(cards: [SequenceCardState], at date: Date) throws -> Bool {
        try checkTime(date)
        var receipts = confirmationReceipts ?? [:]
        let original = receipts
        for step in steps.prefix(progress(cards: cards)) {
            guard let card = cards.first(where: { $0.id == step.routineID }),
                  let token = card.confirmationToken, let confirmedAt = card.confirmedAt,
                  confirmedAt > startedAt, confirmedAt <= date else { continue }
            receipts[step.routineID] = SequenceConfirmationReceipt(token: token, date: confirmedAt)
        }
        guard receipts != original else { return false }
        confirmationReceipts = receipts
        return true
    }

    func eligibleStepID(cards: [SequenceCardState]) -> String? {
        let count = progress(cards: cards)
        guard count < steps.count, cards.contains(where: { $0.id == steps[count].routineID }) else { return nil }
        return steps[count].routineID
    }

    mutating func handover(to person: String, note: String, cards: [SequenceCardState], at date: Date) throws {
        let to = person.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !to.isEmpty else { throw SequenceError.invalidDefinition }
        guard progress(cards: cards) < steps.count else { throw SequenceError.incomplete }
        try checkTime(date)
        handovers.append(SequenceHandover(date: date, from: responsiblePerson, to: to,
                                         note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                                         pendingIDs: Array(steps.dropFirst(progress(cards: cards))).map(\.routineID)))
        ownerOverride = to
    }

    mutating func nextRound(cards: [SequenceCardState], at date: Date) throws {
        guard progress(cards: cards) == steps.count else { throw SequenceError.incomplete }
        try checkTime(date)
        rounds.append(record(cards: cards, endedAt: date))
        if !people.isEmpty { rotationIndex = (rotationIndex + 1) % people.count }
        ownerOverride = nil; handovers = []; confirmationReceipts = nil; startedAt = date
        baselineTokens = Dictionary(uniqueKeysWithValues: steps.map { step in
            (step.routineID, cards.first(where: { $0.id == step.routineID })?.confirmationToken ?? "")
        })
    }

    mutating func reconfigure(name: String, steps: [SequenceStep], people: [String], cards: [SequenceCardState], at date: Date) throws {
        try checkTime(date)
        var replacement = try HouseholdSequence(name: name, steps: steps, people: people, cards: cards, at: date)
        replacement.id = id
        replacement.rounds = rounds + [record(cards: cards, endedAt: date)]
        self = replacement
    }

    private func checkTime(_ date: Date) throws {
        guard date.timeIntervalSince1970.isFinite, date >= startedAt else { throw SequenceError.invalidTime }
    }
    private func record(cards: [SequenceCardState], endedAt date: Date) -> SequenceRoundRecord {
        SequenceRoundRecord(name: name, startedAt: startedAt, endedAt: date, responsiblePerson: responsiblePerson,
                            steps: steps, completedIDs: Array(steps.prefix(progress(cards: cards))).map(\.routineID), handovers: handovers)
    }
    func validate() throws {
        func validSteps(_ values: [SequenceStep]) -> Bool {
            !values.isEmpty && values.allSatisfy { UUID(uuidString: $0.routineID) != nil && !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } && Set(values.map(\.routineID)).count == values.count
        }
        func validHandovers(_ values: [SequenceHandover], steps: [SequenceStep], start: Date, end: Date? = nil) -> Bool {
            Set(values.map(\.id)).count == values.count && values.allSatisfy { item in
                UUID(uuidString: item.id) != nil && item.date.timeIntervalSince1970.isFinite && item.date >= start &&
                (end.map { item.date <= $0 } ?? true) && !item.to.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                !item.pendingIDs.isEmpty && item.pendingIDs.count <= steps.count && item.pendingIDs == Array(steps.suffix(item.pendingIDs.count)).map(\.routineID)
            }
        }
        guard UUID(uuidString: id) != nil, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              validSteps(steps), people.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
              Set(people.map { $0.lowercased() }).count == people.count,
              rotationIndex >= 0, rotationIndex < max(people.count, 1),
              startedAt.timeIntervalSince1970.isFinite, Set(baselineTokens.keys) == Set(steps.map(\.routineID)),
              ownerOverride.map({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) ?? true,
              validHandovers(handovers, steps: steps, start: startedAt), Set(rounds.map(\.id)).count == rounds.count else { throw SequenceError.invalidDefinition }
        for (key, receipt) in confirmationReceipts ?? [:] {
            guard steps.contains(where: { $0.routineID == key }), !receipt.token.isEmpty,
                  receipt.date.timeIntervalSince1970.isFinite, receipt.date > startedAt else { throw SequenceError.invalidArchive }
        }
        for round in rounds {
            guard UUID(uuidString: round.id) != nil, !round.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  round.startedAt.timeIntervalSince1970.isFinite, round.endedAt.timeIntervalSince1970.isFinite,
                  round.endedAt >= round.startedAt, validSteps(round.steps), round.completedIDs.count <= round.steps.count,
                  round.completedIDs == Array(round.steps.prefix(round.completedIDs.count)).map(\.routineID),
                  validHandovers(round.handovers, steps: round.steps, start: round.startedAt, end: round.endedAt) else { throw SequenceError.invalidArchive }
        }
    }
}

struct SequenceArchive {
    let url: URL
    private struct Document: Codable { let schemaVersion: Int; let sequences: [HouseholdSequence] }
    func load() throws -> [HouseholdSequence] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let data = try Data(contentsOf: url)
        let values: [HouseholdSequence]
        if let document = try? JSONDecoder().decode(Document.self, from: data) {
            guard document.schemaVersion == 1 else { throw SequenceError.futureVersion }
            values = document.sequences
        } else { values = try JSONDecoder().decode([HouseholdSequence].self, from: data) }
        try validate(values); return values
    }
    func save(_ values: [HouseholdSequence]) throws {
        _ = try load(); try validate(values)
        let data = try JSONEncoder().encode(Document(schemaVersion: 1, sequences: values))
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }
    private func validate(_ values: [HouseholdSequence]) throws {
        guard Set(values.map(\.id)).count == values.count else { throw SequenceError.invalidArchive }
        try values.forEach { try $0.validate() }
    }
}
