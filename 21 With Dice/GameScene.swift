//
//  GameScene.swift
//  21 With Dice
//

import SpriteKit
import AVFoundation

class GameScene: SKScene {

    // MARK: - Types

    private enum GameState {
        case idle
        case betting
        case playerTurn
        case animating
        case handOver
    }

    // MARK: - Game Data

    private var gameState: GameState = .idle

    private var playerDiceValues: [Int] = []
    private var playerTotal = 0
    private var playerRollCount = 0

    private var computerDiceValues: [Int] = []
    private var computerTotal = 0
    private var computerRollCount = 0
    private var computerRevealedIndex = -1

    private var playerWins = 0
    private var computerWins = 0

    private let betting = BettingManager.shared

    // MARK: - UI Nodes — Labels

    private var dealerTitleLabel: SKLabelNode!
    private var dealerTotalLabel: SKLabelNode!
    private var playerTitleLabel: SKLabelNode!
    private var playerTotalLabel: SKLabelNode!
    private var narrationLabel: SKLabelNode!
    private var scoreLabel: SKLabelNode!
    private var rollInfoLabel: SKLabelNode!
    private var betAmountLabel: SKLabelNode!

    // MARK: - UI Nodes — Dice

    private var dealerDiceNodes: [DiceNode] = []
    private var playerDiceNodes: [DiceNode] = []

    // MARK: - UI Nodes — Buttons & Groups

    private var rollButtonsNode: SKNode!
    private var dealButtonNode: SKNode!
    private var chipButtonsNode: SKNode!
    private var reloadButtonNode: SKNode!
    private var winOptionsNode: SKNode!

    private var helpButtonNode: SKNode!
    private var settingsButtonNode: SKNode!

    // MARK: - UI Nodes — Bet Area

    private var betAreaNode: SKNode!

    // MARK: - UI Nodes — Overlays

    private var overlayNode: SKNode?
    private var howToPlayView: UIView?

    // MARK: - Layout

    private var dieSize: CGFloat = 50
    private var chipSize: CGFloat = 45

    // MARK: - Audio

    private let speaker = AVSpeechSynthesizer()
    private var clickPlayer: AVAudioPlayer?

    // MARK: - Scene Lifecycle

    override func didMove(to view: SKView) {
        dieSize = min(size.width, size.height) * 0.09
        chipSize = dieSize * 1.2
        setupScene()
        setupClickSound()
        Task { await ChipStoreManager.shared.loadProducts() }
        beginNewRound()
    }

    // MARK: - Scene Setup

    private func setupScene() {
        backgroundColor = UIColor(red: 0.04, green: 0.32, blue: 0.10, alpha: 1.0)

        let w = size.width
        let h = size.height

        setupMenuButtons()

        // Dealer area
        dealerTitleLabel = makeLabel("DEALER", size: 22, bold: true)
        dealerTitleLabel.position = CGPoint(x: w * 0.14, y: h * 0.91)
        dealerTitleLabel.horizontalAlignmentMode = .left
        addChild(dealerTitleLabel)

        dealerTotalLabel = makeLabel("Total: --", size: 18, bold: false)
        dealerTotalLabel.position = CGPoint(x: w * 0.88, y: h * 0.91)
        dealerTotalLabel.horizontalAlignmentMode = .right
        addChild(dealerTotalLabel)

        addRail(y: h * 0.66)

        // Narration
        narrationLabel = makeLabel("", size: 24, bold: true)
        narrationLabel.fontColor = UIColor(red: 1.0, green: 0.85, blue: 0.2, alpha: 1.0)
        narrationLabel.position = CGPoint(x: w * 0.5, y: h * 0.57)
        narrationLabel.horizontalAlignmentMode = .center
        narrationLabel.numberOfLines = 2
        narrationLabel.preferredMaxLayoutWidth = w * 0.75
        addChild(narrationLabel)

        // Bet area (visual chip stack)
        betAreaNode = SKNode()
        betAreaNode.position = CGPoint(x: w * 0.5, y: h * 0.50)
        betAreaNode.isHidden = true
        addChild(betAreaNode)

        // Bet amount (large, prominent during betting phase)
        betAmountLabel = makeLabel("", size: 22, bold: true)
        betAmountLabel.fontColor = UIColor(red: 1.0, green: 0.85, blue: 0.2, alpha: 1.0)
        betAmountLabel.position = CGPoint(x: w * 0.5, y: h * 0.43)
        betAmountLabel.horizontalAlignmentMode = .center
        betAmountLabel.isHidden = true
        addChild(betAmountLabel)

        // Score
        scoreLabel = makeLabel("Wins: 0  |  Losses: 0", size: 15, bold: false)
        scoreLabel.fontColor = UIColor(white: 0.8, alpha: 1)
        scoreLabel.position = CGPoint(x: w * 0.5, y: h * 0.38)
        scoreLabel.horizontalAlignmentMode = .center
        addChild(scoreLabel)

        addRail(y: h * 0.33)

        // Player area
        playerTitleLabel = makeLabel("YOU", size: 22, bold: true)
        playerTitleLabel.position = CGPoint(x: w * 0.08, y: h * 0.28)
        playerTitleLabel.horizontalAlignmentMode = .left
        addChild(playerTitleLabel)

        playerTotalLabel = makeLabel("Total: 0", size: 18, bold: false)
        playerTotalLabel.position = CGPoint(x: w * 0.92, y: h * 0.28)
        playerTotalLabel.horizontalAlignmentMode = .right
        addChild(playerTotalLabel)

        rollInfoLabel = makeLabel("", size: 14, bold: false)
        rollInfoLabel.fontColor = UIColor(white: 0.65, alpha: 1)
        rollInfoLabel.position = CGPoint(x: w * 0.5, y: h * 0.14)
        rollInfoLabel.horizontalAlignmentMode = .center
        addChild(rollInfoLabel)

        setupRollButtons()
        setupDealButton()
        setupChipButtons()
        setupReloadButton()
        setupWinOptions()
    }

