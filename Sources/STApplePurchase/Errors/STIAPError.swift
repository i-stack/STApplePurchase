//
//  STIAPError.swift
//  STApplePurchase
//
//  Created by 寒江孤影 on 2026/11/3.
//

import Foundation

/// STApplePurchase 内购流程中的统一错误类型。
public enum STIAPError: Error, LocalizedError {
    /// 请求的商品 ID 未在 App Store 中查到对应商品。
    case productNotFound
    /// 商品列表加载失败。
    case productLoadFailed(Error)
    /// 订阅状态查询失败。
    case subscriptionStatusLoadFailed(Error)
    /// 购买请求失败。
    case purchaseFailed(Error)
    /// 本地交易签名校验失败（StoreKit 2 `VerificationResult` 未通过）。
    case verificationFailed
    /// 用户主动取消了购买流程。
    case userCancelled
    /// 购买处于等待家长同意等待处理状态（Ask to Buy 等）。
    case purchasePending
    /// 恢复购买失败。
    case restoreFailed(Error)
    /// 宿主后端收据校验未通过。
    case receiptValidationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .productNotFound:
            return "未找到对应的内购商品"
        case .productLoadFailed(let underlying):
            return "商品信息加载失败：\(underlying.localizedDescription)"
        case .subscriptionStatusLoadFailed(let underlying):
            return "订阅状态查询失败：\(underlying.localizedDescription)"
        case .purchaseFailed(let underlying):
            return "购买失败：\(underlying.localizedDescription)"
        case .verificationFailed:
            return "交易签名校验失败"
        case .userCancelled:
            return "用户已取消购买"
        case .purchasePending:
            return "购买正在等待处理"
        case .restoreFailed(let underlying):
            return "恢复购买失败：\(underlying.localizedDescription)"
        case .receiptValidationFailed(let reason):
            return "收据校验未通过：\(reason)"
        }
    }
}
