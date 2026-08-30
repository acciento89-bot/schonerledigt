import SwiftUI
import UIKit

struct HistoryView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var purchases: PurchaseManager
    @State private var searchText = ""
    @State private var selectedEvidence: EvidenceSelection?

    private var filteredHistory: [CompletionEvent] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .distantPast
        let available = purchases.hasPro ? store.history : store.history.filter { $0.completedAt >= cutoff }
        return searchText.isEmpty ? available : available.filter { $0.routineTitle.localizedCaseInsensitiveContains(searchText) || $0.completedBy.localizedCaseInsensitiveContains(searchText) }
    }
    private var groupedHistory: [(Date, [CompletionEvent])] {
        let groups = Dictionary(grouping: filteredHistory) { Calendar.current.startOfDay(for: $0.completedAt) }
        return groups.keys.sorted(by: >).map { ($0, groups[$0]!.sorted { $0.completedAt > $1.completedAt }) }
    }

    var body: some View {
        Group {
            if store.history.isEmpty { ContentUnavailableView("Noch kein Verlauf", systemImage: "clock.badge.questionmark", description: Text("Jede Bestätigung erscheint automatisch hier.")) }
            else {
                List {
                    ForEach(groupedHistory, id: \.0) { day, events in
                        Section(day.formatted(.dateTime.weekday(.wide).day().month(.wide))) {
                            ForEach(events) { event in
                                Button {
                                    if let image = store.evidenceImage(for: event) { selectedEvidence = EvidenceSelection(title: event.routineTitle, image: image) }
                                } label: {
                                    HStack(spacing: 13) {
                                        Image(systemName: event.symbol).font(.system(size: 18, weight: .semibold)).foregroundStyle(Color(hex: event.tintHex)).frame(width: 42, height: 42).background(Color(hex: event.tintHex).opacity(0.1), in: RoundedRectangle(cornerRadius: 13))
                                        VStack(alignment: .leading, spacing: 3) { Text(event.routineTitle).font(.headline); Text("\(event.completedBy) · \(event.completedAt.formatted(date: .omitted, time: .shortened))").font(.subheadline).foregroundStyle(Brand.secondaryInk) }
                                        Spacer(); if event.evidenceJPEG != nil || event.evidenceFileName != nil { Image(systemName: "photo.fill").foregroundStyle(Brand.primary) }
                                    }.padding(.vertical, 3)
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                }.listStyle(.insetGrouped).searchable(text: $searchText, prompt: "Verlauf durchsuchen")
            }
        }
        .navigationTitle("Verlauf")
        .sheet(item: $selectedEvidence) { selection in NavigationStack { Image(uiImage: selection.image).resizable().scaledToFit().background(.black).navigationTitle(selection.title).navigationBarTitleDisplayMode(.inline) } }
    }
}
private struct EvidenceSelection: Identifiable { let id = UUID(); let title: String; let image: UIImage }
