import SwiftUI

struct SequencesView: View {
    @EnvironmentObject private var sequences: SequenceStore
    @State private var creating = false
    @State private var deleting: String?
    var body: some View {
        List {
            Section { Text("sequence.localNotice").font(.footnote).foregroundStyle(.secondary) }
            SequenceStorageStatus()
            if sequences.sequences.isEmpty && !sequences.loadFailed {
                ContentUnavailableView("sequence.empty", systemImage: "list.number", description: Text("sequence.emptyHint"))
            }
            ForEach(sequences.sequences) { group in
                NavigationLink { SequenceDetailView(sequenceID: group.id) } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(group.name).font(.headline)
                        Text(group.responsiblePerson ?? String(localized: "sequence.unassigned")).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                .swipeActions { Button("sequence.delete", role: .destructive) { deleting = group.id } }
            }
        }
        .navigationTitle("sequence.title")
        .toolbar { Button("sequence.new", systemImage: "plus") { creating = true }.disabled(sequences.loadFailed) }
        .sheet(isPresented: $creating) { SequenceEditor(sequenceID: nil) }
        .confirmationDialog("sequence.deleteConfirm", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
            Button("sequence.delete", role: .destructive) {
                _ = sequences.commit(sequences.sequences.filter { $0.id != deleting }); deleting = nil
            }
        }
    }
}

private struct SequenceStorageStatus: View {
    @EnvironmentObject private var store: SequenceStore
    var body: some View {
        if store.loadFailed {
            Section { Text("sequence.loadError").foregroundStyle(.red); Button("sequence.retry") { store.reload() } }
        } else if let error = store.errorKey {
            Section { Text(LocalizedStringKey(error)).foregroundStyle(.red) }
        }
    }
}

