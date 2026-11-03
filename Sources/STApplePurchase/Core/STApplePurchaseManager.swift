//
//  STApplePurchaseManager.swift
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
public final class STApplePurchaseManager {
    public static let shared = STApplePurchaseManager()

    public private(set) var products: [STApplePurchaseProduct] = []

    public var receiptValidator: STApplePurchaseReceiptValidating?
    public var statusSyncer: STApplePurchasePurchaseStatusSyncing?
    public var logger: STApplePurchaseLogging?

    private let listener = STApplePurchaseTransactionListener()

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

    public func loadProducts(productIDs: [String]) async throws -> [STApplePurchaseProduct] {
        do {
            let storeProducts = try await Product.products(for: productIDs)
            let mapped = storeProducts.map(STApplePurchaseProduct.init)
            products = mapped
            return mapped
        } catch {
            throw STApplePurchaseError.productLoadFailed(error)
        }
    }

    // MARK: - Purchase

    public func purchase(_ product: STApplePurchaseProduct) async throws -> STApplePurchasePurchaseResult {
        let result: Product.PurchaseResult
        do {
            result = try await product.underlyingProduct.purchase()
        } catch {
            throw STApplePurchaseError.purchaseFailed(error)
        }

        switch result {
        case .success(let verificationResult):
            let (transaction, jwsRepresentation) = try STApplePurchaseVerifier.checkVerified(verificationResult)
            let snapshot = STApplePurchaseTransaction(transaction: transaction, signedPayload: jwsRepresentation)
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
    public func restorePurchases() async throws -> [STApplePurchaseTransaction] {
        do {
            try await AppStore.sync()
        } catch {
            throw STApplePurchaseError.restoreFailed(error)
        }
        return await currentEntitlements()
    }

    public func currentEntitlements() async -> [STApplePurchaseTransaction] {
        var transactions: [STApplePurchaseTransaction] = []
        for await entitlement in Transaction.currentEntitlements {
            guard let (transaction, jwsRepresentation) = try? STApplePurchaseVerifier.checkVerified(entitlement) else {
                continue
            }
            transactions.append(STApplePurchaseTransaction(transaction: transaction, signedPayload: jwsRepresentation))
        }
        return transactions
    }

    // MARK: - Subscription status

    public func subscriptionStatus(for groupID: String) async throws -> [STApplePurchaseSubscriptionStatus] {
        let statuses: [Product.SubscriptionInfo.Status]
        do {
            statuses = try await Product.SubscriptionInfo.status(for: groupID)
        } catch {
            throw STApplePurchaseError.subscriptionStatusLoadFailed(error)
        }

        let mapped = statuses.map { status in
            let renewalInfo = try? status.renewalInfo.payloadValue
            // 下一次续订/到期时间取自最新交易的 expirationDate：
            // 自动续订开启时代表下次续订日，关闭时代表本周期到期日。
            let latestTransaction = try? status.transaction.payloadValue
            return STApplePurchaseSubscriptionStatus(
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

    public func validateReceiptIfNeeded(for transaction: STApplePurchaseTransaction) async throws {
        guard let receiptValidator else { return }
        let passed = try await receiptValidator.validate(transaction: transaction, signedPayload: transaction.signedPayload)
        if !passed {
            throw STApplePurchaseError.receiptValidationFailed("后端收据校验未通过")
        }
    }

    // MARK: - Private

    private func handleVerifiedTransaction(_ snapshot: STApplePurchaseTransaction) async {
        guard let statusSyncer else { return }
        do {
            try await statusSyncer.syncPurchaseStatus(transaction: snapshot)
        } catch {
            logger?.log("purchase status sync failed for transaction \(snapshot.id): \(error.localizedDescription)")
        }
    }
}
