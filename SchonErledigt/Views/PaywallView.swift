import StoreKit
import SwiftUI

struct PaywallView: View {
    @EnvironmentObject private var purchases: PurchaseManager
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    ZStack { Circle().fill(Brand.primary.opacity(0.12)).frame(width: 110, height: 110); Image(systemName: "checkmark.seal.fill").font(.system(size: 54)).foregroundStyle(Brand.primary) }
                    VStack(spacing: 8) { Text("Schon erledigt? Pro").font(.system(.largeTitle, design: .rounded, weight: .bold)); Text("Gemeinsam den Alltag im Blick behalten.").font(.title3).foregroundStyle(Brand.secondaryInk) }
                    VStack(alignment: .leading, spacing: 16) {
                        feature("Unbegrenzt viele Karten", "square.grid.2x2.fill"); feature("Gemeinsame iCloud-Haushalte", "person.2.fill")
                        feature("Fotobelege und vollständiger Verlauf", "camera.fill"); feature("Erinnerungen bei automatischer Rücksetzung", "bell.badge.fill")
                    }.padding(20).background(Brand.background, in: RoundedRectangle(cornerRadius: 22))
                    if purchases.products.isEmpty {
                        if purchases.isLoading { ProgressView("Angebote werden geladen …") } else { Text("Käufe sind auf diesem Gerät derzeit nicht verfügbar.").foregroundStyle(Brand.secondaryInk) }
                    } else {
                        ForEach(purchases.products) { product in
                            Button { Task { await purchases.purchase(product) } } label: {
                                HStack { VStack(alignment: .leading) { Text(product.displayName).font(.headline); Text(product.description).font(.caption).lineLimit(2) }; Spacer(); Text(product.displayPrice).font(.headline) }
                                    .padding(17).background(Brand.primary, in: RoundedRectangle(cornerRadius: 18)).foregroundStyle(.white)
                            }
                        }
                    }
                    Button("Käufe wiederherstellen") { Task { await purchases.restore() } }
                    if let message = purchases.errorMessage { Text(message).font(.footnote).foregroundStyle(.red).multilineTextAlignment(.center) }
                    Text("Abonnements verlängern sich automatisch, sofern sie nicht mindestens 24 Stunden vor Ablauf gekündigt werden. Verwaltung über die Apple-ID-Einstellungen.").font(.caption2).foregroundStyle(Brand.secondaryInk).multilineTextAlignment(.center)
                }.padding(20)
            }.toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Fertig") { dismiss() } } }
        }
    }
    private func feature(_ title: LocalizedStringKey, _ symbol: String) -> some View { Label(title, systemImage: symbol).font(.headline).foregroundStyle(Brand.ink) }
}
