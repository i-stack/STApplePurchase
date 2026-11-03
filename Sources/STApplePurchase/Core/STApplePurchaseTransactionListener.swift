//
//  STApplePurchaseTransactionListener.swift
//  STApplePurchase
//
//  Created by 寒江孤影 on 2026/11/3.
//

import StoreKit

/// 校验通过后把结果转发给调用方提供的回调；是否 `finish()` 由回调方（调用方）决定，
/// 本类不做任何自动 finish，因为能不能 finish 取决于后端校验/本地同步是否成功。
/// 本地签名校验未通过的交易只上报 `onVerificationFailure`（携带 transaction/product
/// 标识与失败类别，不包含完整 JWS），不会让调用方拿到不可信的交易内容。
final class STApplePurchaseTransactionListener {
    
    private var updatesTask: Task<Void, Never>?

    func start(
        onVerifiedTransaction: @escaping @Sendable (STApplePurchaseTransaction, Transaction) async -> Void,
        onVerificationFailure: (@Sendable (String, UInt64, any Error) async -> Void)? = nil
    ) {
        self.stop()
        self.updatesTask = Task.detached {
            for await update in Transaction.updates {
                switch update {
                case .unverified(let unverifiedTransaction, let error):
                    await onVerificationFailure?(unverifiedTransaction.productID, unverifiedTransaction.id, error)
                case .verified:
                    guard let (transaction, jwsRepresentation) = try? STApplePurchaseVerifier.checkVerified(update) else {
                        continue
                    }
                    let snapshot = STApplePurchaseTransaction(transaction: transaction, signedPayload: jwsRepresentation)
                    await onVerifiedTransaction(snapshot, transaction)
                }
            }
        }
    }

    func stop() {
        self.updatesTask?.cancel()
        self.updatesTask = nil
    }

    deinit {
        self.updatesTask?.cancel()
    }
}
