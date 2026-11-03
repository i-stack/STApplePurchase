//
//  STApplePurchaseTransaction.swift
//  STApplePurchase
//
//  Created by 寒江孤影 on 2026/11/3.
//

import StoreKit

/// 本地已通过 StoreKit 2 签名校验的交易快照。
public struct STApplePurchaseTransaction: Identifiable, Sendable {
    public let id: UInt64
    public let originalID: UInt64
    public let productID: String
    public let purchaseDate: Date
    public let expirationDate: Date?
    public let isUpgraded: Bool
    public let revocationDate: Date?
    /// 交易对应的签名原文，供宿主发给自有后端做二次校验。
    public let signedPayload: String

    /// - Parameters:
    ///   - transaction: 已通过本地签名校验的 `Transaction`。
    ///   - signedPayload: 对应的 `VerificationResult.jwsRepresentation`，
    ///     只能在校验那一刻从 `VerificationResult` 上取得，无法从 `Transaction` 反推。
    public init(transaction: Transaction, signedPayload: String) {
        self.id = transaction.id
        self.originalID = transaction.originalID
        self.productID = transaction.productID
        self.purchaseDate = transaction.purchaseDate
        self.expirationDate = transaction.expirationDate
        self.isUpgraded = transaction.isUpgraded
        self.revocationDate = transaction.revocationDate
        self.signedPayload = signedPayload
    }

    public init(
        id: UInt64,
        originalID: UInt64,
        productID: String,
        purchaseDate: Date,
        expirationDate: Date?,
        isUpgraded: Bool,
        revocationDate: Date?,
        signedPayload: String
    ) {
        self.id = id
        self.originalID = originalID
        self.productID = productID
        self.purchaseDate = purchaseDate
        self.expirationDate = expirationDate
        self.isUpgraded = isUpgraded
        self.revocationDate = revocationDate
        self.signedPayload = signedPayload
    }
}