    private func setupMenuButtons() {
        let w = size.width
        let h = size.height
        let r: CGFloat = 16

        helpButtonNode = SKNode()
        helpButtonNode.name = "helpBtn"
        helpButtonNode.position = CGPoint(x: w * 0.05, y: h * 0.91)
        let hBg = SKShapeNode(circleOfRadius: r)
        hBg.fillColor = UIColor(white: 0.15, alpha: 0.85)
        hBg.strokeColor = UIColor(red: 0.8, green: 0.6, blue: 0.2, alpha: 1)
        hBg.lineWidth = 1.5; hBg.name = "helpBtn"
        helpButtonNode.addChild(hBg)
        let hLbl = SKLabelNode(text: "?")
        hLbl.fontName = "Helvetica-Bold"; hLbl.fontSize = 18; hLbl.fontColor = .white
        hLbl.verticalAlignmentMode = .center; hLbl.name = "helpBtn"
        helpButtonNode.addChild(hLbl)
        addChild(helpButtonNode)

        settingsButtonNode = SKNode()
        settingsButtonNode.name = "settingsBtn"
        settingsButtonNode.position = CGPoint(x: w * 0.95, y: h * 0.91)
        let sBg = SKShapeNode(circleOfRadius: r)
        sBg.fillColor = UIColor(white: 0.15, alpha: 0.85)
        sBg.strokeColor = UIColor(red: 0.8, green: 0.6, blue: 0.2, alpha: 1)
        sBg.lineWidth = 1.5; sBg.name = "settingsBtn"
        settingsButtonNode.addChild(sBg)
        let sLbl = SKLabelNode(text: "\u{2699}")
        sLbl.fontSize = 20; sLbl.verticalAlignmentMode = .center; sLbl.name = "settingsBtn"
        settingsButtonNode.addChild(sLbl)
        addChild(settingsButtonNode)
    }

    private func addRail(y: CGFloat) {
        let w = size.width
        let rail = SKShapeNode(rectOf: CGSize(width: w * 0.88, height: 10), cornerRadius: 5)
        rail.fillColor = UIColor(red: 0.45, green: 0.28, blue: 0.12, alpha: 1.0)
        rail.strokeColor = UIColor(red: 0.30, green: 0.15, blue: 0.05, alpha: 1.0)
        rail.lineWidth = 1.5
        rail.position = CGPoint(x: w * 0.5, y: y)
        addChild(rail)

        let trim = SKShapeNode(rectOf: CGSize(width: w * 0.86, height: 1.5))
        trim.fillColor = UIColor(red: 0.75, green: 0.60, blue: 0.25, alpha: 0.5)
        trim.strokeColor = .clear
        trim.position = CGPoint(x: w * 0.5, y: y + 4)
        addChild(trim)
    }

    private func setupRollButtons() {
        let w = size.width
        let h = size.height
        let btnW = w * 0.17
        let btnH: CGFloat = 42
        let y = h * 0.06

        rollButtonsNode = SKNode()
        addChild(rollButtonsNode)

        let btn1 = makeButton(text: "Roll 1 Die", width: btnW, height: btnH, name: "roll1")
        btn1.position = CGPoint(x: w * 0.17, y: y)
        rollButtonsNode.addChild(btn1)

        let btn2 = makeButton(text: "Roll 2 Dice", width: btnW, height: btnH, name: "roll2")
        btn2.position = CGPoint(x: w * 0.39, y: y)
        rollButtonsNode.addChild(btn2)

        let btn3 = makeButton(text: "Roll 3 Dice", width: btnW, height: btnH, name: "roll3")
        btn3.position = CGPoint(x: w * 0.61, y: y)
        rollButtonsNode.addChild(btn3)

        let stand = makeButton(text: "Stand", width: btnW * 0.7, height: btnH, name: "stand")
        stand.position = CGPoint(x: w * 0.82, y: y)
        rollButtonsNode.addChild(stand)

        rollButtonsNode.isHidden = true
    }

    private func setupDealButton() {
        let w = size.width
        let h = size.height

        dealButtonNode = makeButton(text: "New Hand", width: w * 0.22, height: 46, name: "deal")
        dealButtonNode.position = CGPoint(x: w * 0.5, y: h * 0.06)
        addChild(dealButtonNode)
        dealButtonNode.isHidden = true
    }

    private func setupChipButtons() {
        let w = size.width
        let h = size.height
        let y = h * 0.06

        chipButtonsNode = SKNode()
        addChild(chipButtonsNode)

        let denominations = [5, 25, 100]
        let xPositions: [CGFloat] = [0.14, 0.28, 0.42]

        for (i, denom) in denominations.enumerated() {
            let chip = ChipNode(denomination: denom, size: chipSize)
            chip.name = "chip\(denom)"
            chip.position = CGPoint(x: w * xPositions[i], y: y)
            chipButtonsNode.addChild(chip)
        }

        let clearBtn = makeButton(text: "Clear Bet", width: w * 0.14, height: 40, name: "clearBet")
        clearBtn.position = CGPoint(x: w * 0.63, y: y)
        chipButtonsNode.addChild(clearBtn)

        let dealBtn = makeButton(text: "Deal", width: w * 0.14, height: 40, name: "dealBet")
        dealBtn.position = CGPoint(x: w * 0.80, y: y)
        chipButtonsNode.addChild(dealBtn)

        chipButtonsNode.isHidden = true
    }

    private func setupReloadButton() {
        let w = size.width
        let h = size.height

        reloadButtonNode = makeButton(text: "Free Reload \u{2014} $200", width: w * 0.30, height: 46, name: "reloadBtn")
        reloadButtonNode.position = CGPoint(x: w * 0.5, y: h * 0.06)
        addChild(reloadButtonNode)
        reloadButtonNode.isHidden = true
    }

