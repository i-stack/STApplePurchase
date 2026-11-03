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
/// 购买与交易监听路径把「后端收据校验（`receiptValidator`，若已配置）→ 本地状态同步
/// （`statusSyncer.syncPurchaseStatus`，若已配置）→ `finish()`」收拢成一个原子流程：
/// 任一步骤失败都不会调用 `finish()`，交易保留在 unfinished 队列里等待下次重试。
/// `startListeningForTransactionUpdates()` 启动时会先回放一遍 `Transaction.unfinished`，
/// 把上次未能完成交付的交易重新走一次该流程。
/// `restorePurchases()` 面向的是已经确权的历史交易，逐笔同步状态，但同步失败只记录
/// 日志、不影响恢复结果的返回（这些交易本身已经 finish 过，不存在“保留重试”的概念）。
@MainActor
public final class STApplePurchaseManager {
    
    public static let shared = STApplePurchaseManager()

    private let listener = STApplePurchaseTransactionListener()
    public private(set) var products: [STApplePurchaseProduct] = []

    public var logger: STApplePurchaseLogging?
    public var receiptValidator: STApplePurchaseReceiptValidating?
    public var statusSyncer: STApplePurchasePurchaseStatusSyncing?

    public init() {}

    public func startListeningForTransactionUpdates() {
        Task { [weak self] in
            await self?.recoverUnfinishedTransactions()
        }
        self.listener.start(
            onVerifiedTransaction: { [weak self] snapshot, transaction in
                guard let self else { return }
                do {
                    try await self.finalizeVerifiedTransaction(snapshot, transaction: transaction)
                } catch {
                    await self.logFinalizeFailure(transactionID: snapshot.id, error: error)
                }
            },
            onVerificationFailure: { [weak self] productID, transactionID, error in
                await self?.logVerificationFailure(productID: productID, transactionID: transactionID, error: error)
            }
        )
    }

    public func stopListeningForTransactionUpdates() {
        self.listener.stop()
    }

    /// 重放一遍尚未 `finish()` 的历史交易（例如上次校验/同步失败、或进程在 `finish()` 前被杀）。
    /// 已经在 `startListeningForTransactionUpdates()` 里自动调用一次；也可以在需要时手动重试。
    public func recoverUnfinishedTransactions() async {
        for await update in Transaction.unfinished {
            switch update {
            case .unverified(let unverifiedTransaction, let error):
                self.logger?.log("unfinished transaction \(unverifiedTransaction.id) (product \(unverifiedTransaction.productID)) verification failed: \(error)")
            case .verified:
                guard let (transaction, jwsRepresentation) = try? STApplePurchaseVerifier.checkVerified(update) else {
                    continue
                }
                let snapshot = STApplePurchaseTransaction(transaction: transaction, signedPayload: jwsRepresentation)
                do {
                    try await finalizeVerifiedTransaction(snapshot, transaction: transaction)
                } catch {
                    self.logger?.log("unfinished transaction \(snapshot.id) retry failed, kept unfinished: \(error.localizedDescription)")
                }
            }
        }
    }

    public func loadProducts(productIDs: [String]) async throws -> [STApplePurchaseProduct] {
        do {
            let storeProducts = try await Product.products(for: productIDs)
            let mapped = storeProducts.map(STApplePurchaseProduct.init)
            self.products = mapped
            return mapped
        } catch {
            throw STApplePurchaseError.productLoadFailed(error)
        }
    }

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
            try await finalizeVerifiedTransaction(snapshot, transaction: transaction)
            return .success(snapshot)
        case .userCancelled:
            return .userCancelled
        case .pending:
            return .pending
        @unknown default:
            return .pending
        }
    }

    @discardableResult
    public func restorePurchases() async throws -> [STApplePurchaseTransaction] {
        do {
            try await AppStore.sync()
        } catch {
            throw STApplePurchaseError.restoreFailed(error)
        }
        let entitlements = await self.currentEntitlements()
        for entitlement in entitlements {
            await self.syncPurchaseStatusLoggingFailure(for: entitlement)
        }
        return entitlements
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

    public func validateReceiptIfNeeded(for transaction: STApplePurchaseTransaction) async throws {
        guard let receiptValidator else { return }
        let passed = try await receiptValidator.validate(transaction: transaction, signedPayload: transaction.signedPayload)
        if !passed {
            throw STApplePurchaseError.receiptValidationFailed("后端收据校验未通过")
        }
    }

    /// 把一笔已经通过本地签名校验的交易收拢成原子流程：后端收据校验 → 本地状态同步 → `finish()`。
    /// 任一步骤抛错都不会执行到 `finish()`，交易继续留在 unfinished 队列里等待重试。
    private func finalizeVerifiedTransaction(_ snapshot: STApplePurchaseTransaction, transaction: Transaction) async throws {
        try await validateReceiptIfNeeded(for: snapshot)
        if let statusSyncer {
            try await statusSyncer.syncPurchaseStatus(transaction: snapshot)
        }
        await transaction.finish()
    }

    /// 面向“已经确权、不存在保留重试概念”的历史交易（恢复购买）：同步失败只记录日志，不抛错。
    /// internal 而非 private，便于测试直接验证 manager 自身的日志记录行为。
    func syncPurchaseStatusLoggingFailure(for transaction: STApplePurchaseTransaction) async {
        guard let statusSyncer else { return }
        do {
            try await statusSyncer.syncPurchaseStatus(transaction: transaction)
        } catch {
            self.logger?.log("purchase status sync failed for transaction \(transaction.id): \(error.localizedDescription)")
        }
    }

    private func logFinalizeFailure(transactionID: UInt64, error: any Error) {
        self.logger?.log("transaction \(transactionID) finalize failed, kept unfinished for retry: \(error.localizedDescription)")
    }

    private func logVerificationFailure(productID: String, transactionID: UInt64, error: any Error) {
        self.logger?.log("transaction \(transactionID) (product \(productID)) verification failed: \(error)")
    }
}