private struct SequenceDetailView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var sequences: SequenceStore
    @EnvironmentObject private var purchases: PurchaseManager
    let sequenceID: String
    @State private var editing = false
    @State private var handingOver = false
    @State private var startingRound = false
    @State private var evidenceRoutine: RoutineItem?
    @State private var paywall = false
    private var group: HouseholdSequence? { sequences.sequences.first { $0.id == sequenceID } }
    private func cards(at date: Date = .now) -> [SequenceCardState] {
        SequenceCardAdapter.states(routines: store.routines, history: store.history, at: date)
    }
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            List {
                SequenceStorageStatus()
                if let group {
                    let state = cards(at: context.date)
                    let progress = group.progress(cards: state)
                    Section {
                        Text(group.name).font(.title2.bold())
                        LabeledContent("sequence.responsible", value: group.responsiblePerson ?? String(localized: "sequence.unassigned"))
                        Text("\(progress)/\(group.steps.count)").font(.headline).accessibilityLabel(Text("sequence.progress") + Text(" \(progress)/\(group.steps.count)"))
                        Text("sequence.localNotice").font(.footnote).foregroundStyle(.secondary)
                        Button("sequence.edit", systemImage: "pencil") { editing = true }.disabled(sequences.loadFailed)
                    }
                    Section("sequence.steps") {
                        ForEach(group.steps) { step in
                            stepView(step, group: group, progress: progress)
                        }
                    }
                    Section {
                        Button("sequence.handover", systemImage: "person.2") { handingOver = true }
                            .disabled(progress == group.steps.count || sequences.loadFailed)
                        Button("sequence.nextRound", systemImage: "arrow.triangle.2.circlepath") { startingRound = true }
                            .disabled(progress != group.steps.count || sequences.loadFailed)
                        Text("sequence.roundHint").font(.footnote).foregroundStyle(.secondary)
                    }
                    if !group.handovers.isEmpty {
                        Section("sequence.handovers") {
                            ForEach(group.handovers.reversed()) { event in handoverView(event, steps: group.steps) }
                        }
                    }
                    ForEach(group.rounds.reversed()) { round in
                        Section("sequence.previousRound") {
                            Text(round.name).font(.headline)
                            Text(round.endedAt, format: .dateTime.year().month().day().hour().minute())
                            Text(round.responsiblePerson ?? String(localized: "sequence.unassigned"))
                            Text(LocalizedStringKey(round.pendingIDs.isEmpty ? "sequence.finished" : "sequence.incomplete"))
                                .foregroundStyle(round.pendingIDs.isEmpty ? Brand.success : Brand.primary)
                            ForEach(round.steps) { step in
                                Label(step.title, systemImage: round.completedIDs.contains(step.routineID) ? "checkmark.circle" : "circle")
                            }
                            ForEach(round.handovers) { handoverView($0, steps: round.steps) }
                        }
                    }
                }
            }
        }
        .navigationTitle("sequence.title")
        .sheet(isPresented: $editing) { SequenceEditor(sequenceID: sequenceID) }
        .sheet(isPresented: $handingOver) { SequenceHandoverEditor(sequenceID: sequenceID) }
        .sheet(item: $evidenceRoutine) { EvidenceCaptureView(routine: $0).environmentObject(store) }
        .sheet(isPresented: $paywall) { PaywallView().environmentObject(purchases) }
        .confirmationDialog("sequence.nextRoundConfirm", isPresented: $startingRound, titleVisibility: .visible) {
            Button("sequence.nextRound") {
                guard var value = group else { return }
                do { try value.nextRound(cards: cards(), at: .now); _ = sequences.save(value) }
                catch { sequences.errorKey = "sequence.changed" }
            }
        } message: { Text("sequence.roundHint") }
    }
    private func stepView(_ step: SequenceStep, group: HouseholdSequence, progress: Int) -> some View {
        let index = group.steps.firstIndex(where: { $0.routineID == step.routineID }) ?? 0
        let routine = store.routines.first { $0.id.uuidString == step.routineID }
        return VStack(alignment: .leading, spacing: 10) {
            Text("\(index + 1). \(routine?.title ?? step.title)").font(.headline)
            if index < progress {
                Label("sequence.confirmed", systemImage: "checkmark.circle.fill").foregroundStyle(Brand.success)
            } else if routine == nil {
                Text("sequence.missingCard").foregroundStyle(.red)
            } else {
                Text(LocalizedStringKey(index == progress ? "sequence.checkNow" : "sequence.waiting")).font(.subheadline).foregroundStyle(.secondary)
                Button("sequence.confirm", systemImage: "checkmark.circle") {
                    guard let routine, group.eligibleStepID(cards: cards()) == step.routineID else { sequences.errorKey = "sequence.changed"; return }
                    store.complete(routine)
                    let observedAt = Date.now
                    sequences.observe(cards: cards(at: observedAt), at: observedAt)
                }.disabled(index != progress || sequences.loadFailed)
                Button("sequence.photo", systemImage: "camera") {
                    guard let routine, group.eligibleStepID(cards: cards()) == step.routineID else { sequences.errorKey = "sequence.changed"; return }
                    if purchases.hasPro { evidenceRoutine = routine } else { paywall = true }
                }.disabled(index != progress || sequences.loadFailed)
            }
        }.padding(.vertical, 6)
    }
    private func handoverView(_ event: SequenceHandover, steps: [SequenceStep]) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("\(event.from ?? String(localized: "sequence.unassigned")) → \(event.to)").font(.headline)
            Text(event.date, format: .dateTime.year().month().day().hour().minute()).font(.caption).foregroundStyle(.secondary)
            if !event.note.isEmpty { Text(event.note) }
            Text("sequence.pendingAtHandover").font(.caption.bold())
            ForEach(event.pendingIDs, id: \.self) { id in Text(steps.first(where: { $0.routineID == id })?.title ?? id) }
        }.padding(.vertical, 4)
    }
}

