//
//  GameCenterManager.swift
//  21 With Dice
//

import GameKit
import UIKit

final class GameCenterManager: NSObject {

    static let shared = GameCenterManager()

    private let mostWinsLeaderboardID = "com.21withdice.mostwins"

    private(set) var isAuthenticated = false
    weak var presentingViewController: UIViewController?

    private override init() { super.init() }

    // Called once at app launch from GameViewController.
    func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] vc, error in
            guard let self = self else { return }

            if let vc = vc {
                self.presentingViewController?.present(vc, animated: true)
                return
            }

            if error != nil {
                self.isAuthenticated = false
                return
            }

            self.isAuthenticated = GKLocalPlayer.local.isAuthenticated
        }
    }

    // Best-effort score submission. Silent on failure.
    func reportMostWins(_ wins: Int) {
        guard isAuthenticated, wins > 0 else { return }

        GKLeaderboard.submitScore(wins,
                                  context: 0,
                                  player: GKLocalPlayer.local,
                                  leaderboardIDs: [mostWinsLeaderboardID],
                                  completionHandler: { _ in })
    }

    // Presents Apple's native leaderboard UI.
    func presentLeaderboard() {
        guard let presenter = presentingViewController else { return }

        guard isAuthenticated else {
            let alert = UIAlertController(
                title: "Game Center Not Signed In",
                message: "Sign in to Game Center in iOS Settings to view the online leaderboard.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            presenter.present(alert, animated: true)
            return
        }

        let vc = GKGameCenterViewController(leaderboardID: mostWinsLeaderboardID,
                                            playerScope: .global,
                                            timeScope: .allTime)
        vc.gameCenterDelegate = self
        presenter.present(vc, animated: true)
    }
}

extension GameCenterManager: GKGameCenterControllerDelegate {
    func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        gameCenterViewController.dismiss(animated: true)
    }
}
