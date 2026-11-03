//
//  STApplePurchaseSubscriptionStatus.swift
//  STApplePurchase
//
//  Created by 寒江孤影 on 2026/11/3.
//

import StoreKit

/// `Product.SubscriptionInfo.Status` 的轻量包装。
public struct STApplePurchaseSubscriptionStatus: Sendable {
    public let state: Product.SubscriptionInfo.RenewalState
    public let willAutoRenew: Bool
    public let renewalDate: Date?
    public let expirationReason: Product.SubscriptionInfo.RenewalInfo.ExpirationReason?

    public init(
        state: Product.SubscriptionInfo.RenewalState,
        willAutoRenew: Bool,
        renewalDate: Date?,
        expirationReason: Product.SubscriptionInfo.RenewalInfo.ExpirationReason?
    ) {
        self.state = state
        self.willAutoRenew = willAutoRenew
        self.renewalDate = renewalDate
        self.expirationReason = expirationReason
    }
}
