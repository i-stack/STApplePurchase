//
//  STApplePurchasePurchaseResultTests.swift
//  STApplePurchaseTests
//
//  Created by 寒江孤影 on 2026/11/3.
//

import XCTest
@testable import STApplePurchase

final class STApplePurchasePurchaseResultTests: XCTestCase {
    private func makeTransaction(id: UInt64 = 1) -> STApplePurchaseTransaction {
        STApplePurchaseTransaction(
            id: id,
            originalID: id,
            productID: "com.example.product",
            purchaseDate: Date(),
            expirationDate: nil,
            isUpgraded: false,
            revocationDate: nil,
            signedPayload: "stub-jws"
        )
    }

    func testSuccessCaseCarriesTransaction() {
        let transaction = makeTransaction(id: 42)
        let result = STApplePurchasePurchaseResult.success(transaction)

        guard case .success(let carried) = result else {
            XCTFail("expected .success case")
            return
        }
        XCTAssertEqual(carried.id, transaction.id)
        XCTAssertEqual(carried.productID, transaction.productID)
    }

    func testUserCancelledCase() {
        let result = STApplePurchasePurchaseResult.userCancelled
        guard case .userCancelled = result else {
            XCTFail("expected .userCancelled case")
            return
        }
    }

    func testPendingCase() {
        let result = STApplePurchasePurchaseResult.pending
        guard case .pending = result else {
            XCTFail("expected .pending case")
            return
        }
    }
}
