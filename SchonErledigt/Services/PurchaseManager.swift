import Foundation
import StoreKit

@MainActor final class PurchaseManager: ObservableObject {
    static let yearlyID = "com.kamilunavo.schon-erledigt.pro.yearly"
    static let lifetimeID = "com.kamilunavo.schon-erledigt.pro.lifetime"
    @Published private(set) var products: [Product] = []
    @Published private(set) var hasPro = false
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                if case .verified(let transaction) = update { await transaction.finish(); await self?.refreshEntitlements() }
            }
        }
        Task { await load() }
    }
    deinit { updatesTask?.cancel() }

    func load() async {
        isLoading = true; defer { isLoading = false }
        do { products = try await Product.products(for: [Self.yearlyID, Self.lifetimeID]).sorted { $0.price < $1.price }; await refreshEntitlements() }
        catch { errorMessage = error.localizedDescription }
    }
    func purchase(_ product: Product) async {
        do {
            if case .success(let verification) = try await product.purchase(), case .verified(let transaction) = verification {
                await transaction.finish(); await refreshEntitlements()
            }
        } catch { errorMessage = error.localizedDescription }
    }
    func restore() async {
        do { try await StoreKit.AppStore.sync(); await refreshEntitlements() }
        catch { errorMessage = error.localizedDescription }
    }
    private func refreshEntitlements() async {
        var pro = false
        for await entitlement in Transaction.currentEntitlements {
            guard case .verified(let transaction) = entitlement else { continue }
            if [Self.yearlyID, Self.lifetimeID].contains(transaction.productID), transaction.revocationDate == nil { pro = true }
        }
        hasPro = pro
    }
}
