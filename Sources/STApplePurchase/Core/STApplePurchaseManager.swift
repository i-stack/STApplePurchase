//
//  STIAPManager.swift
//  STApplePurchase
//
//  Created by 寒江孤影 on 2026/11/3.
//

import StoreKit

/// STApplePurchase 对外主入口：商品查询、购买、恢复购买、交易监听、订阅状态查询。
///
/// 本地签名校验（StoreKit 2 `VerificationResult`）始终是强制网关，未通过直接抛错。
/// `receiptValidator`（后端收据校验）不会被自动调用，是否需要在本地校验通过后
/// 再做一次后端校验，由宿主 App 自行决定何时调用 `validateReceiptIfNeeded(for:)`。
/// `statusSyncer`（购买状态同步）在每次本地校验成功的交易后自动调用一次，
/// 失败只记录日志、不影响主流程。
@MainActor
public final class STIAPManager {
    public static let shared = STIAPManager()

    public private(set) var products: [STIAPProduct] = []

    public var receiptValidator: STIAPReceiptValidating?
    public var statusSyncer: STIAPPurchaseStatusSyncing?
    public var logger: STIAPLogging?

    private let listener = STIAPTransactionListener()

    public init() {}

    // MARK: - Transaction listening

    public func startListeningForTransactionUpdates() {
        listener.start { [weak self] snapshot, _ in
            await self?.handleVerifiedTransaction(snapshot)
        }
    }

    public func stopListeningForTransactionUpdates() {
        listener.stop()
    }

    // MARK: - Products

    public func loadProducts(productIDs: [String]) async throws -> [STIAPProduct] {
        do {
            let storeProducts = try await Product.products(for: productIDs)
            let mapped = storeProducts.map(STIAPProduct.init)
            products = mapped
            return mapped
        } catch {
            throw STIAPError.productLoadFailed(error)
        }
    }

    // MARK: - Purchase

    public func purchase(_ product: STIAPProduct) async throws -> STIAPPurchaseResult {
        let result: Product.PurchaseResult
        do {
            result = try await product.underlyingProduct.purchase()
        } catch {
            throw STIAPError.purchaseFailed(error)
        }

        switch result {
        case .success(let verificationResult):
            let (transaction, jwsRepresentation) = try STIAPVerifier.checkVerified(verificationResult)
            let snapshot = STIAPTransaction(transaction: transaction, signedPayload: jwsRepresentation)
            await handleVerifiedTransaction(snapshot)
            await transaction.finish()
            return .success(snapshot)
        case .userCancelled:
            return .userCancelled
        case .pending:
            return .pending
        @unknown default:
            return .pending
        }
    }

    // MARK: - Restore

    @discardableResult
    public func restorePurchases() async throws -> [STIAPTransaction] {
        do {
            try await AppStore.sync()
        } catch {
            throw STIAPError.restoreFailed(error)
        }
        return await currentEntitlements()
    }

    public func currentEntitlements() async -> [STIAPTransaction] {
        var transactions: [STIAPTransaction] = []
        for await entitlement in Transaction.currentEntitlements {
            guard let (transaction, jwsRepresentation) = try? STIAPVerifier.checkVerified(entitlement) else {
                continue
            }
            transactions.append(STIAPTransaction(transaction: transaction, signedPayload: jwsRepresentation))
        }
        return transactions
    }

    // MARK: - Subscription status

    public func subscriptionStatus(for groupID: String) async throws -> [STIAPSubscriptionStatus] {
        let statuses: [Product.SubscriptionInfo.Status]
        do {
            statuses = try await Product.SubscriptionInfo.status(for: groupID)
        } catch {
            throw STIAPError.subscriptionStatusLoadFailed(error)
        }

        let mapped = statuses.map { status in
            let renewalInfo = try? status.renewalInfo.payloadValue
            // 下一次续订/到期时间取自最新交易的 expirationDate：
            // 自动续订开启时代表下次续订日，关闭时代表本周期到期日。
            let latestTransaction = try? status.transaction.payloadValue
            return STIAPSubscriptionStatus(
                state: status.state,
                willAutoRenew: renewalInfo?.willAutoRenew ?? false,
                renewalDate: latestTransaction?.expirationDate,
                expirationReason: renewalInfo?.expirationReason
            )
        }
        if let statusSyncer,
           let productID = try? statuses.first?.transaction.payloadValue.productID {
            try? await statusSyncer.syncSubscriptionStatus(mapped, productID: productID)
        }
        return mapped
    }

    // MARK: - Receipt validation (host-driven)

    public func validateReceiptIfNeeded(for transaction: STIAPTransaction) async throws {
        guard let receiptValidator else { return }
        let passed = try await receiptValidator.validate(transaction: transaction, signedPayload: transaction.signedPayload)
        if !passed {
            throw STIAPError.receiptValidationFailed("后端收据校验未通过")
        }
    }

    // MARK: - Private

    private func handleVerifiedTransaction(_ snapshot: STIAPTransaction) async {
        guard let statusSyncer else { return }
        do {
            try await statusSyncer.syncPurchaseStatus(transaction: snapshot)
        } catch {
            logger?.log("purchase status sync failed for transaction \(snapshot.id): \(error.localizedDescription)")
        }
    }
}
