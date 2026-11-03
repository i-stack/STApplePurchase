//
//  STApplePurchaseProduct.swift
//  STApplePurchase
//
//  Created by 寒江孤影 on 2026/11/3.
//

import StoreKit

/// StoreKit.Product 的轻量包装，向宿主暴露展示所需的基础信息，
/// 同时保留底层 `Product` 以便需要更多细节时直接访问。
public struct STApplePurchaseProduct: Identifiable, Sendable {
    public let id: String
    public let displayName: String
    public let displayPrice: String
    public let description: String
    public let underlyingProduct: Product

    public init(product: Product) {
        self.id = product.id
        self.displayName = product.displayName
        self.displayPrice = product.displayPrice
        self.description = product.description
        self.underlyingProduct = product
    }
}
