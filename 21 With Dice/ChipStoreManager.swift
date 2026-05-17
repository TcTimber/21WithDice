//
//  ChipStoreManager.swift
//  21 With Dice
//

import StoreKit

class ChipStoreManager {

    static let shared = ChipStoreManager()
    static let chips1000ID = "com.21withdice.chips1000"

    private var product: Product?

    private init() {}

    var priceString: String {
        product?.displayPrice ?? "$1.99"
    }

    var isAvailable: Bool {
        product != nil
    }

    func loadProducts() async {
        do {
            let products = try await Product.products(for: [Self.chips1000ID])
            product = products.first
        } catch {
            print("StoreKit: Failed to load products: \(error)")
        }
    }

    func purchase() async -> Bool {
        guard let product else { return false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try verification.payloadValue
                await MainActor.run {
                    BettingManager.shared.bankroll += 1000
                }
                await transaction.finish()
                return true
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            print("StoreKit: Purchase failed: \(error)")
            return false
        }
    }
}