    private func setupWinOptions() {
        let w = size.width
        let h = size.height
        let btnW = w * 0.19
        let btnH: CGFloat = 42
        let y = h * 0.06

        winOptionsNode = SKNode()
        addChild(winOptionsNode)

        let btn1 = makeButton(text: "Let it Ride", width: btnW, height: btnH, name: "letItRide")
        btn1.position = CGPoint(x: w * 0.12, y: y)
        winOptionsNode.addChild(btn1)

        let btn2 = makeButton(text: "Repeat Bet", width: btnW, height: btnH, name: "repeatBet")
        btn2.position = CGPoint(x: w * 0.35, y: y)
        winOptionsNode.addChild(btn2)

        let btn3 = makeButton(text: "New Bet", width: btnW, height: btnH, name: "newBet")
        btn3.position = CGPoint(x: w * 0.58, y: y)
        winOptionsNode.addChild(btn3)

        let btn4 = makeButton(text: "Take Winnings", width: btnW, height: btnH, name: "takeWinnings")
        btn4.position = CGPoint(x: w * 0.84, y: y)
        winOptionsNode.addChild(btn4)

        winOptionsNode.isHidden = true
    }

    // MARK: - UI Helpers

    private func makeLabel(_ text: String, size: CGFloat, bold: Bool) -> SKLabelNode {
        let label = SKLabelNode(text: text)
        label.fontName = bold ? "Helvetica-Bold" : "Helvetica"
        label.fontSize = size
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        return label
    }

    private func makeButton(text: String, width: CGFloat, height: CGFloat, name: String) -> SKNode {
        let container = SKNode()
        container.name = name

        let bg = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: 8)
        bg.fillColor = UIColor(red: 0.55, green: 0.10, blue: 0.10, alpha: 1.0)
        bg.strokeColor = UIColor(red: 0.80, green: 0.60, blue: 0.18, alpha: 1.0)
        bg.lineWidth = 2
        bg.name = name
        container.addChild(bg)

        let label = SKLabelNode(text: text)
        label.fontName = "Helvetica-Bold"
        label.fontSize = 15
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.name = name
        container.addChild(label)

