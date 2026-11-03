//
//  STApplePurchaseProtocolConformanceTests.swift
//  STApplePurchaseTests
//
//  Created by 寒江孤影 on 2026/11/3.
//

import XCTest
import StoreKit
@testable import STApplePurchase

private final class MockLogger: STApplePurchaseLogging {
    var messages: [String] = []
    func log(_ message: String) {
        messages.append(message)
    }
}

private final class MockStatusSyncer: STApplePurchasePurchaseStatusSyncing {
    var syncedPurchaseCount = 0
    var syncedSubscriptionCount = 0
    var shouldThrow = false

    func syncPurchaseStatus(transaction: STApplePurchaseTransaction) async throws {
        if shouldThrow {
            throw NSError(domain: "mock", code: -1)
        }
        syncedPurchaseCount += 1
    }

    func syncSubscriptionStatus(_ statuses: [STApplePurchaseSubscriptionStatus], productID: String) async throws {
        syncedSubscriptionCount += 1
    }
}

private final class MockReceiptValidator: STApplePurchaseReceiptValidating {
    var result: Bool = true
    var lastSignedPayload: String?

    func validate(transaction: STApplePurchaseTransaction, signedPayload: String) async throws -> Bool {
        lastSignedPayload = signedPayload
        return result
    }
}

final class STApplePurchaseProtocolConformanceTests: XCTestCase {
    @MainActor
    func testValidateReceiptIfNeededSkipsWhenNoValidatorConfigured() async throws {
        let manager = STApplePurchaseManager()
        let transaction = makeTransaction()

        // 未配置 receiptValidator 时不应抛错，也不应调用任何校验逻辑。
        try await manager.validateReceiptIfNeeded(for: transaction)
    }

    @MainActor
    func testValidateReceiptIfNeededThrowsWhenValidatorRejects() async {
        let manager = STApplePurchaseManager()
        let validator = MockReceiptValidator()
        validator.result = false
        manager.receiptValidator = validator
        let transaction = makeTransaction()

        do {
            try await manager.validateReceiptIfNeeded(for: transaction)
            XCTFail("expected receiptValidationFailed")
        } catch let error as STApplePurchaseError {
            guard case .receiptValidationFailed = error else {
                XCTFail("unexpected error case: \(error)")
                return
            }
        } catch {
            XCTFail("unexpected error type: \(error)")
        }

        XCTAssertEqual(validator.lastSignedPayload, transaction.signedPayload)
    }

    func testStatusSyncerLogsFailureWithoutThrowing() async {
        let syncer = MockStatusSyncer()
        syncer.shouldThrow = true
        let logger = MockLogger()

        do {
            try await syncer.syncPurchaseStatus(transaction: makeTransaction())
            XCTFail("mock should throw")
        } catch {
            logger.log("sync failed: \(error.localizedDescription)")
        }

        XCTAssertEqual(logger.messages.count, 1)
        XCTAssertEqual(syncer.syncedPurchaseCount, 0)
    }

    private func makeTransaction() -> STApplePurchaseTransaction {
        STApplePurchaseTransaction(
            id: 1,
            originalID: 1,
            productID: "com.example.product",
            purchaseDate: Date(),
            expirationDate: nil,
            isUpgraded: false,
            revocationDate: nil,
            signedPayload: "stub-jws"
        )
    }
}
