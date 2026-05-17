//
//  BettingManager.swift
//  21 With Dice
//

import Foundation

class BettingManager {

    static let shared = BettingManager()

    private let bankrollKey = "playerBankroll"
    private let bettingEnabledKey = "bettingEnabled"
    private let lastReloadDateKey = "lastFreeReloadDate"

    var bankroll: Int {
        get { UserDefaults.standard.integer(forKey: bankrollKey) }
        set { UserDefaults.standard.set(newValue, forKey: bankrollKey) }
    }

    var bettingEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: bettingEnabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: bettingEnabledKey) }
    }

    private(set) var betChips: [Int] = []
    private(set) var lastBetChips: [Int] = []
    private(set) var lastWinnings: Int = 0
    private var lastReloadDate: Date? {
        get { UserDefaults.standard.object(forKey: lastReloadDateKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: lastReloadDateKey) }
    }

    var currentBet: Int { betChips.reduce(0, +) }
    var hasBet: Bool { !betChips.isEmpty }
    var isBroke: Bool { bankroll <= 0 && betChips.isEmpty }

    private init() {
        if UserDefaults.standard.object(forKey: bankrollKey) == nil {
            bankroll = 200
        }
    }

    @discardableResult
    func addChip(_ denomination: Int) -> Bool {
        guard denomination <= bankroll else { return false }
        betChips.append(denomination)
        bankroll -= denomination
        return true
    }

    @discardableResult
    func removeLastChip() -> Int? {
        guard let chip = betChips.popLast() else { return nil }
        bankroll += chip
        return chip
    }

    func clearBet() {
        bankroll += currentBet
        betChips.removeAll()
    }

    func processWin() -> Int {
        let profit = currentBet
        lastBetChips = betChips
        lastWinnings = currentBet * 2
        bankroll += currentBet * 2
        betChips.removeAll()
        return profit
    }

    func processThreeSixesWin() -> Int {
        let payout = currentBet + 200
        lastBetChips = betChips
        lastWinnings = payout
        bankroll += payout
        betChips.removeAll()
        return payout
    }

    func processLoss() -> Int {
        let lost = currentBet
        lastBetChips = betChips
        lastWinnings = 0
        betChips.removeAll()
        return lost
    }

    func canReload() -> Bool {
        guard isBroke else { return false }
        guard let last = lastReloadDate else { return true }
        return !Calendar.current.isDateInToday(last)
    }

    func reload() {
        bankroll = 200
        lastReloadDate = Date()
    }

    static func chipBreakdown(for amount: Int) -> [Int] {
        var remaining = amount
        var chips: [Int] = []
        for denom in [100, 25, 5] {
            while remaining >= denom {
                chips.append(denom)
                remaining -= denom
            }
        }
        return chips
    }
}
