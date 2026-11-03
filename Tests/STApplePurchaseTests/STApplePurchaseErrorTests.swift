//
//  STApplePurchaseErrorTests.swift
//  STApplePurchaseTests
//
//  Created by 寒江孤影 on 2026/11/3.
//

import XCTest
@testable import STApplePurchase

final class STApplePurchaseErrorTests: XCTestCase {
    func testAllCasesHaveNonEmptyDescription() {
        let underlying = NSError(domain: "test", code: -1, userInfo: [NSLocalizedDescriptionKey: "underlying"])
        let cases: [STApplePurchaseError] = [
            .productNotFound,
            .productLoadFailed(underlying),
            .subscriptionStatusLoadFailed(underlying),
            .purchaseFailed(underlying),
            .verificationFailed,
            .userCancelled,
            .purchasePending,
            .restoreFailed(underlying),
            .receiptValidationFailed("reason")
        ]

        for error in cases {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
        }
    }

    func testReceiptValidationFailedIncludesReason() {
        let error = STApplePurchaseError.receiptValidationFailed("签名不匹配")
        XCTAssertTrue(error.errorDescription?.contains("签名不匹配") ?? false)
    }
}
