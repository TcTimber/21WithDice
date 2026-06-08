//
//  LeaderboardManager.swift
//  21 With Dice
//

import Foundation

struct LeaderboardEntry: Codable {
    let name: String
    let score: Int
    let date: Date
}

class LeaderboardManager {

    static let shared = LeaderboardManager()

    private let nameKey = "playerName"
    private let entriesKey = "leaderboardEntries"
    private let maxEntries = 10

    var playerName: String? {
        get {
            let name = UserDefaults.standard.string(forKey: nameKey)
            return (name?.isEmpty == false) ? name : nil
        }
        set { UserDefaults.standard.set(newValue, forKey: nameKey) }
    }

    var hasPlayerName: Bool { playerName != nil }

    private(set) var entries: [LeaderboardEntry] = []

    private init() {
        loadEntries()
    }

    private func loadEntries() {
        guard let data = UserDefaults.standard.data(forKey: entriesKey),
              let decoded = try? JSONDecoder().decode([LeaderboardEntry].self, from: data) else {
            entries = []
            return
        }
        entries = decoded
    }

    private func saveEntries() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: entriesKey)
        }
    }

    func recordScore(_ score: Int) {
        guard let name = playerName, score > 0 else { return }

        if let idx = entries.firstIndex(where: { $0.name == name }) {
            if score > entries[idx].score {
                entries[idx] = LeaderboardEntry(name: name, score: score, date: Date())
            } else {
                return
            }
        } else {
            entries.append(LeaderboardEntry(name: name, score: score, date: Date()))
        }

        entries.sort { $0.score > $1.score }
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }
        saveEntries()
    }

    func reset() {
        entries = []
        saveEntries()
    }
}
