import Foundation
@_exported import Combine
public enum ProviderProbe { public static var calls:[String]=[] }
public enum VerificationResult<T> { case verified(T), unverified }
public struct Transaction {
 public var productID:String=""; public var revocationDate:Date?=nil
 public static var updates:AsyncStream<VerificationResult<Transaction>> { ProviderProbe.calls.append("updates"); return AsyncStream { $0.finish() } }
 public static var currentEntitlements:AsyncStream<VerificationResult<Transaction>> { ProviderProbe.calls.append("entitlements"); return AsyncStream { $0.finish() } }
 public static var unfinished:AsyncStream<VerificationResult<Transaction>> { ProviderProbe.calls.append("unfinished"); return AsyncStream { $0.finish() } }
 public func finish() async { ProviderProbe.calls.append("finish") }
}
public struct Product {
 public init() {}
 public var price:Decimal { 0 }
 public enum PurchaseResult { case success(VerificationResult<Transaction>), pending, userCancelled }
 public static func products(for ids:[String]) async throws -> [Product] { ProviderProbe.calls.append("products"); return [Product()] }
 public func purchase() async throws -> PurchaseResult { ProviderProbe.calls.append("purchase"); return .userCancelled }
}
public enum AppStore { public static func sync() async throws { ProviderProbe.calls.append("sync") } }
