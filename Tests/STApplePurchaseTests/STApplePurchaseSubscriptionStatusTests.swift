//
//  STApplePurchaseSubscriptionStatusTests.swift
//  STApplePurchaseTests
//
//  Created by 寒江孤影 on 2026/11/3.
//

import XCTest
import StoreKit
@testable import STApplePurchase

final class STApplePurchaseSubscriptionStatusTests: XCTestCase {
    func testHoldsGivenValues() {
        let renewalDate = Date(timeIntervalSince1970: 1_700_000_000)
        let status = STApplePurchaseSubscriptionStatus(
            state: .subscribed,
            willAutoRenew: true,
            renewalDate: renewalDate,
            expirationReason: nil
        )

        XCTAssertEqual(status.state, .subscribed)
        XCTAssertTrue(status.willAutoRenew)
        XCTAssertEqual(status.renewalDate, renewalDate)
        XCTAssertNil(status.expirationReason)
    }

    func testExpiredWithReason() {
        let status = STApplePurchaseSubscriptionStatus(
            state: .expired,
            willAutoRenew: false,
            renewalDate: nil,
            expirationReason: .autoRenewDisabled
        )

        XCTAssertEqual(status.state, .expired)
        XCTAssertFalse(status.willAutoRenew)
        XCTAssertEqual(status.expirationReason, .autoRenewDisabled)
    }
}
