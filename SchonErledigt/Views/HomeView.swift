import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var purchases: PurchaseManager
    @State private var showsCreateSheet = false
    @State private var evidenceRoutine: RoutineItem?
    @State private var editingRoutine: RoutineItem?
    @State private var showsPaywall = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                summaryHeader

                if store.openRoutines.isEmpty {
                    allDoneCard
                } else {
                    sectionTitle("Noch offen", count: store.openRoutines.count)
                    ForEach(store.openRoutines) { routine in
                        RoutineCard(routine: routine, completed: false, onPhotoRequested: {
                            if purchases.hasPro { evidenceRoutine = routine } else { showsPaywall = true }
                        }, onEdit: { editingRoutine = routine })
                    }
                }

                if !store.completedRoutines.isEmpty {
                    sectionTitle("Schon erledigt", count: store.completedRoutines.count)
                        .padding(.top, 10)
                    ForEach(store.completedRoutines) { routine in
                        RoutineCard(routine: routine, completed: true, onPhotoRequested: {}, onEdit: { editingRoutine = routine })
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 28)
        }
        .background(Brand.background)
        .navigationTitle("Schon erledigt?")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if store.routines.count < 6 || purchases.hasPro { showsCreateSheet = true } else { showsPaywall = true }
                } label: {
                    Image(systemName: "plus")
                        .fontWeight(.semibold)
                }
                .accessibilityLabel("Neue Karte erstellen")
            }
        }
        .sheet(isPresented: $showsCreateSheet) {
            CreateRoutineView()
                .environmentObject(store)
        }
        .sheet(item: $evidenceRoutine) { EvidenceCaptureView(routine: $0).environmentObject(store) }
        .sheet(item: $editingRoutine) { CreateRoutineView(routine: $0).environmentObject(store) }
        .sheet(isPresented: $showsPaywall) { PaywallView().environmentObject(purchases) }
    }

    private var summaryHeader: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().stroke(Brand.border, lineWidth: 8)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Brand.success, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(store.completedRoutines.count)/\(store.routines.count)")
                    .font(.system(.headline, design: .rounded, weight: .bold))
            }
            .frame(width: 72, height: 72)

            VStack(alignment: .leading, spacing: 5) {
                Text(greeting)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(Brand.ink)
                Text(summaryText)
                    .foregroundStyle(Brand.secondaryInk)
            }
            Spacer()
        }
        .padding(18)
        .background(Brand.card, in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Brand.border))
        .padding(.top, 8)
    }

    private var progress: CGFloat {
        guard !store.routines.isEmpty else { return 1 }
        return CGFloat(store.completedRoutines.count) / CGFloat(store.routines.count)
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: String(localized: "Guten Morgen")
        case 12..<18: String(localized: "Guten Tag")
        default: String(localized: "Guten Abend")
        }
    }

    private var summaryText: String {
        guard !store.openRoutines.isEmpty else { return String(localized: "Für jetzt ist alles erledigt.") }
        return String.localizedStringWithFormat(NSLocalizedString("%d Dinge brauchen noch Gewissheit.", comment: "Open cards"), store.openRoutines.count)
    }

    private var allDoneCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Brand.success)
            Text("Alles im grünen Bereich")
                .font(.headline)
            Text("Sobald eine Karte automatisch zurückgesetzt wird, erscheint sie wieder hier.")
                .font(.subheadline)
                .foregroundStyle(Brand.secondaryInk)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Brand.success.opacity(0.09), in: RoundedRectangle(cornerRadius: 22))
    }

    private func sectionTitle(_ title: String, count: Int) -> some View {
        HStack {
            Text(title).font(.headline).foregroundStyle(Brand.ink)
            Text("\(count)")
                .font(.caption.bold())
                .foregroundStyle(Brand.secondaryInk)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Brand.border, in: Capsule())
            Spacer()
        }
        .padding(.top, 4)
    }
}

private struct RoutineCard: View {
    @EnvironmentObject private var store: AppStore
    let routine: RoutineItem
    let completed: Bool
    let onPhotoRequested: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Button { completed ? store.reopen(routine) : store.complete(routine) } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(hex: routine.tintHex).opacity(completed ? 0.1 : 0.14))
                    Image(systemName: completed ? "checkmark" : routine.symbol)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(completed ? Brand.success : Color(hex: routine.tintHex))
                }
                .frame(width: 54, height: 54)

                VStack(alignment: .leading, spacing: 4) {
                    Text(routine.title)
                        .font(.headline)
                        .foregroundStyle(Brand.ink)
                        .strikethrough(completed, color: Brand.secondaryInk)
                    if completed, let date = routine.completedAt {
                        Text(String.localizedStringWithFormat(NSLocalizedString("Erledigt %@", comment: "Completion time"), date.relativeCompletionText))
                            .font(.subheadline)
                            .foregroundStyle(Brand.success)
                    } else {
                        Text(routine.detail.isEmpty ? routine.resetRule.title : routine.detail)
                            .font(.subheadline)
                            .foregroundStyle(Brand.secondaryInk)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)
                Image(systemName: completed ? "arrow.uturn.backward.circle" : "checkmark.circle.fill")
                    .font(.system(size: 27))
                    .foregroundStyle(completed ? Brand.secondaryInk.opacity(0.6) : Brand.primary)
            }
            }
            .buttonStyle(.plain)
            if !completed {
                Button(action: onPhotoRequested) { Image(systemName: "camera.fill").font(.system(size: 17, weight: .semibold)).foregroundStyle(Brand.primary).frame(width: 42, height: 54).background(Brand.primary.opacity(0.1), in: RoundedRectangle(cornerRadius: 16)) }.buttonStyle(.plain).accessibilityLabel("Mit Fotobeleg bestätigen")
            }
        }
        .padding(12).background(Brand.card, in: RoundedRectangle(cornerRadius: 21)).overlay(RoundedRectangle(cornerRadius: 21).stroke(completed ? Brand.success.opacity(0.22) : Brand.border)).opacity(completed ? 0.82 : 1)
        .contextMenu {
            Button(action: onEdit) { Label("Bearbeiten", systemImage: "pencil") }
            if !completed { Button(action: onPhotoRequested) { Label("Mit Fotobeleg bestätigen", systemImage: "camera") } }
            Button(role: .destructive) { store.delete(routine) } label: {
                Label("Karte löschen", systemImage: "trash")
            }
        }
        .accessibilityLabel("\(routine.title), \(completed ? String(localized: "erledigt") : String(localized: "offen"))")
        .accessibilityHint(completed ? String(localized: "Doppeltippen, um wieder zu öffnen") : String(localized: "Doppeltippen, um als erledigt zu markieren"))
    }
}
