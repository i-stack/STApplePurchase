//
//  STApplePurchaseTransactionListener.swift
//  STApplePurchase
//
//  Created by 寒江孤影 on 2026/11/3.
//

import StoreKit

/// 校验通过后把结果转发给调用方提供的回调。
final class STApplePurchaseTransactionListener {
    
    private var updatesTask: Task<Void, Never>?

    func start(onVerifiedTransaction: @escaping @Sendable (STApplePurchaseTransaction, Transaction) async -> Void) {
        self.stop()
        self.updatesTask = Task.detached {
            for await update in Transaction.updates {
                guard let (transaction, jwsRepresentation) = try? STApplePurchaseVerifier.checkVerified(update) else {
                    continue
                }
                let snapshot = STApplePurchaseTransaction(transaction: transaction, signedPayload: jwsRepresentation)
                await onVerifiedTransaction(snapshot, transaction)
                await transaction.finish()
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
