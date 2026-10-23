import Foundation
import StoreKit
@main struct ProviderIsolationSmoke {
 @MainActor static func main() async {
  let store = PurchaseManager()
  try? await Task.sleep(nanoseconds: 30_000_000)
  await store.load()
  await store.purchase(Product())
  await store.restore()
  if ProcessInfo.processInfo.environment["EXPECT_PROVIDER_CALLS"] == "1" {
   precondition(!ProviderProbe.calls.isEmpty, "Normal/release startup must retain its store behavior")
   print("PASS: normal/release entry points retain provider behavior using only a synthetic provider")
   return
  }
  precondition(ProviderProbe.calls.isEmpty, "QA isolation called providers: \(ProviderProbe.calls)")
  precondition(!store.hasPro && !store.isLoading && store.products.isEmpty)
  print("PASS: actual PurchaseManager QA launch and all public provider entry points are isolated")
 }
}
