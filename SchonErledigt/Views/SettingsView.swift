import CloudKit
import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var purchases: PurchaseManager
    @State private var showsResetConfirmation = false
    @State private var showsCloudShare = false
    @State private var showsPaywall = false
    @State private var notificationToggleBusy = false

    var body: some View {
        Form {
            Section("Profil") { TextField("Dein Name", text: $store.displayName).textContentType(.name); TextField("Name des Haushalts", text: $store.householdName) }
            Section {
                Toggle(isOn: Binding(get: { store.iCloudEnabled }, set: { enabled in
                    if enabled && !purchases.hasPro { showsPaywall = true } else { Task { await store.setICloudEnabled(enabled) } }
                })) { Label("iCloud-Synchronisierung", systemImage: "icloud.fill") }
                LabeledContent("Status", value: store.cloudState.title)
                if store.iCloudEnabled {
                    Button { Task { await store.syncCloud() } } label: { Label("Jetzt synchronisieren", systemImage: "arrow.triangle.2.circlepath") }
                    Button { showsCloudShare = true } label: { Label("Haushalt einladen", systemImage: "person.badge.plus") }.disabled(store.snapshotData() == nil)
                    if case .unavailable(let message) = store.cloudState { Text(message).font(.footnote).foregroundStyle(.red) }
                }
            } header: { Text("Gemeinsam") } footer: { Text("Einladungen laufen direkt über Apples private iCloud-Freigabe. Ohne Aktivierung bleiben alle Daten nur auf diesem iPhone.") }
            Section("Erinnerungen") {
                Toggle(isOn: Binding(get: { store.notificationsEnabled }, set: { enabled in
                    notificationToggleBusy = true; Task { _ = await store.setNotificationsEnabled(enabled); notificationToggleBusy = false }
                })) { Label("Bei Rücksetzung erinnern", systemImage: "bell.badge.fill") }.disabled(notificationToggleBusy)
            }
            Section("Schon erledigt? Pro") {
                HStack { Label(purchases.hasPro ? "Pro ist aktiv" : "Pro freischalten", systemImage: purchases.hasPro ? "checkmark.seal.fill" : "sparkles"); Spacer(); if purchases.hasPro { Text("Aktiv").foregroundStyle(Brand.success) } }
                if !purchases.hasPro { Button("Pro ansehen") { showsPaywall = true } }
            }
            Section("Daten") {
                LabeledContent("Karten", value: "\(store.routines.count)"); LabeledContent("Bestätigungen", value: "\(store.history.count)")
                Button("Beispieldaten wiederherstellen", role: .destructive) { showsResetConfirmation = true }
            }
            Section("Wichtiger Hinweis") { Text("Die App dokumentiert deine Eingaben. Sie kann nicht prüfen, ob eine Tür tatsächlich verschlossen oder ein Gerät tatsächlich ausgeschaltet ist.").font(.footnote).foregroundStyle(Brand.secondaryInk) }
            Section("Hilfe & Rechtliches") {
                Link(destination: AppLinks.support) { Label("Support", systemImage: "questionmark.circle") }
                Link(destination: AppLinks.privacy) { Label("Datenschutz", systemImage: "hand.raised") }
                Link(destination: AppLinks.termsOfUse) { Label("Nutzungsbedingungen", systemImage: "doc.text") }
            }
            Section { LabeledContent("Version", value: appVersion) }
        }
        .navigationTitle("Einstellungen")
        .keyboardDoneToolbar()
        .alert("Alle eigenen Daten ersetzen?", isPresented: $showsResetConfirmation) {
            Button("Abbrechen", role: .cancel) {}; Button("Wiederherstellen", role: .destructive) { store.resetToSamples() }
        } message: { Text("Eigene Karten und der Verlauf werden gelöscht und durch die Beispielkarten ersetzt.") }
        .sheet(isPresented: $showsCloudShare) { if let data = store.snapshotData() { CloudSharingView(householdName: store.householdName, snapshotData: data) } }
        .sheet(isPresented: $showsPaywall) { PaywallView().environmentObject(purchases) }
        .onReceive(NotificationCenter.default.publisher(for: .cloudShareAccepted)) { _ in Task { await store.setICloudEnabled(true); await store.syncCloud() } }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–"
    }
}

private struct CloudSharingView: UIViewControllerRepresentable {
    let householdName: String; let snapshotData: Data
    func makeUIViewController(context: Context) -> UICloudSharingController { CloudKitService.sharingController(householdName: householdName, localData: snapshotData) }
    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {}
}