        return container
    }

    private func setStandVisible(_ visible: Bool) {
        if let stand = rollButtonsNode.childNode(withName: "stand") {
            stand.alpha = visible ? 1.0 : 0.3
        }
    }

    private func updateRollInfo() {
        let remaining = 4 - playerRollCount
        rollInfoLabel.text = "Roll \(playerRollCount + 1) of 4  \u{2022}  \(remaining) roll\(remaining == 1 ? "" : "s") remaining"
    }

    private func updateScoreDisplay() {
        if betting.bettingEnabled {
            if gameState == .betting {
                scoreLabel.text = "Bankroll: $\(betting.bankroll)    W:\(playerWins) L:\(computerWins)"
                betAmountLabel.text = "Bet: $\(betting.currentBet)"
                betAmountLabel.isHidden = false
            } else {
                scoreLabel.text = "Bankroll: $\(betting.bankroll)  Bet: $\(betting.currentBet)  W:\(playerWins) L:\(computerWins)"
                betAmountLabel.isHidden = true
            }
        } else {
            scoreLabel.text = "Wins: \(playerWins)  |  Losses: \(computerWins)"
            betAmountLabel.isHidden = true
        }
    }

    private func updateChipButtonStates() {
        for denom in [5, 25, 100] {
            if let chip = chipButtonsNode.childNode(withName: "chip\(denom)") {
                chip.alpha = betting.bankroll >= denom ? 1.0 : 0.3
            }
        }
        if let dealBtn = chipButtonsNode.childNode(withName: "dealBet") {
            dealBtn.alpha = betting.hasBet ? 1.0 : 0.3
        }
    }

    // MARK: - Bet Area Visuals

    private func animateChipToBetArea(denomination: Int) {
        guard let sourceChip = chipButtonsNode.childNode(withName: "chip\(denomination)") else { return }
        let startPos = sourceChip.position

        let flyingChip = ChipNode(denomination: denomination, size: chipSize * 0.65)
        flyingChip.position = startPos
        flyingChip.zPosition = 50
        addChild(flyingChip)

        let chipIndex = betAreaNode.children.count
        let stackOffset = CGPoint(x: CGFloat.random(in: -10...10), y: CGFloat(chipIndex) * 3)
        let landingPos = CGPoint(x: betAreaNode.position.x + stackOffset.x,
                                 y: betAreaNode.position.y + stackOffset.y)

        let move = SKAction.move(to: landingPos, duration: 0.25)
        move.timingMode = .easeOut

        flyingChip.run(SKAction.sequence([
            move,
            SKAction.run { [weak self, weak flyingChip] in
                flyingChip?.removeFromParent()
                guard let self = self else { return }
                let stacked = ChipNode(denomination: denomination, size: self.chipSize * 0.55)
                stacked.position = stackOffset
                self.betAreaNode.addChild(stacked)
            }
        ]))
    }

    private func clearBetArea() {
        betAreaNode.removeAllChildren()
    }

    // MARK: - Dice Helpers

    private func dicePositions(count: Int, centerX: CGFloat, centerY: CGFloat) -> [CGPoint] {
        guard count > 0 else { return [] }
        let spacing = dieSize * 1.4
        let totalWidth = CGFloat(count - 1) * spacing
        return (0..<count).map { i in
            CGPoint(x: centerX - totalWidth / 2 + CGFloat(i) * spacing, y: centerY)
        }
    }

    private func animateDie(_ die: DiceNode, to target: CGPoint, value: Int, faceDown: Bool) {
        let duration: TimeInterval = 0.7
        let steps = 8
        let stepDuration = duration / Double(steps)

        var actions: [SKAction] = []
        for _ in 0..<steps {
            actions.append(SKAction.run { [weak die] in die?.showValue(Int.random(in: 1...6)) })
            actions.append(SKAction.wait(forDuration: stepDuration))
        }
        if faceDown {
            actions.append(SKAction.run { [weak die] in die?.showFaceDown() })
        } else {
            actions.append(SKAction.run { [weak die] in die?.showValue(value) })
        }

        let move = SKAction.move(to: target, duration: duration)
        move.timingMode = .easeOut
        let rotate = SKAction.rotate(toAngle: 0, duration: duration)
        rotate.timingMode = .easeOut

        die.run(SKAction.group([SKAction.sequence(actions), move, rotate]))
    }

    // MARK: - Click Sound

    private func setupClickSound() {
        let sampleRate = 44100
        let numSamples = Int(Double(sampleRate) * 0.035)
        let dataSize = numSamples * 2

        var wav = Data(capacity: 44 + dataSize)
        func u32(_ v: UInt32) { withUnsafeBytes(of: v.littleEndian) { wav.append(contentsOf: $0) } }
        func u16(_ v: UInt16) { withUnsafeBytes(of: v.littleEndian) { wav.append(contentsOf: $0) } }

        wav.append(contentsOf: [0x52,0x49,0x46,0x46]); u32(UInt32(36 + dataSize))
        wav.append(contentsOf: [0x57,0x41,0x56,0x45])
        wav.append(contentsOf: [0x66,0x6D,0x74,0x20]); u32(16)
        u16(1); u16(1); u32(UInt32(sampleRate)); u32(UInt32(sampleRate * 2)); u16(2); u16(16)
        wav.append(contentsOf: [0x64,0x61,0x74,0x61]); u32(UInt32(dataSize))

        for i in 0..<numSamples {
            let t = Double(i) / Double(sampleRate)
            let sample = sin(2.0 * .pi * 900.0 * t) * exp(-t * 120.0) * 0.7
            let clamped = Int16(clamping: Int(sample * 32767.0))
            withUnsafeBytes(of: clamped.littleEndian) { wav.append(contentsOf: $0) }
        }

        clickPlayer = try? AVAudioPlayer(data: wav)
        clickPlayer?.prepareToPlay()
    }

    private func playClick() {
        clickPlayer?.currentTime = 0
        clickPlayer?.play()
    }

    // MARK: - Narration

    private func narrate(_ text: String) {
        narrationLabel.text = text

        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.48
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        speaker.stopSpeaking(at: .immediate)
        speaker.speak(utterance)
    }

    // MARK: - Game Flow

    private func clearTable() {
        dealerDiceNodes.forEach { $0.removeFromParent() }
        playerDiceNodes.forEach { $0.removeFromParent() }
        dealerDiceNodes.removeAll()
        playerDiceNodes.removeAll()

        playerDiceValues = []
        computerDiceValues = []
        playerTotal = 0
        computerTotal = 0
        playerRollCount = 0
        computerRollCount = 0
        computerRevealedIndex = -1

        dealerTotalLabel.text = "Total: --"
        playerTotalLabel.text = "Total: 0"
    }

    private func beginNewRound() {
        clearTable()
        rollInfoLabel.text = ""
        rollButtonsNode.isHidden = true
        dealButtonNode.isHidden = true
        reloadButtonNode.isHidden = true
        chipButtonsNode.isHidden = true
        winOptionsNode.isHidden = true
        clearBetArea()
        betAreaNode.isHidden = true

        updateScoreDisplay()

        if betting.bettingEnabled {
            if betting.isBroke {
                handleBankruptcy()
                return
            }
            gameState = .betting
            chipButtonsNode.isHidden = false
            betAreaNode.isHidden = false
            updateChipButtonStates()
            narrate("Place your bet.")
        } else {
            startNewHand()
        }
    }

    private func startNewHand() {
        chipButtonsNode.isHidden = true
        betAreaNode.isHidden = true
        gameState = .animating
        updateScoreDisplay()

        narrate("Dealer rolls...")

        run(SKAction.sequence([
            SKAction.wait(forDuration: 1.2),
            SKAction.run { [weak self] in self?.computerInitialRoll() }
        ]))
    }

    private func computerInitialRoll() {
        let rand = Int.random(in: 1...10)
        let diceCount: Int
        if rand <= 6 { diceCount = 3 }
        else if rand <= 9 { diceCount = 2 }
        else { diceCount = 1 }

        computerDiceValues = (0..<diceCount).map { _ in Int.random(in: 1...6) }
        computerTotal = computerDiceValues.reduce(0, +)
        computerRollCount = 1
        computerRevealedIndex = chooseRevealIndex()

        let positions = dicePositions(count: diceCount, centerX: size.width * 0.5, centerY: size.height * 0.78)

        for (i, value) in computerDiceValues.enumerated() {
            let die = DiceNode(size: dieSize)
            die.position = CGPoint(x: positions[i].x, y: positions[i].y + 80)
            die.zRotation = CGFloat.random(in: -.pi ... .pi)
            addChild(die)
            dealerDiceNodes.append(die)
            animateDie(die, to: positions[i], value: value, faceDown: i != computerRevealedIndex)
        }

        let revealedValue = computerDiceValues[computerRevealedIndex]

        run(SKAction.sequence([
            SKAction.wait(forDuration: 1.0),
            SKAction.run { [weak self] in
                self?.narrate("Dealer shows a \(revealedValue). Your turn!")
            },
            SKAction.wait(forDuration: 1.5),
            SKAction.run { [weak self] in
                self?.gameState = .playerTurn
                self?.rollButtonsNode.isHidden = false
                self?.setStandVisible(false)
                self?.updateRollInfo()
            }
        ]))
    }

    // MARK: - Computer AI

    private func chooseRevealIndex() -> Int {
        guard computerDiceValues.count > 1 else { return 0 }
        if computerTotal >= 14 {
            return computerDiceValues.enumerated().min(by: { $0.element < $1.element })!.offset
        } else if computerTotal <= 8 {
            return computerDiceValues.enumerated().max(by: { $0.element < $1.element })!.offset
        } else {
            return Int.random(in: 0..<computerDiceValues.count)
        }
    }

    private func computerChooseDiceCount() -> Int {
        guard computerTotal < 17, computerRollCount < 4 else { return 0 }
        let room = 21 - computerTotal
        if room >= 12 && computerTotal < 9 { return 3 }
        if room >= 8 && computerTotal < 13 { return 2 }
        return 1
    }

    // MARK: - Player Actions

    private func handlePlayerRoll(diceCount: Int) {
        guard gameState == .playerTurn else { return }
        gameState = .animating

        playerRollCount += 1
        let existingCount = playerDiceNodes.count

        var newValues: [Int] = []
        for _ in 0..<diceCount { newValues.append(Int.random(in: 1...6)) }
        playerDiceValues.append(contentsOf: newValues)

        let rollTotal = newValues.reduce(0, +)
        playerTotal += rollTotal

        let totalDiceCount = existingCount + diceCount
        let allPositions = dicePositions(count: totalDiceCount, centerX: size.width * 0.5, centerY: size.height * 0.21)

        for (i, die) in playerDiceNodes.enumerated() {
            die.run(SKAction.move(to: allPositions[i], duration: 0.3))
        }

        for j in 0..<diceCount {
            let idx = existingCount + j
            let die = DiceNode(size: dieSize)
            die.position = CGPoint(x: allPositions[idx].x, y: allPositions[idx].y + 80)
            die.zRotation = CGFloat.random(in: -.pi ... .pi)
            addChild(die)
            playerDiceNodes.append(die)
            animateDie(die, to: allPositions[idx], value: newValues[j], faceDown: false)
        }

        run(SKAction.sequence([
            SKAction.wait(forDuration: 0.75),
            SKAction.run { [weak self] in
                guard let self = self else { return }
                self.playerTotalLabel.text = "Total: \(self.playerTotal)"

                if self.playerRollCount == 1 && diceCount == 3
                    && newValues.allSatisfy({ $0 == 6 }) {
                    self.finishHand(playerWon: true,
                                   message: "Three sixes! 18! Instant winner!",
                                   isThreeSixes: true)
                    return
                }

                if self.playerTotal > 21 {
                    self.finishHand(playerWon: false,
                                   message: "Sorry, you went over 21.")
                    return
                }

                let diceStr = newValues.map { String($0) }.joined(separator: " and ")
                self.narrate("You rolled \(diceStr). Total: \(self.playerTotal)")

                if self.playerTotal == 21 {
                    self.rollButtonsNode.isHidden = true
                    self.run(SKAction.sequence([
                        SKAction.wait(forDuration: 1.5),
                        SKAction.run { [weak self] in
                            guard let self = self else { return }
                            self.narrate("21! Standing.")
                            self.beginComputerReveal()
                        }
                    ]))
                    return
                }

                if self.playerRollCount >= 4 {
                    self.rollButtonsNode.isHidden = true
                    self.run(SKAction.sequence([
                        SKAction.wait(forDuration: 1.5),
                        SKAction.run { [weak self] in
                            guard let self = self else { return }
                            self.narrate("4 rolls used. You stand at \(self.playerTotal).")
                            self.beginComputerReveal()
                        }
                    ]))
                    return
                }

                self.gameState = .playerTurn
                self.setStandVisible(true)
                self.updateRollInfo()
            }
        ]))
    }

    private func handleStand() {
        guard gameState == .playerTurn, playerRollCount > 0 else { return }
        gameState = .animating
        rollButtonsNode.isHidden = true

        narrate("You stand at \(playerTotal).")

        run(SKAction.sequence([
            SKAction.wait(forDuration: 2.0),
            SKAction.run { [weak self] in self?.beginComputerReveal() }
        ]))
    }

    // MARK: - Computer Turn

    private func beginComputerReveal() {
        for (i, die) in dealerDiceNodes.enumerated() {
            if die.isFaceDown {
                let val = computerDiceValues[i]
                die.run(SKAction.sequence([
                    SKAction.scaleX(to: 0, duration: 0.2),
                    SKAction.run { die.showValue(val) },
                    SKAction.scaleX(to: 1.0, duration: 0.2)
                ]))
            }
        }
        dealerTotalLabel.text = "Total: \(computerTotal)"

        run(SKAction.sequence([
            SKAction.wait(forDuration: 1.0),
            SKAction.run { [weak self] in
                guard let self = self else { return }
                self.narrate("Dealer has \(self.computerTotal).")
            },
            SKAction.wait(forDuration: 2.5),
            SKAction.run { [weak self] in self?.computerCompleteTurn() }
        ]))
    }

    private func computerCompleteTurn() {
        guard computerTotal < 17, computerRollCount < 4 else {
            resolveHand()
            return
        }

        let diceCount = computerChooseDiceCount()
        guard diceCount > 0 else { resolveHand(); return }

        computerRollCount += 1
        let existingCount = dealerDiceNodes.count

        var newValues: [Int] = []
        for _ in 0..<diceCount { newValues.append(Int.random(in: 1...6)) }
        computerDiceValues.append(contentsOf: newValues)
        computerTotal += newValues.reduce(0, +)

        let totalDiceCount = existingCount + diceCount
        let allPositions = dicePositions(count: totalDiceCount, centerX: size.width * 0.5, centerY: size.height * 0.78)

        for (i, die) in dealerDiceNodes.enumerated() {
            die.run(SKAction.move(to: allPositions[i], duration: 0.3))
        }

        for j in 0..<diceCount {
            let idx = existingCount + j
            let die = DiceNode(size: dieSize)
            die.position = CGPoint(x: allPositions[idx].x, y: allPositions[idx].y + 80)
            die.zRotation = CGFloat.random(in: -.pi ... .pi)
            addChild(die)
            dealerDiceNodes.append(die)
            animateDie(die, to: allPositions[idx], value: newValues[j], faceDown: false)
        }

        run(SKAction.sequence([
            SKAction.wait(forDuration: 1.0),
            SKAction.run { [weak self] in
                guard let self = self else { return }
                self.dealerTotalLabel.text = "Total: \(self.computerTotal)"

                if self.computerTotal > 21 {
                    self.finishHand(playerWon: true,
                                   message: "Dealer busts with \(self.computerTotal)! You win!")
                    return
                }

                let diceStr = newValues.map { String($0) }.joined(separator: ", ")
                self.narrate("Dealer rolls \(diceStr). Dealer has \(self.computerTotal).")

                self.run(SKAction.sequence([
                    SKAction.wait(forDuration: 2.0),
                    SKAction.run { [weak self] in self?.computerCompleteTurn() }
                ]))
            }
        ]))
    }

    // MARK: - Resolution

    private func resolveHand() {
        if playerTotal > computerTotal {
            finishHand(playerWon: true,
                       message: "You have \(playerTotal) to my \(computerTotal). You win!")
        } else if computerTotal > playerTotal {
            finishHand(playerWon: false,
                       message: "I have \(computerTotal). I win.")
        } else {
            finishHand(playerWon: false,
                       message: "Tie at \(playerTotal). Dealer wins.")
        }
    }

    private func finishHand(playerWon: Bool, message: String, isThreeSixes: Bool = false) {
        if playerWon {
            playerWins += 1
            if betting.bettingEnabled && betting.hasBet {
                if isThreeSixes {
                    let payout = betting.processThreeSixesWin()
                    narrate("\(message) $\(payout) payout!")
                } else {
                    let profit = betting.processWin()
                    narrate("\(message) You win $\(profit)!")
                }
            } else {
                narrate(message)
            }
        } else {
            computerWins += 1
            if betting.bettingEnabled && betting.hasBet {
                let lost = betting.processLoss()
                narrate("\(message) You lose $\(lost).")
            } else {
                narrate(message)
            }
        }
        endHand(playerWon: playerWon)
    }

    private func endHand(playerWon: Bool) {
        gameState = .handOver
        rollButtonsNode.isHidden = true
        updateScoreDisplay()

        run(SKAction.sequence([
            SKAction.wait(forDuration: 3.0),
            SKAction.run { [weak self] in
                guard let self = self else { return }
                if self.betting.bettingEnabled && playerWon {
                    self.winOptionsNode.isHidden = false
                } else {
                    self.dealButtonNode.isHidden = false
                }
            }
        ]))
    }

    // MARK: - Betting

    private func handleChipTap(_ denomination: Int) {
        guard gameState == .betting else { return }
        if betting.addChip(denomination) {
            animateChipToBetArea(denomination: denomination)
            updateScoreDisplay()
            updateChipButtonStates()
        }
    }

    private func handleClearBet() {
        guard gameState == .betting else { return }
        betting.clearBet()
        clearBetArea()
        updateScoreDisplay()
        updateChipButtonStates()
    }

    private func handleBankruptcy() {
        if betting.canReload() {
            narrate("Tough luck. Here\u{2019}s a fresh $200 on the house.")
            reloadButtonNode.isHidden = false
        } else {
            showCashierOverlay()
        }
    }

    private func handleReload() {
        betting.reload()
        reloadButtonNode.isHidden = true
        narrate("Fresh $200! Place your bet.")
        updateScoreDisplay()

        run(SKAction.sequence([
            SKAction.wait(forDuration: 2.0),
            SKAction.run { [weak self] in
                self?.gameState = .betting
                self?.chipButtonsNode.isHidden = false
                self?.betAreaNode.isHidden = false
                self?.updateChipButtonStates()
            }
        ]))
    }

    // MARK: - Win Options

    private func handleLetItRide() {
        winOptionsNode.isHidden = true
        clearTable()
        let chips = BettingManager.chipBreakdown(for: betting.lastWinnings)
        for chip in chips { betting.addChip(chip) }
        updateScoreDisplay()
        narrate("Let it ride! $\(betting.currentBet)!")
        run(SKAction.sequence([
            SKAction.wait(forDuration: 1.5),
            SKAction.run { [weak self] in self?.startNewHand() }
        ]))
    }

    private func handleRepeatBet() {
        winOptionsNode.isHidden = true
        clearTable()
        for chip in betting.lastBetChips { betting.addChip(chip) }
        updateScoreDisplay()
        narrate("Same bet. $\(betting.currentBet)!")
        run(SKAction.sequence([
            SKAction.wait(forDuration: 1.5),
            SKAction.run { [weak self] in self?.startNewHand() }
        ]))
    }

    private func handleNewBetOption() {
        winOptionsNode.isHidden = true
        beginNewRound()
    }

    private func handleTakeWinnings() {
        winOptionsNode.isHidden = true
        betting.bettingEnabled = false
        narrate("Cashing out. Free play!")
        updateScoreDisplay()
        run(SKAction.sequence([
            SKAction.wait(forDuration: 2.0),
            SKAction.run { [weak self] in self?.beginNewRound() }
        ]))
    }

    // MARK: - Overlays

    private func showOverlay(content: SKNode) {
        dismissOverlay()

        let overlay = SKNode()
        overlay.zPosition = 100

        let bg = SKShapeNode(rectOf: CGSize(width: size.width * 2, height: size.height * 2))
        bg.fillColor = UIColor(white: 0, alpha: 0.75)
        bg.strokeColor = .clear
        bg.position = CGPoint(x: size.width / 2, y: size.height / 2)
        bg.name = "overlayBg"
        overlay.addChild(bg)

        content.position = CGPoint(x: size.width / 2, y: size.height / 2)
        overlay.addChild(content)

        addChild(overlay)
        overlayNode = overlay
    }

    private func dismissOverlay() {
        overlayNode?.removeFromParent()
        overlayNode = nil
        dismissHowToPlay()
    }

    private func showHowToPlay() {
        guard let skView = self.view else { return }

        let container = UIView(frame: skView.bounds)
        container.backgroundColor = UIColor(white: 0, alpha: 0.75)

        let pw = skView.bounds.width * 0.75
        let ph = skView.bounds.height * 0.88
        let panel = UIView(frame: CGRect(
            x: (skView.bounds.width - pw) / 2,
            y: (skView.bounds.height - ph) / 2,
            width: pw, height: ph
        ))
        panel.backgroundColor = UIColor(red: 0.06, green: 0.22, blue: 0.08, alpha: 0.97)
        panel.layer.cornerRadius = 12
        panel.layer.borderColor = UIColor(red: 0.8, green: 0.6, blue: 0.2, alpha: 1).cgColor
        panel.layer.borderWidth = 2
        panel.clipsToBounds = true
        container.addSubview(panel)

        let titleLabel = UILabel()
        titleLabel.text = "HOW TO PLAY"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 24)
        titleLabel.textColor = UIColor(red: 1, green: 0.85, blue: 0.2, alpha: 1)
        titleLabel.textAlignment = .center
        titleLabel.frame = CGRect(x: 0, y: 10, width: pw, height: 36)
        panel.addSubview(titleLabel)

        let closeBtn = UIButton(type: .system)
        closeBtn.setTitle("\u{2715}", for: .normal)
        closeBtn.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        closeBtn.setTitleColor(.white, for: .normal)
        closeBtn.backgroundColor = UIColor(red: 0.55, green: 0.10, blue: 0.10, alpha: 1)
        closeBtn.layer.cornerRadius = 15
        closeBtn.layer.borderColor = UIColor(red: 0.80, green: 0.60, blue: 0.18, alpha: 1).cgColor
        closeBtn.layer.borderWidth = 1.5
        closeBtn.frame = CGRect(x: pw - 42, y: 10, width: 30, height: 30)
        closeBtn.addTarget(self, action: #selector(dismissHowToPlay), for: .touchUpInside)
        panel.addSubview(closeBtn)

        let scrollView = UIScrollView(frame: CGRect(
            x: 24, y: 54, width: pw - 48, height: ph - 64
        ))
        scrollView.indicatorStyle = .white
        scrollView.showsVerticalScrollIndicator = true

        let contentLabel = UILabel()
        contentLabel.numberOfLines = 0
        contentLabel.attributedText = buildHowToPlayContent()
        let fitSize = contentLabel.sizeThatFits(
            CGSize(width: scrollView.bounds.width - 8, height: .greatestFiniteMagnitude))
        contentLabel.frame = CGRect(x: 4, y: 0, width: scrollView.bounds.width - 8, height: fitSize.height)

        scrollView.addSubview(contentLabel)
        scrollView.contentSize = CGSize(width: scrollView.bounds.width, height: fitSize.height + 24)
        panel.addSubview(scrollView)

        skView.addSubview(container)
        howToPlayView = container
    }

    private func buildHowToPlayContent() -> NSAttributedString {
        let gold = UIColor(red: 1, green: 0.85, blue: 0.2, alpha: 1)
        let headFont = UIFont.boldSystemFont(ofSize: 19)
        let bodyFont = UIFont.systemFont(ofSize: 17)
        let headAttrs: [NSAttributedString.Key: Any] = [.font: headFont, .foregroundColor: gold]
        let bodyAttrs: [NSAttributedString.Key: Any] = [.font: bodyFont, .foregroundColor: UIColor.white]

        let text = NSMutableAttributedString()
        func head(_ s: String) { text.append(NSAttributedString(string: s + "\n", attributes: headAttrs)) }
        func body(_ s: String) { text.append(NSAttributedString(string: s + "\n", attributes: bodyAttrs)) }
        func gap() { text.append(NSAttributedString(string: "\n", attributes: bodyAttrs)) }

        head("OBJECT")
        body("Roll dice to get as close to 21 as possible without going over.")
        gap()
        head("YOUR TURN")
        body("Choose to roll 1, 2, or 3 dice.")
        body("You may roll up to 4 times per hand.")
        body("Tap Stand to keep your total.")
        gap()
        head("DEALER RULES")
        body("Dealer rolls first, shows only one die.")
        body("After you stand, dealer reveals all.")
        body("Dealer must hit on 16 or less.")
        body("Dealer must stand on 17 or higher.")
        gap()
        head("WINNING")
        body("Highest total at or below 21 wins.")
        body("Ties go to the dealer.")
        body("Three sixes on first roll = instant win!")
        gap()
        head("STRATEGY")
        body("Watch the dealer\u{2019}s revealed die for clues.")
        body("Mix up dice count based on your total.")
        body("Standing at 17\u{2013}18 is often smart.")
        body("The dealer can bust too!")
        gap()
        head("BETTING")
        body("Toggle betting on in Settings (\u{2699}).")
        body("Place chips before each hand.")
        body("Win pays 1:1.")
        body("Three sixes on first roll pays $200 bonus.")
        body("Starting bankroll: $200.")

        return text
    }

    @objc private func dismissHowToPlay() {
        howToPlayView?.removeFromSuperview()
        howToPlayView = nil
    }

    private func showSettings() {
        let pw = size.width * 0.45
        let ph = size.height * 0.50

        let container = SKNode()

        let panel = SKShapeNode(rectOf: CGSize(width: pw, height: ph), cornerRadius: 12)
        panel.fillColor = UIColor(red: 0.06, green: 0.22, blue: 0.08, alpha: 0.97)
        panel.strokeColor = UIColor(red: 0.8, green: 0.6, blue: 0.2, alpha: 1)
        panel.lineWidth = 2
        container.addChild(panel)

        let title = SKLabelNode(text: "SETTINGS")
        title.fontName = "Helvetica-Bold"
        title.fontSize = 22
        title.fontColor = UIColor(red: 1, green: 0.85, blue: 0.2, alpha: 1)
        title.position = CGPoint(x: 0, y: ph * 0.30)
        title.verticalAlignmentMode = .center
        container.addChild(title)

        let bettingLabel = SKLabelNode(text: "Betting:")
        bettingLabel.fontName = "Helvetica"
        bettingLabel.fontSize = 18
        bettingLabel.fontColor = .white
        bettingLabel.position = CGPoint(x: -pw * 0.15, y: 0)
        bettingLabel.verticalAlignmentMode = .center
        bettingLabel.horizontalAlignmentMode = .right
        container.addChild(bettingLabel)

        let stateText = betting.bettingEnabled ? "ON" : "OFF"
        let stateColor = betting.bettingEnabled
            ? UIColor(red: 0.3, green: 1, blue: 0.3, alpha: 1)
            : UIColor(red: 1, green: 0.4, blue: 0.4, alpha: 1)

        let toggle = makeButton(text: stateText, width: 80, height: 36, name: "toggleBetting")
        toggle.position = CGPoint(x: pw * 0.15, y: 0)
        if let lbl = toggle.children.compactMap({ $0 as? SKLabelNode }).first {
            lbl.fontColor = stateColor
        }
        container.addChild(toggle)

        let close = makeButton(text: "Close", width: 100, height: 36, name: "closeOverlay")
        close.position = CGPoint(x: 0, y: -ph * 0.30)
        container.addChild(close)

        showOverlay(content: container)
    }

    private func showCashierOverlay() {
        let pw = size.width * 0.50
        let ph = size.height * 0.55

        let container = SKNode()

        let panel = SKShapeNode(rectOf: CGSize(width: pw, height: ph), cornerRadius: 12)
        panel.fillColor = UIColor(red: 0.06, green: 0.22, blue: 0.08, alpha: 0.97)
        panel.strokeColor = UIColor(red: 0.8, green: 0.6, blue: 0.2, alpha: 1)
        panel.lineWidth = 2
        container.addChild(panel)

        let title = SKLabelNode(text: "OUT OF CHIPS")
        title.fontName = "Helvetica-Bold"
        title.fontSize = 22
        title.fontColor = UIColor(red: 1, green: 0.85, blue: 0.2, alpha: 1)
        title.position = CGPoint(x: 0, y: ph * 0.30)
        title.verticalAlignmentMode = .center
        container.addChild(title)

        let priceStr = ChipStoreManager.shared.priceString
        let desc = SKLabelNode(text: "Buy $1,000 in chips for \(priceStr)")
        desc.fontName = "Helvetica"
        desc.fontSize = 16
        desc.fontColor = .white
        desc.position = CGPoint(x: 0, y: ph * 0.05)
        desc.verticalAlignmentMode = .center
        container.addChild(desc)

        let buyBtn = makeButton(text: "Buy Chips", width: pw * 0.40, height: 40, name: "buyChips")
        buyBtn.position = CGPoint(x: -pw * 0.15, y: -ph * 0.18)
        container.addChild(buyBtn)

        let noBtn = makeButton(text: "No Thanks", width: pw * 0.40, height: 40, name: "noThanks")
        noBtn.position = CGPoint(x: pw * 0.15, y: -ph * 0.18)
        container.addChild(noBtn)

        showOverlay(content: container)
    }

    private func toggleBetting() {
        betting.bettingEnabled.toggle()
        if !betting.bettingEnabled { betting.clearBet() }
        dismissOverlay()

        if gameState == .betting && !betting.bettingEnabled {
            chipButtonsNode.isHidden = true
            betAreaNode.isHidden = true
            clearBetArea()
            updateScoreDisplay()
            startNewHand()
        } else if gameState == .handOver {
            updateScoreDisplay()
        } else {
            showSettings()
        }
    }

    private func handleBuyChips() {
        Task {
            let success = await ChipStoreManager.shared.purchase()
            await MainActor.run { [weak self] in
                guard let self = self else { return }
                self.dismissOverlay()
                if success {
                    self.narrate("$1,000 in chips added!")
                    self.updateScoreDisplay()
                    self.run(SKAction.sequence([
                        SKAction.wait(forDuration: 2.0),
                        SKAction.run { [weak self] in
                            self?.gameState = .betting
                            self?.chipButtonsNode.isHidden = false
                            self?.betAreaNode.isHidden = false
                            self?.updateChipButtonStates()
                        }
                    ]))
                } else {
                    self.handleNoThanks()
                }
            }
        }
    }

    private func handleNoThanks() {
        dismissOverlay()
        betting.bettingEnabled = false
        narrate("Betting disabled. Free play!")
        updateScoreDisplay()
        run(SKAction.sequence([
            SKAction.wait(forDuration: 2.0),
            SKAction.run { [weak self] in self?.beginNewRound() }
        ]))
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        if overlayNode != nil {
            if let name = findButton(at: location) {
                handleOverlayButton(name)
            }
            return
        }

        guard let name = findButton(at: location) else { return }
        handleButton(name)
    }



    private func handleButton(_ name: String) {
        switch name {
        case "roll1":       playClick(); handlePlayerRoll(diceCount: 1)
        case "roll2":       playClick(); handlePlayerRoll(diceCount: 2)
        case "roll3":       playClick(); handlePlayerRoll(diceCount: 3)
        case "stand":       handleStand()
        case "deal":        beginNewRound()
        case "dealBet":
            guard gameState == .betting, betting.hasBet else { return }
            startNewHand()
        case "chip5":       handleChipTap(5)
        case "chip25":      handleChipTap(25)
        case "chip100":     handleChipTap(100)
        case "clearBet":    handleClearBet()
        case "helpBtn":     showHowToPlay()
        case "settingsBtn":
            if gameState == .betting || gameState == .handOver || gameState == .idle {
                showSettings()
            }
        case "reloadBtn":   handleReload()
        case "letItRide":   handleLetItRide()
        case "repeatBet":   handleRepeatBet()
        case "newBet":      handleNewBetOption()
        case "takeWinnings": handleTakeWinnings()
        default: break
        }
    }

    private func handleOverlayButton(_ name: String) {
        switch name {
        case "closeOverlay":    dismissOverlay()
        case "toggleBetting":   toggleBetting()
        case "buyChips":        handleBuyChips()
        case "noThanks":        handleNoThanks()
        default: break
        }
    }

    private func findButton(at point: CGPoint) -> String? {
        let touched = nodes(at: point)
        let buttonNames: Set<String> = [
            "roll1", "roll2", "roll3", "stand", "deal", "dealBet",
            "chip5", "chip25", "chip100", "clearBet",
            "helpBtn", "settingsBtn", "reloadBtn",
            "closeOverlay", "toggleBetting", "buyChips", "noThanks",
            "letItRide", "repeatBet", "newBet", "takeWinnings"
        ]
        for node in touched {
            var current: SKNode? = node
            while let n = current {
                if let name = n.name, buttonNames.contains(name) {
                    return name
                }
                current = n.parent
            }
        }
        return nil
    }
}
