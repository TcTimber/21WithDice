//
//  Probability.swift
//  21 With Dice
//

import Foundation

enum Probability {

    static let oneDieWeights: [Int: Int] =
        [1:1, 2:1, 3:1, 4:1, 5:1, 6:1]

    static let twoDiceWeights: [Int: Int] =
        [2:1, 3:2, 4:3, 5:4, 6:5, 7:6, 8:5, 9:4, 10:3, 11:2, 12:1]

    static let threeDiceWeights: [Int: Int] =
        [3:1, 4:3, 5:6, 6:10, 7:15, 8:21, 9:25, 10:27,
         11:27, 12:25, 13:21, 14:15, 15:10, 16:6, 17:3, 18:1]

    static func weights(forDice diceCount: Int) -> [Int: Int] {
        switch diceCount {
        case 1: return oneDieWeights
        case 2: return twoDiceWeights
        case 3: return threeDiceWeights
        default: return [:]
        }
    }

    static func percentage(currentTotal: Int, diceCount: Int, condition: (Int) -> Bool) -> Double {
        let w = weights(forDice: diceCount)
        let total = w.values.reduce(0, +)
        guard total > 0 else { return 0 }
        var matching = 0
        for (sum, weight) in w {
            if condition(currentTotal + sum) { matching += weight }
        }
        return Double(matching) / Double(total) * 100.0
    }

    static func hit21(currentTotal: Int, diceCount: Int) -> Double {
        percentage(currentTotal: currentTotal, diceCount: diceCount) { $0 == 21 }
    }

    static func reach17Plus(currentTotal: Int, diceCount: Int) -> Double {
        percentage(currentTotal: currentTotal, diceCount: diceCount) { $0 >= 17 && $0 <= 21 }
    }

    static func bust(currentTotal: Int, diceCount: Int) -> Double {
        percentage(currentTotal: currentTotal, diceCount: diceCount) { $0 > 21 }
    }
}
