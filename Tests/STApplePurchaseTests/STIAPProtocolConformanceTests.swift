//
//  STIAPProtocolConformanceTests.swift
//  STApplePurchaseTests
//
//  Created by 寒江孤影 on 2026/11/3.
//

import XCTest
import StoreKit
@testable import STApplePurchase

private final class MockLogger: STIAPLogging {
    var messages: [String] = []
    func log(_ message: String) {
        messages.append(message)
    }
}

private final class MockStatusSyncer: STIAPPurchaseStatusSyncing {
    var syncedPurchaseCount = 0
    var syncedSubscriptionCount = 0
    var shouldThrow = false

    func syncPurchaseStatus(transaction: STIAPTransaction) async throws {
        if shouldThrow {
            throw NSError(domain: "mock", code: -1)
        }
        syncedPurchaseCount += 1
    }

    func syncSubscriptionStatus(_ statuses: [STIAPSubscriptionStatus], productID: String) async throws {
        syncedSubscriptionCount += 1
    }
}

private final class MockReceiptValidator: STIAPReceiptValidating {
    var result: Bool = true
    var lastSignedPayload: String?

    func validate(transaction: STIAPTransaction, signedPayload: String) async throws -> Bool {
        lastSignedPayload = signedPayload
        return result
    }
}

final class STIAPProtocolConformanceTests: XCTestCase {
    @MainActor
    func testValidateReceiptIfNeededSkipsWhenNoValidatorConfigured() async throws {
        let manager = STIAPManager()
        let transaction = makeTransaction()

        // 未配置 receiptValidator 时不应抛错，也不应调用任何校验逻辑。
        try await manager.validateReceiptIfNeeded(for: transaction)
    }

    @MainActor
    func testValidateReceiptIfNeededThrowsWhenValidatorRejects() async {
        let manager = STIAPManager()
        let validator = MockReceiptValidator()
        validator.result = false
        manager.receiptValidator = validator
        let transaction = makeTransaction()

        do {
            try await manager.validateReceiptIfNeeded(for: transaction)
            XCTFail("expected receiptValidationFailed")
        } catch let error as STIAPError {
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

    private func makeTransaction() -> STIAPTransaction {
        STIAPTransaction(
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
