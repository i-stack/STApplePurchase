//
//  STIAPVerifier.swift
//  STApplePurchase
//
//  Created by 寒江孤影 on 2026/11/3.
//

import StoreKit

/// 把 StoreKit 2 的 `VerificationResult<Transaction>` 转成强类型结果，
/// 未通过本地签名校验时统一抛出 `STIAPError.verificationFailed`。
///
/// `jwsRepresentation` 只在 `SignedType == Transaction` 的条件扩展里提供，
/// 所以这里不对 `T` 泛型化，专门只处理 `Transaction`。
enum STIAPVerifier {
    static func checkVerified(_ result: VerificationResult<Transaction>) throws -> (value: Transaction, jwsRepresentation: String) {
        switch result {
        case .unverified:
            throw STIAPError.verificationFailed
        case .verified(let safe):
            return (safe, result.jwsRepresentation)
        }
    }
}
