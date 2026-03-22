//
//  MessageParserFormattingTests.swift
//  SpendSenseTests
//

import Testing
@testable import SpendSense

struct BankSMSCase: Sendable {
    let message: String
    let expectedAmount: Double
}

// File-level so @Test(arguments:) expansion is not blocked by MainActor-isolated `Self`.
private let messageParserBankSMSCases: [BankSMSCase] = [
    BankSMSCase(
        message: "HDFC Bank: INR 1,250.00 debited from A/c XX9012 on 12-Mar-26 towards SWIGGY BANGALORE. Avl Bal Rs. 42,300.50",
        expectedAmount: 1_250
    ),
    BankSMSCase(
        message: "ICICI: Rs. 499.00 spent on ZOMATO LTD via UPI-1234567890@ybl. Ref 9081726354",
        expectedAmount: 499
    ),
    BankSMSCase(
        message: "Axis Alert: Your a/c is debited for Rs 2,345.50 towards OLA RIDE on 11/03/26. Not you? Call 1800.",
        expectedAmount: 2_345.50
    ),
    BankSMSCase(
        message: "SBI: Payment of ₹890.00 charged to card ending 4411 at BLINKIT QUICK COMMERCE.",
        expectedAmount: 890
    ),
    BankSMSCase(
        message: "Kotak: Transaction of Rs. 12,999.00 — purchase at AMAZON PAY on 10 Mar 2026.",
        expectedAmount: 12_999
    ),
    BankSMSCase(
        message: "HDFC UPI: Rs.175 debited to NETFLIX ENTERTAINMENT. Bal Rs 21000. Ref UPI/77/abc",
        expectedAmount: 175
    ),
    BankSMSCase(
        message: "ICICI: INR 199.00 debited for SPOTIFY INDIA subscription on 09-Mar-2026.",
        expectedAmount: 199
    ),
    BankSMSCase(
        message: "Axis: Payment of Rs 1,050.00 towards BESCOM electricity bill via UPI.",
        expectedAmount: 1_050
    ),
    BankSMSCase(
        message: "HDFC BANK Credit Card XX5678: INR 2,499.00 charged at FLIPKART on 08-Mar-26. Not you? Call 1800.",
        expectedAmount: 2_499
    ),
    BankSMSCase(
        message: "SBI: Rs. 312.50 debited from A/c XX1234 for UBER INDIA trip via UPI. Ref 9988776655",
        expectedAmount: 312.50
    )
]

@Suite("MessageParser bank SMS formats")
struct MessageParserFormattingTests {

    @Test(arguments: messageParserBankSMSCases)
    func parsesExpectedAmount(case sample: BankSMSCase) {
        let parser = MessageParser()
        let tx = parser.parseMessage(sample.message)
        #expect(tx != nil)
        guard let tx else { return }
        #expect(abs(tx.amount - sample.expectedAmount) < 0.02)
        #expect(tx.rawMessageText.isEmpty == false)
    }
}
