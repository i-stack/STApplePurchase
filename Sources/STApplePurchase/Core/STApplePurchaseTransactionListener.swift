//
//  STIAPTransactionListener.swift
//  STApplePurchase
//
//  Created by 寒江孤影 on 2026/11/3.
//

import StoreKit

/// 把 `Transaction.updates` 包成一个后台 `Task`，
/// 校验通过后把结果转发给调用方提供的回调。
final class STIAPTransactionListener {
    private var updatesTask: Task<Void, Never>?

    func start(onVerifiedTransaction: @escaping @Sendable (STIAPTransaction, Transaction) async -> Void) {
        stop()
        updatesTask = Task.detached {
            for await update in Transaction.updates {
                guard let (transaction, jwsRepresentation) = try? STIAPVerifier.checkVerified(update) else {
                    continue
                }
                let snapshot = STIAPTransaction(transaction: transaction, signedPayload: jwsRepresentation)
                await onVerifiedTransaction(snapshot, transaction)
                await transaction.finish()
            }
        }
    }

    func stop() {
        updatesTask?.cancel()
        updatesTask = nil
    }

    deinit {
        updatesTask?.cancel()
    }
}
