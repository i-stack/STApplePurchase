//
//  STApplePurchaseReceiptValidating.swift
//  STApplePurchase
//
//  Created by 寒江孤影 on 2026/11/3.
//

import Foundation

public protocol STApplePurchaseReceiptValidating {
    /// - Parameters:
    ///   - transaction: 本地已通过 StoreKit 2 校验的交易快照。
    ///   - signedPayload: 交易对应的签名原文（`Transaction.jwsRepresentation`），
    /// - Returns: 后端校验是否通过。
    func validate(transaction: STApplePurchaseTransaction, signedPayload: String) async throws -> Bool
}
