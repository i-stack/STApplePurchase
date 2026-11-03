//
//  STApplePurchasePurchaseResult.swift
//  STApplePurchase
//
//  Created by 寒江孤影 on 2026/11/3.
//

import Foundation

/// `STApplePurchaseManager.purchase(_:)` 的结果。
public enum STApplePurchasePurchaseResult: Sendable {
    case success(STApplePurchaseTransaction)
    case userCancelled
    case pending
}
