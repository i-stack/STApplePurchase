//
//  STApplePurchasePurchaseStatusSyncing.swift
//  STApplePurchase
//
//  Created by 寒江孤影 on 2026/11/3.
//

import Foundation

public protocol STApplePurchasePurchaseStatusSyncing {
    /// 一次已校验通过的交易发生后调用（购买、恢复购买、交易更新监听均会触发）。
    func syncPurchaseStatus(transaction: STApplePurchaseTransaction) async throws

    /// 某个订阅组的最新状态发生查询/变化后调用。
    func syncSubscriptionStatus(_ statuses: [STApplePurchaseSubscriptionStatus], productID: String) async throws
}
