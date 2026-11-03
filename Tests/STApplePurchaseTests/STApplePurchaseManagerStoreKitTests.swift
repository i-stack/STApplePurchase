//
//  STIAPManagerStoreKitTests.swift
//  STApplePurchaseTests
//
//  Created by 寒江孤影 on 2026/11/3.
//
//  用 StoreKitTest 本地模拟商店跑通 STIAPManager 的核心购买流程，
//  不联网、不依赖真实 App Store Connect 商品配置。
//  配置来自 Resources/STApplePurchaseTests.storekit：
//    - 消耗型商品 com.stapplepurchase.example.coins_small
//    - 自动续订订阅 com.stapplepurchase.example.pro_monthly（订阅组 id 见该文件）

import XCTest
import StoreKit
import StoreKitTest
@testable import STApplePurchase

final class STIAPManagerStoreKitTests: XCTestCase {
    private var session: SKTestSession!
    private var manager: STIAPManager!

    private static let consumableProductID = "com.stapplepurchase.example.coins_small"
    private static let subscriptionProductID = "com.stapplepurchase.example.pro_monthly"
    private static let subscriptionGroupID = "A1000000-0000-0000-0000-000000000003"

    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        guard let url = Bundle.module.url(forResource: "STApplePurchaseTests", withExtension: "storekit") else {
            throw XCTSkip("找不到 STApplePurchaseTests.storekit，跳过 StoreKitTest 集成测试")
        }
        session = try SKTestSession(contentsOf: url)
        session.disableDialogs = true
        session.clearTransactions()
        manager = STIAPManager()
    }

    @MainActor
    override func tearDown() async throws {
        session.clearTransactions()
        manager = nil
        session = nil
        try await super.tearDown()
    }

    @MainActor
    func testLoadProductsReturnsConfiguredProducts() async throws {
        let products = try await manager.loadProducts(productIDs: [Self.consumableProductID, Self.subscriptionProductID])

        XCTAssertEqual(products.count, 2)
        XCTAssertTrue(products.contains { $0.id == Self.consumableProductID })
        XCTAssertTrue(products.contains { $0.id == Self.subscriptionProductID })
    }

    @MainActor
    func testPurchaseConsumableProductSucceedsAndIsVerified() async throws {
        let products = try await manager.loadProducts(productIDs: [Self.consumableProductID])
        guard let product = products.first else {
            XCTFail("未能从 StoreKitTest 加载到消耗型商品")
            return
        }

        let result = try await manager.purchase(product)

        guard case .success(let transaction) = result else {
            XCTFail("预期购买成功，实际为 \(result)")
            return
        }
        XCTAssertEqual(transaction.productID, Self.consumableProductID)
        XCTAssertFalse(transaction.signedPayload.isEmpty)
    }

    @MainActor
    func testRestorePurchasesReturnsPreviouslyPurchasedEntitlement() async throws {
        let products = try await manager.loadProducts(productIDs: [Self.subscriptionProductID])
        guard let product = products.first else {
            XCTFail("未能从 StoreKitTest 加载到订阅商品")
            return
        }

        _ = try await manager.purchase(product)

        let restored = try await manager.restorePurchases()
        XCTAssertTrue(restored.contains { $0.productID == Self.subscriptionProductID })
    }

    @MainActor
    func testSubscriptionStatusReflectsActiveSubscription() async throws {
        let products = try await manager.loadProducts(productIDs: [Self.subscriptionProductID])
        guard let product = products.first else {
            XCTFail("未能从 StoreKitTest 加载到订阅商品")
            return
        }

        _ = try await manager.purchase(product)

        let statuses = try await manager.subscriptionStatus(for: Self.subscriptionGroupID)
        XCTAssertEqual(statuses.count, 1)
        XCTAssertEqual(statuses.first?.state, .subscribed)
    }

    @MainActor
    func testStatusSyncerIsCalledAfterVerifiedPurchase() async throws {
        let syncer = RecordingStatusSyncer()
        manager.statusSyncer = syncer

        let products = try await manager.loadProducts(productIDs: [Self.consumableProductID])
        guard let product = products.first else {
            XCTFail("未能从 StoreKitTest 加载到消耗型商品")
            return
        }

        _ = try await manager.purchase(product)

        XCTAssertEqual(syncer.syncedPurchaseCount, 1)
    }
}

private final class RecordingStatusSyncer: STIAPPurchaseStatusSyncing {
    private(set) var syncedPurchaseCount = 0

    func syncPurchaseStatus(transaction: STIAPTransaction) async throws {
        syncedPurchaseCount += 1
    }

    func syncSubscriptionStatus(_ statuses: [STIAPSubscriptionStatus], productID: String) async throws {}
}
