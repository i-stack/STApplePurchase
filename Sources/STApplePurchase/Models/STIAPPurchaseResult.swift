//
//  STIAPPurchaseResult.swift
//  STApplePurchase
//
//  Created by 寒江孤影 on 2026/11/3.
//

import Foundation

/// `STIAPManager.purchase(_:)` 的结果。
public enum STIAPPurchaseResult: Sendable {
    case success(STIAPTransaction)
    case userCancelled
    case pending
}
