//
//  STApplePurchaseReceiptValidating.swift
//  STApplePurchase
//
//  Created by 寒江孤影 on 2026/11/3.
//

import Foundation

/// 宿主 App 实现此协议，把本地已通过 StoreKit 2 签名校验的交易，
/// 再发给自己的后端做收据校验。STApplePurchase 不关心具体网络请求的实现方式。
public protocol STApplePurchaseReceiptValidating {
    /// - Parameters:
    ///   - transaction: 本地已通过 StoreKit 2 校验的交易快照。
    ///   - signedPayload: 交易对应的签名原文（`Transaction.jwsRepresentation`），
    ///     用于宿主后端做二次校验。
    /// - Returns: 后端校验是否通过。
    func validate(transaction: STApplePurchaseTransaction, signedPayload: String) async throws -> Bool
}
