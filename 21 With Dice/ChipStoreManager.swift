//
//  ChipStoreManager.swift
//  21 With Dice
//

import StoreKit

class ChipStoreManager {

    static let shared = ChipStoreManager()

    struct ChipOffer {
        let productID: String
        let chips: Int
        let defaultPriceString: String
    }

    static let offers: [ChipOffer] = [
        ChipOffer(productID: "com.21withdice.chips200", chips: 200, defaultPriceString: "$0.99"),
        ChipOffer(productID: "com.21withdice.chips500", chips: 500, defaultPriceString: "$1.99")
    ]

    private var products: [String: Product] = [:]

    private init() {}

    func priceString(for productID: String) -> String {
        if let p = products[productID] { return p.displayPrice }
        return Self.offers.first(where: { $0.productID == productID })?.defaultPriceString ?? ""
    }

    func chipAmount(for productID: String) -> Int {
        Self.offers.first(where: { $0.productID == productID })?.chips ?? 0
    }

    var isAvailable: Bool {
        !products.isEmpty
    }

    func loadProducts() async {
        do {
            let ids = Self.offers.map { $0.productID }
            let fetched = try await Product.products(for: ids)
            for p in fetched { products[p.id] = p }
        } catch {
            print("StoreKit: Failed to load products: \(error)")
        }
    }

    func purchase(productID: String) async -> Bool {
        guard let product = products[productID] else { return false }
        let chips = chipAmount(for: productID)
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try verification.payloadValue
                await MainActor.run {
                    BettingManager.shared.bankroll += chips
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
