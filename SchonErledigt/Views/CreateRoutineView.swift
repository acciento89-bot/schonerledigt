import SwiftUI

struct CreateRoutineView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    private let existing: RoutineItem?
    @State private var title: String
    @State private var detail: String
    @State private var selectedSymbol: String
    @State private var selectedTint: String
    @State private var selectedReset: ResetRule
    init(routine: RoutineItem? = nil) {
        existing = routine; _title = State(initialValue: routine?.title ?? ""); _detail = State(initialValue: routine?.detail ?? "")
        _selectedSymbol = State(initialValue: routine?.symbol ?? "checkmark.circle.fill"); _selectedTint = State(initialValue: routine?.tintHex ?? "6C63FF")
        _selectedReset = State(initialValue: routine?.resetRule ?? .daily(hour: 0, minute: 0))
    }
    private let symbols = ["lock.fill", "flame.fill", "pawprint.fill", "pills.fill", "leaf.fill", "drop.fill", "cart.fill", "shippingbox.fill", "car.fill", "washer.fill", "bed.double.fill", "checkmark.circle.fill"]
    private let tints = ["6C63FF", "FF6B57", "28BFA3", "FFB84D", "53B86B", "3988FF", "C45BE8", "34435E"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Was möchtest du bestätigen?") { TextField("Zum Beispiel: Haustür abgeschlossen", text: $title); TextField("Kurzer Hinweis (optional)", text: $detail) }
                Section("Symbol") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 14) {
                        ForEach(symbols, id: \.self) { symbol in Button { selectedSymbol = symbol } label: { Image(systemName: symbol).font(.system(size: 20, weight: .semibold)).foregroundStyle(selectedSymbol == symbol ? .white : Color(hex: selectedTint)).frame(width: 42, height: 42).background(selectedSymbol == symbol ? Color(hex: selectedTint) : Color(hex: selectedTint).opacity(0.1), in: RoundedRectangle(cornerRadius: 13)) }.buttonStyle(.plain) }
                    }.padding(.vertical, 4)
                }
                Section("Farbe") { HStack(spacing: 13) { ForEach(tints, id: \.self) { tint in Button { selectedTint = tint } label: { Circle().fill(Color(hex: tint)).frame(width: 31, height: 31).overlay { if selectedTint == tint { Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.white) } } }.buttonStyle(.plain) } }.padding(.vertical, 4) }
                Section { Picker("Zurücksetzen", selection: $selectedReset) { ForEach(ResetRule.presets) { rule in Text(rule.title).tag(rule) } } } header: { Text("Wann soll sie wieder offen sein?") } footer: { Text("Die Bestätigung bleibt im Verlauf erhalten, auch wenn die Karte wieder offen wird.") }
                Section("Vorschau") { HStack(spacing: 14) { Image(systemName: selectedSymbol).font(.title2.weight(.semibold)).foregroundStyle(Color(hex: selectedTint)).frame(width: 52, height: 52).background(Color(hex: selectedTint).opacity(0.12), in: RoundedRectangle(cornerRadius: 16)); VStack(alignment: .leading, spacing: 4) { Text(cleanTitle.isEmpty ? String(localized: "Deine neue Karte") : cleanTitle).font(.headline); Text(detail.isEmpty ? selectedReset.title : detail).font(.subheadline).foregroundStyle(Brand.secondaryInk) } } }
            }
            .navigationTitle(existing == nil ? String(localized: "Neue Karte") : String(localized: "Karte bearbeiten")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button(existing == nil ? String(localized: "Erstellen") : String(localized: "Speichern")) { commit() }.fontWeight(.semibold).disabled(cleanTitle.isEmpty) } }
            .keyboardDoneToolbar()
        }
    }
    private var cleanTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
    private func commit() {
        if var item = existing { item.title = cleanTitle; item.detail = detail.trimmingCharacters(in: .whitespacesAndNewlines); item.symbol = selectedSymbol; item.tintHex = selectedTint; item.resetRule = selectedReset; store.update(item) }
        else { store.add(RoutineItem(title: cleanTitle, detail: detail.trimmingCharacters(in: .whitespacesAndNewlines), symbol: selectedSymbol, tintHex: selectedTint, resetRule: selectedReset, sortOrder: 0)) }
        dismiss()
    }
}
