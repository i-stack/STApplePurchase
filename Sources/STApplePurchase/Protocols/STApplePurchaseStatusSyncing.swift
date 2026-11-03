//
//  STApplePurchasePurchaseStatusSyncing.swift
//  STApplePurchase
//
//  Created by 寒江孤影 on 2026/11/3.
//

import Foundation

/// 宿主 App 实现此协议，把本地购买/订阅状态同步给自己的后端。
/// STApplePurchase 不关心具体网络请求的实现方式。
public protocol STApplePurchasePurchaseStatusSyncing {
    /// 一次已校验通过的交易发生后调用（购买、恢复购买、交易更新监听均会触发）。
    func syncPurchaseStatus(transaction: STApplePurchaseTransaction) async throws

    /// 某个订阅组的最新状态发生查询/变化后调用。
    func syncSubscriptionStatus(_ statuses: [STApplePurchaseSubscriptionStatus], productID: String) async throws
}
