//
//  STApplePurchaseTransactionTests.swift
//  STApplePurchaseTests
//
//  Created by 寒江孤影 on 2026/11/3.
//

import XCTest
@testable import STApplePurchase

final class STApplePurchaseTransactionTests: XCTestCase {
    func testMemberwiseInitPopulatesAllFields() {
        let purchaseDate = Date(timeIntervalSince1970: 1_700_000_000)
        let expirationDate = Date(timeIntervalSince1970: 1_705_000_000)
        let revocationDate = Date(timeIntervalSince1970: 1_702_000_000)

        let transaction = STApplePurchaseTransaction(
            id: 10,
            originalID: 9,
            productID: "com.example.pro_monthly",
            purchaseDate: purchaseDate,
            expirationDate: expirationDate,
            isUpgraded: true,
            revocationDate: revocationDate,
            signedPayload: "jws-stub"
        )

        XCTAssertEqual(transaction.id, 10)
        XCTAssertEqual(transaction.originalID, 9)
        XCTAssertEqual(transaction.productID, "com.example.pro_monthly")
        XCTAssertEqual(transaction.purchaseDate, purchaseDate)
        XCTAssertEqual(transaction.expirationDate, expirationDate)
        XCTAssertTrue(transaction.isUpgraded)
        XCTAssertEqual(transaction.revocationDate, revocationDate)
        XCTAssertEqual(transaction.signedPayload, "jws-stub")
    }

    func testIdentifiableIDMatchesTransactionID() {
        let transaction = STApplePurchaseTransaction(
            id: 77,
            originalID: 77,
            productID: "com.example.coins_small",
            purchaseDate: Date(),
            expirationDate: nil,
            isUpgraded: false,
            revocationDate: nil,
            signedPayload: "jws-stub"
        )

        XCTAssertEqual(transaction.id, UInt64(77))
    }
}
