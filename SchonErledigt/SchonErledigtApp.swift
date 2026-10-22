import CloudKit
import SwiftUI
import UIKit

@main struct SchonErledigtApp: App {
    @StateObject private var store = AppStore()
    @StateObject private var purchases = PurchaseManager()
    @StateObject private var sequences = SequenceStore()
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup { RootView().environmentObject(store).environmentObject(purchases).environmentObject(sequences).preferredColorScheme(.light) }
            .onChange(of: store.history) { _, _ in
                let now = Date.now
                sequences.observe(cards: SequenceCardAdapter.states(routines: store.routines, history: store.history, at: now), at: now)
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { store.reloadFromDiskIfNeeded(); store.refreshExpiredItems(); if store.iCloudEnabled { Task { await store.syncCloud() } } }
            }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, userDidAcceptCloudKitShareWith metadata: CKShare.Metadata) {
        Task { try? await CloudKitService.shared.accept(metadata: metadata); await MainActor.run { NotificationCenter.default.post(name: .cloudShareAccepted, object: nil) } }
    }
}
extension Notification.Name { static let cloudShareAccepted = Notification.Name("cloudShareAccepted") }
