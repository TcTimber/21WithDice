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

    private var voiceEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: "voiceEnabled") == nil { return true }
            return UserDefaults.standard.bool(forKey: "voiceEnabled")
        }
        set { UserDefaults.standard.set(newValue, forKey: "voiceEnabled") }
    }

    private var oddsTableEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: "oddsTableEnabled") == nil { return true }
            return UserDefaults.standard.bool(forKey: "oddsTableEnabled")
        }
        set { UserDefaults.standard.set(newValue, forKey: "oddsTableEnabled") }
    }

    // MARK: - UI Nodes — Labels

    private var dealerTitleLabel: SKLabelNode!
    private var dealerTotalLabel: SKLabelNode!
    private var playerTitleLabel: SKLabelNode!
    private var playerTotalLabel: SKLabelNode!
    private var narrationLabel: SKLabelNode!
    private var scoreLabel: SKLabelNode!
    private var rollInfoLabel: SKLabelNode!

    // MARK: - UI Nodes — Dice

    private var dealerDiceNodes: [DiceNode] = []
    private var playerDiceNodes: [DiceNode] = []

    // MARK: - UI Nodes — Buttons & Groups

    private var rollButtonsNode: SKNode!
    private var dealButtonNode: SKNode!

    private var helpButtonNode: SKNode!
    private var settingsButtonNode: SKNode!

    // MARK: - UI Nodes — Probability Table

    private var probabilityTableNode: SKNode!

    // MARK: - UI Nodes — Overlays

    private var overlayNode: SKNode?
    private var howToPlayView: UIView?
    private var namePromptView: UIView?
    private var leaderboardView: UIView?
    private var settingsView: UIView?

    // MARK: - Layout

    private var dieSize: CGFloat = 50

    private var uiScale: CGFloat {
        let baseHeight: CGFloat = 430
        return min(max(size.height / baseHeight, 1.0), 1.7)
    }

    // MARK: - Audio

    private let speaker = AVSpeechSynthesizer()
    private var clickPlayer: AVAudioPlayer?

    // MARK: - Scene Lifecycle

    override func didMove(to view: SKView) {
        dieSize = min(size.width, size.height) * 0.09
        setupScene()
        setupClickSound()

        if !LeaderboardManager.shared.hasPlayerName {
            showNamePrompt()
        } else {
            showWelcomeScreen()
        }
    }

    private func showWelcomeScreen() {
        clearTable()
        rollInfoLabel.text = ""
        rollButtonsNode.isHidden = true
        dealButtonNode.isHidden = false
        gameState = .idle
        updateScoreDisplay()

        let name = LeaderboardManager.shared.playerName
        let greeting = name.map { "Welcome, \($0)!" } ?? "Welcome!"
        narrate("\(greeting) Tap Settings, or New Hand to begin.")
    }

    // MARK: - Scene Setup

    private func setupScene() {
        backgroundColor = UIColor(red: 0.04, green: 0.32, blue: 0.10, alpha: 1.0)

        let w = size.width
        let h = size.height

        setupMenuButtons()

        // Dealer area
        dealerTitleLabel = makeLabel("COMPUTER", size: 22, bold: true)
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
        setupProbabilityTable()
    }

    private func setupProbabilityTable() {
        probabilityTableNode = SKNode()
        probabilityTableNode.position = CGPoint(x: size.width * 0.18, y: size.height * 0.50)
        probabilityTableNode.isHidden = true
        addChild(probabilityTableNode)
    }

    private func updateProbabilityTable() {
        probabilityTableNode.removeAllChildren()

        guard oddsTableEnabled, playerTotal >= 10, gameState == .playerTurn else {
            probabilityTableNode.isHidden = true
            return
        }
        probabilityTableNode.isHidden = false

        let cellW: CGFloat = 68 * uiScale
        let cellH: CGFloat = 24 * uiScale
        let leftW: CGFloat = 68 * uiScale
        let totalW = leftW + 3 * cellW
        let totalH: CGFloat = 4 * cellH

        let bg = SKShapeNode(rectOf: CGSize(width: totalW + 14, height: totalH + 10), cornerRadius: 6)
        bg.fillColor = UIColor(white: 0, alpha: 0.55)
        bg.strokeColor = UIColor(red: 0.8, green: 0.6, blue: 0.2, alpha: 0.6)
        bg.lineWidth = 1
        probabilityTableNode.addChild(bg)

        let xLabel = -totalW / 2 + leftW / 2
        let xCol1 = xLabel + leftW / 2 + cellW / 2
        let xCol2 = xCol1 + cellW
        let xCol3 = xCol2 + cellW
        let yHeader = totalH / 2 - cellH / 2
        let goldColor = UIColor(red: 1, green: 0.85, blue: 0.2, alpha: 1)

        let h1 = makeProbCell("\u{1F340}21", color: goldColor, bold: true)
        h1.position = CGPoint(x: xCol1, y: yHeader)
        probabilityTableNode.addChild(h1)

        let h2 = makeProbCell("17+", color: goldColor, bold: true)
        h2.position = CGPoint(x: xCol2, y: yHeader)
        probabilityTableNode.addChild(h2)

        let h3 = makeProbCell("\u{1F480}", color: goldColor, bold: true)
        h3.position = CGPoint(x: xCol3, y: yHeader)
        probabilityTableNode.addChild(h3)

        for (i, dice) in [1, 2, 3].enumerated() {
            let y = yHeader - CGFloat(i + 1) * cellH
            let labelText = dice == 1 ? "1 Die" : "\(dice) Dice"
            let label = makeProbCell(labelText, color: .white, bold: false)
            label.position = CGPoint(x: xLabel, y: y)
            probabilityTableNode.addChild(label)

            let h21Pct = Probability.hit21(currentTotal: playerTotal, diceCount: dice)
            let r17Pct = Probability.reach17Plus(currentTotal: playerTotal, diceCount: dice)
            let bustPct = Probability.bust(currentTotal: playerTotal, diceCount: dice)

            let cols = [xCol1, xCol2, xCol3]
            let vals = [h21Pct, r17Pct, bustPct]
            for j in 0..<3 {
                let (text, color) = formatProbability(vals[j])
                let cell = makeProbCell(text, color: color, bold: false)
                cell.position = CGPoint(x: cols[j], y: y)
                probabilityTableNode.addChild(cell)
            }
        }
    }

    private func makeProbCell(_ text: String, color: UIColor, bold: Bool) -> SKLabelNode {
        let label = SKLabelNode(text: text)
        label.fontName = bold ? "Helvetica-Bold" : "Helvetica"
        label.fontSize = 15 * uiScale
        label.fontColor = color
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        return label
    }

    private func formatProbability(_ v: Double) -> (String, UIColor) {
        if v < 0.05 { return ("N/A", UIColor(white: 0.5, alpha: 1)) }
        if v > 99.95 { return ("X", UIColor(red: 1, green: 0.25, blue: 0.25, alpha: 1)) }
        return (String(format: "%.1f%%", v), .white)
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
        hLbl.fontName = "Helvetica-Bold"; hLbl.fontSize = 18 * uiScale; hLbl.fontColor = .white
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
        sLbl.fontSize = 20 * uiScale; sLbl.verticalAlignmentMode = .center; sLbl.name = "settingsBtn"
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

    // MARK: - UI Helpers

    private func makeLabel(_ text: String, size: CGFloat, bold: Bool) -> SKLabelNode {
        let label = SKLabelNode(text: text)
        label.fontName = bold ? "Helvetica-Bold" : "Helvetica"
        label.fontSize = size * uiScale
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        return label
    }

    private func makeButton(text: String, width: CGFloat, height: CGFloat, name: String) -> SKNode {
        let container = SKNode()
        container.name = name

        let scaledH = height * uiScale
        let bg = SKShapeNode(rectOf: CGSize(width: width, height: scaledH), cornerRadius: 8)
        bg.fillColor = UIColor(red: 0.55, green: 0.10, blue: 0.10, alpha: 1.0)
        bg.strokeColor = UIColor(red: 0.80, green: 0.60, blue: 0.18, alpha: 1.0)
        bg.lineWidth = 2
        bg.name = name
        container.addChild(bg)

        let label = SKLabelNode(text: text)
        label.fontName = "Helvetica-Bold"
        label.fontSize = 15 * uiScale
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
        scoreLabel.text = "Wins: \(playerWins)  |  Losses: \(computerWins)"
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

        guard voiceEnabled else {
            speaker.stopSpeaking(at: .immediate)
            return
        }

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
        updateProbabilityTable()
    }

    private func beginNewRound() {
        clearTable()
        rollInfoLabel.text = ""
        rollButtonsNode.isHidden = true
        dealButtonNode.isHidden = true

        updateScoreDisplay()
        startNewHand()
    }

    private func startNewHand() {
        gameState = .animating
        updateScoreDisplay()

        narrate("Computer rolls...")

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
                self?.narrate("Computer shows a \(revealedValue). Your turn!")
            },
            SKAction.wait(forDuration: 1.5),
            SKAction.run { [weak self] in
                self?.gameState = .playerTurn
                self?.rollButtonsNode.isHidden = false
                self?.setStandVisible(false)
                self?.updateRollInfo()
                self?.updateProbabilityTable()
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
                                   message: "Three sixes! 18! Instant winner!")
                    return
                }

                if self.playerTotal > 21 {
                    self.finishHand(playerWon: false,
                                   message: "Sorry, you went over 21.")
                    return
                }

                self.narrate("You have \(self.playerTotal).")

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
                self.updateProbabilityTable()
            }
        ]))
    }

    private func handleStand() {
        guard gameState == .playerTurn, playerRollCount > 0 else { return }
        gameState = .animating
        rollButtonsNode.isHidden = true
        updateProbabilityTable()

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
                self.narrate("Computer has \(self.computerTotal).")
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
                                   message: "Computer busts with \(self.computerTotal)! You win!")
                    return
                }

                self.narrate("Computer has \(self.computerTotal).")

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
                       message: "You have \(playerTotal) to Computer's \(computerTotal). You win!")
        } else if computerTotal > playerTotal {
            finishHand(playerWon: false,
                       message: "Computer has \(computerTotal). Computer wins.")
        } else {
            finishHand(playerWon: false,
                       message: "Tie at \(playerTotal). Computer wins.")
        }
    }

    private func finishHand(playerWon: Bool, message: String) {
        if playerWon {
            playerWins += 1
        } else {
            computerWins += 1
        }
        narrate(message)
        endHand(playerWon: playerWon)
    }

    private func endHand(playerWon: Bool) {
        gameState = .handOver
        rollButtonsNode.isHidden = true
        updateScoreDisplay()

        LeaderboardManager.shared.recordScore(playerWins)
        LeaderboardManager.shared.recordScore(computerWins, for: "A.Eye")

        run(SKAction.sequence([
            SKAction.wait(forDuration: 3.0),
            SKAction.run { [weak self] in
                self?.dealButtonNode.isHidden = false
            }
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
        let monoFont = UIFont.monospacedSystemFont(ofSize: 15, weight: .regular)
        let monoHeadFont = UIFont.monospacedSystemFont(ofSize: 15, weight: .bold)
        let headAttrs: [NSAttributedString.Key: Any] = [.font: headFont, .foregroundColor: gold]
        let bodyAttrs: [NSAttributedString.Key: Any] = [.font: bodyFont, .foregroundColor: UIColor.white]
        let monoAttrs: [NSAttributedString.Key: Any] = [.font: monoFont, .foregroundColor: UIColor.white]
        let monoHeadAttrs: [NSAttributedString.Key: Any] = [.font: monoHeadFont, .foregroundColor: gold]

        let text = NSMutableAttributedString()
        func head(_ s: String) { text.append(NSAttributedString(string: s + "\n", attributes: headAttrs)) }
        func body(_ s: String) { text.append(NSAttributedString(string: s + "\n", attributes: bodyAttrs)) }
        func row(_ s: String) { text.append(NSAttributedString(string: s + "\n", attributes: monoAttrs)) }
        func tableHead(_ s: String) { text.append(NSAttributedString(string: s + "\n", attributes: monoHeadAttrs)) }
        func gap() { text.append(NSAttributedString(string: "\n", attributes: bodyAttrs)) }

        head("SETTINGS (\u{2699})")
        body("Tap the gear icon (top right) to:")
        body("\u{2022} Toggle voice narration")
        body("\u{2022} Toggle the odds table")
        body("\u{2022} View the leaderboard")
        body("\u{2022} Change your user name")
        gap()
        head("OBJECT")
        body("Roll dice to get as close to 21 as possible without going over. Beat the computer to win the hand.")
        gap()
        head("YOUR TURN")
        body("Choose to roll 1, 2, or 3 dice.")
        body("You may roll up to 4 times per hand.")
        body("Tap Stand to keep your total.")
        gap()
        head("DEALER RULES")
        body("Computer rolls first, shows only one die.")
        body("After you stand, Computer reveals all.")
        body("Computer must hit on 16 or less.")
        body("Computer must stand on 17 or higher.")
        gap()
        head("WINNING")
        body("Highest total at or below 21 wins.")
        body("Ties go to Computer.")
        body("Three sixes on first roll = instant win!")
        gap()
        head("STRATEGY")
        body("Watch the Computer\u{2019}s revealed die for clues.")
        body("Mix up dice count based on your total.")
        body("Standing at 17\u{2013}18 is often smart.")
        body("Computer can bust too!")
        gap()
        head("ODDS TABLE")
        body("Once your total reaches 10, an odds table appears on the left. Each row is a roll option (1, 2, or 3 dice).")
        gap()
        tableHead("COL     MEANING")
        row("\u{1F340} 21    Chance of landing on 21")
        row("17+     Chance of reaching 17\u{2013}21")
        row("\u{1F480}       Chance of busting (over 21)")
        row("")
        row("N/A     Impossible (0%)")
        row("X       Certain (100%)")
        gap()
        body("Toggle the table on or off in Settings.")

        return text
    }

    @objc private func dismissHowToPlay() {
        howToPlayView?.removeFromSuperview()
        howToPlayView = nil
    }

    // MARK: - Name Prompt

    private var nameTextField: UITextField?

    private func showNamePrompt() {
        guard let skView = self.view else { return }

        let container = UIView(frame: skView.bounds)
        container.backgroundColor = UIColor(white: 0, alpha: 0.85)

        let pw = min(skView.bounds.width * 0.65, 500)
        let ph: CGFloat = 280
        let panel = UIView(frame: CGRect(
            x: (skView.bounds.width - pw) / 2,
            y: (skView.bounds.height - ph) / 2,
            width: pw, height: ph
        ))
        panel.backgroundColor = UIColor(red: 0.06, green: 0.22, blue: 0.08, alpha: 0.97)
        panel.layer.cornerRadius = 12
        panel.layer.borderColor = UIColor(red: 0.8, green: 0.6, blue: 0.2, alpha: 1).cgColor
        panel.layer.borderWidth = 2
        container.addSubview(panel)

        let title = UILabel(frame: CGRect(x: 0, y: 20, width: pw, height: 30))
        title.text = nameChangeOnly ? "Change Player Name" : "Welcome to 21 With Dice!"
        title.font = UIFont.boldSystemFont(ofSize: 22)
        title.textColor = UIColor(red: 1, green: 0.85, blue: 0.2, alpha: 1)
        title.textAlignment = .center
        panel.addSubview(title)

        let subtitle = UILabel(frame: CGRect(x: 20, y: 60, width: pw - 40, height: 50))
        subtitle.text = nameChangeOnly
            ? "Enter a new name. Leave blank to play without a name."
            : "Enter your name (optional) to track your high score on the leaderboard:"
        subtitle.font = UIFont.systemFont(ofSize: 16)
        subtitle.textColor = .white
        subtitle.textAlignment = .center
        subtitle.numberOfLines = 0
        panel.addSubview(subtitle)

        let tf = UITextField(frame: CGRect(x: 30, y: 130, width: pw - 60, height: 40))
        tf.borderStyle = .roundedRect
        tf.font = UIFont.systemFont(ofSize: 18)
        tf.placeholder = "Your name"
        tf.text = nameChangeOnly ? LeaderboardManager.shared.playerName : nil
        tf.autocapitalizationType = .words
        tf.returnKeyType = .done
        tf.addTarget(self, action: #selector(handleNamePromptOK), for: .editingDidEndOnExit)
        panel.addSubview(tf)
        nameTextField = tf

        let skipBtn = UIButton(type: .system)
        skipBtn.setTitle("Skip", for: .normal)
        skipBtn.titleLabel?.font = UIFont.systemFont(ofSize: 17)
        skipBtn.setTitleColor(.white, for: .normal)
        skipBtn.backgroundColor = UIColor(white: 0.3, alpha: 1)
        skipBtn.layer.cornerRadius = 8
        skipBtn.frame = CGRect(x: pw * 0.10, y: 200, width: pw * 0.35, height: 40)
        skipBtn.addTarget(self, action: #selector(handleNamePromptSkip), for: .touchUpInside)
        panel.addSubview(skipBtn)

        let startBtn = UIButton(type: .system)
        startBtn.setTitle(nameChangeOnly ? "Save" : "Start Playing", for: .normal)
        startBtn.titleLabel?.font = UIFont.boldSystemFont(ofSize: 17)
        startBtn.setTitleColor(.white, for: .normal)
        startBtn.backgroundColor = UIColor(red: 0.55, green: 0.10, blue: 0.10, alpha: 1)
        startBtn.layer.cornerRadius = 8
        startBtn.layer.borderColor = UIColor(red: 0.80, green: 0.60, blue: 0.18, alpha: 1).cgColor
        startBtn.layer.borderWidth = 1.5
        startBtn.frame = CGRect(x: pw * 0.55, y: 200, width: pw * 0.35, height: 40)
        startBtn.addTarget(self, action: #selector(handleNamePromptOK), for: .touchUpInside)
        panel.addSubview(startBtn)

        skView.addSubview(container)
        namePromptView = container
        tf.becomeFirstResponder()
    }

    private var nameChangeOnly = false

    @objc private func handleNamePromptOK() {
        let name = nameTextField?.text?.trimmingCharacters(in: .whitespaces) ?? ""
        if !name.isEmpty {
            LeaderboardManager.shared.playerName = name
        }
        let changeOnly = nameChangeOnly
        nameChangeOnly = false
        dismissNamePrompt()
        if !changeOnly {
            showWelcomeScreen()
        }
    }

    @objc private func handleNamePromptSkip() {
        let changeOnly = nameChangeOnly
        nameChangeOnly = false
        dismissNamePrompt()
        if !changeOnly {
            showWelcomeScreen()
        }
    }

    @objc private func handleChangeName() {
        dismissSettings()
        nameChangeOnly = true
        showNamePrompt()
    }

    private func dismissNamePrompt() {
        self.view?.endEditing(true)
        namePromptView?.removeFromSuperview()
        namePromptView = nil
        nameTextField = nil
    }

    // MARK: - Leaderboard

    private func showLeaderboard() {
        guard let skView = self.view else { return }

        let container = UIView(frame: skView.bounds)
        container.backgroundColor = UIColor(white: 0, alpha: 0.85)

        let pw = min(skView.bounds.width * 0.7, 560)
        let ph = min(skView.bounds.height * 0.85, 500)
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

        let title = UILabel(frame: CGRect(x: 0, y: 14, width: pw, height: 30))
        title.text = "LEADERBOARD"
        title.font = UIFont.boldSystemFont(ofSize: 22)
        title.textColor = UIColor(red: 1, green: 0.85, blue: 0.2, alpha: 1)
        title.textAlignment = .center
        panel.addSubview(title)

        let closeBtn = UIButton(type: .system)
        closeBtn.setTitle("\u{2715}", for: .normal)
        closeBtn.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        closeBtn.setTitleColor(.white, for: .normal)
        closeBtn.backgroundColor = UIColor(red: 0.55, green: 0.10, blue: 0.10, alpha: 1)
        closeBtn.layer.cornerRadius = 15
        closeBtn.layer.borderColor = UIColor(red: 0.80, green: 0.60, blue: 0.18, alpha: 1).cgColor
        closeBtn.layer.borderWidth = 1.5
        closeBtn.frame = CGRect(x: pw - 42, y: 12, width: 30, height: 30)
        closeBtn.addTarget(self, action: #selector(dismissLeaderboard), for: .touchUpInside)
        panel.addSubview(closeBtn)

        let entries = LeaderboardManager.shared.entries
        let listX: CGFloat = 28
        let listW = pw - 56
        let listY: CGFloat = 56
        let rowHeight: CGFloat = 30
        let goldColor = UIColor(red: 1, green: 0.85, blue: 0.2, alpha: 1)

        let headerRow = UIView(frame: CGRect(x: listX, y: listY, width: listW, height: rowHeight))
        let rankH = UILabel(frame: CGRect(x: 0, y: 0, width: 40, height: rowHeight))
        rankH.text = "#"
        rankH.font = UIFont.boldSystemFont(ofSize: 14)
        rankH.textColor = goldColor
        headerRow.addSubview(rankH)
        let nameH = UILabel(frame: CGRect(x: 45, y: 0, width: listW * 0.55, height: rowHeight))
        nameH.text = "Name"
        nameH.font = UIFont.boldSystemFont(ofSize: 14)
        nameH.textColor = goldColor
        headerRow.addSubview(nameH)
        let scoreH = UILabel(frame: CGRect(x: listW * 0.65, y: 0, width: listW * 0.35, height: rowHeight))
        scoreH.text = "Wins"
        scoreH.font = UIFont.boldSystemFont(ofSize: 14)
        scoreH.textColor = goldColor
        scoreH.textAlignment = .right
        headerRow.addSubview(scoreH)
        panel.addSubview(headerRow)

        if entries.isEmpty {
            let empty = UILabel(frame: CGRect(x: 20, y: listY + rowHeight + 30, width: pw - 40, height: 40))
            empty.text = "No scores yet \u{2014} start playing!"
            empty.font = UIFont.systemFont(ofSize: 16)
            empty.textColor = UIColor(white: 0.7, alpha: 1)
            empty.textAlignment = .center
            panel.addSubview(empty)
        } else {
            for (i, entry) in entries.enumerated() {
                let y = listY + CGFloat(i + 1) * rowHeight
                let row = UIView(frame: CGRect(x: listX, y: y, width: listW, height: rowHeight))
                let rank = UILabel(frame: CGRect(x: 0, y: 0, width: 40, height: rowHeight))
                rank.text = "\(i + 1)."
                rank.font = UIFont.systemFont(ofSize: 16)
                rank.textColor = .white
                row.addSubview(rank)
                let name = UILabel(frame: CGRect(x: 45, y: 0, width: listW * 0.55, height: rowHeight))
                name.text = entry.name
                name.font = UIFont.systemFont(ofSize: 16)
                name.textColor = .white
                row.addSubview(name)
                let score = UILabel(frame: CGRect(x: listW * 0.65, y: 0, width: listW * 0.35, height: rowHeight))
                score.text = "\(entry.score)"
                score.font = UIFont.boldSystemFont(ofSize: 16)
                score.textColor = goldColor
                score.textAlignment = .right
                row.addSubview(score)
                panel.addSubview(row)
            }
        }

        let resetBtn = UIButton(type: .system)
        resetBtn.setTitle("Reset Leaderboard", for: .normal)
        resetBtn.titleLabel?.font = UIFont.boldSystemFont(ofSize: 15)
        resetBtn.setTitleColor(.white, for: .normal)
        resetBtn.backgroundColor = UIColor(white: 0.3, alpha: 1)
        resetBtn.layer.cornerRadius = 8
        resetBtn.frame = CGRect(x: (pw - 200) / 2, y: ph - 54, width: 200, height: 38)
        resetBtn.addTarget(self, action: #selector(handleResetLeaderboard), for: .touchUpInside)
        panel.addSubview(resetBtn)

        skView.addSubview(container)
        leaderboardView = container
    }

    @objc private func dismissLeaderboard() {
        leaderboardView?.removeFromSuperview()
        leaderboardView = nil
    }

    @objc private func handleResetLeaderboard() {
        LeaderboardManager.shared.reset()
        dismissLeaderboard()
        showLeaderboard()
    }

    private func showSettings() {
        guard let skView = self.view else { return }

        let container = UIView(frame: skView.bounds)
        container.backgroundColor = UIColor(white: 0, alpha: 0.85)

        let pw = min(skView.bounds.width * 0.55, 460)
        let ph: CGFloat = 320
        let panel = UIView(frame: CGRect(
            x: (skView.bounds.width - pw) / 2,
            y: (skView.bounds.height - ph) / 2,
            width: pw, height: ph
        ))
        panel.backgroundColor = UIColor(red: 0.06, green: 0.22, blue: 0.08, alpha: 0.97)
        panel.layer.cornerRadius = 12
        panel.layer.borderColor = UIColor(red: 0.8, green: 0.6, blue: 0.2, alpha: 1).cgColor
        panel.layer.borderWidth = 2
        container.addSubview(panel)

        let title = UILabel(frame: CGRect(x: 0, y: 16, width: pw, height: 30))
        title.text = "SETTINGS"
        title.font = UIFont.boldSystemFont(ofSize: 22)
        title.textColor = UIColor(red: 1, green: 0.85, blue: 0.2, alpha: 1)
        title.textAlignment = .center
        panel.addSubview(title)

        let closeBtn = UIButton(type: .system)
        closeBtn.setTitle("\u{2715}", for: .normal)
        closeBtn.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        closeBtn.setTitleColor(.white, for: .normal)
        closeBtn.backgroundColor = UIColor(red: 0.55, green: 0.10, blue: 0.10, alpha: 1)
        closeBtn.layer.cornerRadius = 15
        closeBtn.layer.borderColor = UIColor(red: 0.80, green: 0.60, blue: 0.18, alpha: 1).cgColor
        closeBtn.layer.borderWidth = 1.5
        closeBtn.frame = CGRect(x: pw - 42, y: 14, width: 30, height: 30)
        closeBtn.addTarget(self, action: #selector(dismissSettings), for: .touchUpInside)
        panel.addSubview(closeBtn)

        let voiceLabel = UILabel(frame: CGRect(x: 40, y: 80, width: pw - 130, height: 36))
        voiceLabel.text = "Voice"
        voiceLabel.font = UIFont.systemFont(ofSize: 19)
        voiceLabel.textColor = .white
        panel.addSubview(voiceLabel)

        let voiceSwitch = UISwitch()
        voiceSwitch.isOn = voiceEnabled
        voiceSwitch.frame = CGRect(x: pw - 95, y: 84, width: 51, height: 31)
        voiceSwitch.onTintColor = UIColor(red: 0.3, green: 0.75, blue: 0.3, alpha: 1)
        voiceSwitch.addTarget(self, action: #selector(voiceSwitchChanged(_:)), for: .valueChanged)
        panel.addSubview(voiceSwitch)

        let oddsLabel = UILabel(frame: CGRect(x: 40, y: 128, width: pw - 130, height: 36))
        oddsLabel.text = "Odds Table"
        oddsLabel.font = UIFont.systemFont(ofSize: 19)
        oddsLabel.textColor = .white
        panel.addSubview(oddsLabel)

        let oddsSwitch = UISwitch()
        oddsSwitch.isOn = oddsTableEnabled
        oddsSwitch.frame = CGRect(x: pw - 95, y: 132, width: 51, height: 31)
        oddsSwitch.onTintColor = UIColor(red: 0.3, green: 0.75, blue: 0.3, alpha: 1)
        oddsSwitch.addTarget(self, action: #selector(oddsTableSwitchChanged(_:)), for: .valueChanged)
        panel.addSubview(oddsSwitch)

        let sep = UIView(frame: CGRect(x: 30, y: 188, width: pw - 60, height: 1))
        sep.backgroundColor = UIColor(white: 1, alpha: 0.18)
        panel.addSubview(sep)

        let lbBtn = UIButton(type: .system)
        lbBtn.setTitle("View Leaderboard", for: .normal)
        lbBtn.titleLabel?.font = UIFont.boldSystemFont(ofSize: 17)
        lbBtn.setTitleColor(.white, for: .normal)
        lbBtn.backgroundColor = UIColor(red: 0.55, green: 0.10, blue: 0.10, alpha: 1)
        lbBtn.layer.cornerRadius = 8
        lbBtn.layer.borderColor = UIColor(red: 0.80, green: 0.60, blue: 0.18, alpha: 1).cgColor
        lbBtn.layer.borderWidth = 1.5
        lbBtn.frame = CGRect(x: (pw - 220) / 2, y: 210, width: 220, height: 38)
        lbBtn.addTarget(self, action: #selector(handleOpenLeaderboard), for: .touchUpInside)
        panel.addSubview(lbBtn)

        let changeNameBtn = UIButton(type: .system)
        changeNameBtn.setTitle("Change User Name", for: .normal)
        changeNameBtn.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        changeNameBtn.setTitleColor(.white, for: .normal)
        changeNameBtn.backgroundColor = UIColor(white: 0.3, alpha: 1)
        changeNameBtn.layer.cornerRadius = 8
        changeNameBtn.frame = CGRect(x: (pw - 180) / 2, y: 260, width: 180, height: 34)
        changeNameBtn.addTarget(self, action: #selector(handleChangeName), for: .touchUpInside)
        panel.addSubview(changeNameBtn)

        skView.addSubview(container)
        settingsView = container
    }

    @objc private func dismissSettings() {
        settingsView?.removeFromSuperview()
        settingsView = nil
    }

    @objc private func voiceSwitchChanged(_ sender: UISwitch) {
        voiceEnabled = sender.isOn
    }

    @objc private func oddsTableSwitchChanged(_ sender: UISwitch) {
        oddsTableEnabled = sender.isOn
        updateProbabilityTable()
    }

    @objc private func handleOpenLeaderboard() {
        dismissSettings()
        showLeaderboard()
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
        case "helpBtn":     showHowToPlay()
        case "settingsBtn":
            if gameState == .handOver || gameState == .idle {
                showSettings()
            }
        default: break
        }
    }

    private func handleOverlayButton(_ name: String) {
        switch name {
        case "closeOverlay":    dismissOverlay()
        default: break
        }
    }



    private func findButton(at point: CGPoint) -> String? {
        let touched = nodes(at: point)
        let buttonNames: Set<String> = [
            "roll1", "roll2", "roll3", "stand", "deal",
            "helpBtn", "settingsBtn",
            "closeOverlay"
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