private struct SequenceEditor: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var sequences: SequenceStore
    @Environment(\.dismiss) private var dismiss
    let sequenceID: String?
    @State private var name = ""
    @State private var selected: [SequenceStep] = []
    @State private var people = ""
    @State private var initialized = false
    var body: some View {
        NavigationStack {
            Form {
                SequenceStorageStatus()
                Section("sequence.name") { TextField("sequence.name", text: $name) }
                Section("sequence.steps") {
                    ForEach(selected) { step in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(step.title).font(.headline)
                            HStack {
                                Button("sequence.up", systemImage: "arrow.up") { move(step.routineID, delta: -1) }.buttonStyle(.bordered)
                                Button("sequence.down", systemImage: "arrow.down") { move(step.routineID, delta: 1) }.buttonStyle(.bordered)
                                Button("sequence.remove", role: .destructive) { selected.removeAll { $0.routineID == step.routineID } }.buttonStyle(.bordered)
                            }
                        }
                    }
                    if selected.isEmpty { Text("sequence.chooseCards").foregroundStyle(.secondary) }
                }
                Section("sequence.availableCards") {
                    ForEach(store.routines.filter { routine in !selected.contains { $0.routineID == routine.id.uuidString } }.sorted { $0.sortOrder < $1.sortOrder }) { routine in
                        Button { selected.append(SequenceStep(routineID: routine.id.uuidString, title: routine.title)) } label: { Label(routine.title, systemImage: "plus.circle") }
                    }
                    Text("sequence.cardsHint").font(.footnote).foregroundStyle(.secondary)
                }
                Section("sequence.people") {
                    TextField("sequence.peopleHint", text: $people, axis: .vertical).lineLimit(3...8)
                    Text("sequence.peopleHelp").font(.footnote).foregroundStyle(.secondary)
                }
                Section { Text(LocalizedStringKey(sequenceID == nil ? "sequence.startHint" : "sequence.editHint")).font(.footnote); Text("sequence.localNotice").font(.footnote) }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(Text(LocalizedStringKey(sequenceID == nil ? "sequence.new" : "sequence.edit")))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("sequence.saveStart") { save() }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selected.isEmpty || sequences.loadFailed) }
            }
            .onAppear {
                guard !initialized else { return }; initialized = true
                if let group = sequences.sequences.first(where: { $0.id == sequenceID }) { name = group.name; selected = group.steps; people = group.people.joined(separator: "\n") }
            }
        }
    }
    private func move(_ id: String, delta: Int) {
        guard let index = selected.firstIndex(where: { $0.routineID == id }), selected.indices.contains(index + delta) else { return }
        selected.swapAt(index, index + delta)
    }
    private func save() {
        let now = Date.now
        let cards = SequenceCardAdapter.states(routines: store.routines, history: store.history, at: now)
        let roster = people.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        do {
            var value: HouseholdSequence
            if let id = sequenceID {
                guard let existing = sequences.sequences.first(where: { $0.id == id }) else { sequences.errorKey = "sequence.changed"; return }
                value = existing; try value.reconfigure(name: name, steps: selected, people: roster, cards: cards, at: now)
            } else { value = try HouseholdSequence(name: name, steps: selected, people: roster, cards: cards, at: now) }
            if sequences.save(value) { dismiss() }
        } catch { sequences.errorKey = "sequence.invalid" }
    }
}

private struct SequenceHandoverEditor: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var sequences: SequenceStore
    @Environment(\.dismiss) private var dismiss
    let sequenceID: String
    @State private var person = ""
    @State private var note = ""
    var body: some View {
        NavigationStack {
            Form {
                SequenceStorageStatus()
                Section("sequence.handoverTo") { TextField("sequence.person", text: $person) }
                Section("sequence.handoverNote") { TextField("sequence.handoverNote", text: $note, axis: .vertical).lineLimit(3...8) }
                Section { Text("sequence.handoverHint").font(.footnote) }
            }
            .navigationTitle("sequence.handover")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("sequence.saveHandover") {
                        guard var group = sequences.sequences.first(where: { $0.id == sequenceID }) else { return }
                        let now = Date.now
                        let cards = SequenceCardAdapter.states(routines: store.routines, history: store.history, at: now)
                        do { try group.handover(to: person, note: note, cards: cards, at: now); if sequences.save(group) { dismiss() } }
                        catch { sequences.errorKey = "sequence.changed" }
                    }.disabled(person.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || sequences.loadFailed)
                }
            }
        }
    }
}
