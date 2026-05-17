//
//  DiceNode.swift
//  21 With Dice
//

import SpriteKit

class DiceNode: SKNode {

    private let dieSize: CGFloat
    private let background: SKShapeNode
    private var pipNodes: [SKShapeNode] = []
    private var questionLabel: SKLabelNode?
    private(set) var value: Int = 0
    private(set) var isFaceDown: Bool = false

    init(size: CGFloat) {
        self.dieSize = size
        self.background = SKShapeNode(rectOf: CGSize(width: size, height: size), cornerRadius: size * 0.15)
        super.init()

        background.fillColor = UIColor(red: 0.78, green: 0.12, blue: 0.12, alpha: 1.0)
        background.strokeColor = UIColor(red: 0.50, green: 0.05, blue: 0.05, alpha: 1.0)
        background.lineWidth = 2
        addChild(background)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showValue(_ val: Int) {
        value = val
        isFaceDown = false
        background.fillColor = UIColor(red: 0.78, green: 0.12, blue: 0.12, alpha: 1.0)
        questionLabel?.removeFromParent()
        questionLabel = nil
        layoutPips()
    }

    func showFaceDown() {
        isFaceDown = true
        value = 0
        clearPips()
        background.fillColor = UIColor(red: 0.50, green: 0.06, blue: 0.06, alpha: 1.0)

        let q = SKLabelNode(text: "?")
        q.fontName = "Helvetica-Bold"
        q.fontSize = dieSize * 0.5
        q.fontColor = UIColor(white: 0.7, alpha: 0.5)
        q.verticalAlignmentMode = .center
        q.horizontalAlignmentMode = .center
        addChild(q)
        questionLabel = q
    }

    private func clearPips() {
        pipNodes.forEach { $0.removeFromParent() }
        pipNodes.removeAll()
    }

    private func layoutPips() {
        clearPips()
        guard value >= 1, value <= 6 else { return }

        let r = dieSize * 0.09
        let off = dieSize * 0.26

        let layouts: [[CGPoint]] = [
            [.zero],
            [CGPoint(x: off, y: off), CGPoint(x: -off, y: -off)],
            [CGPoint(x: off, y: off), .zero, CGPoint(x: -off, y: -off)],
            [CGPoint(x: -off, y: off), CGPoint(x: off, y: off),
             CGPoint(x: -off, y: -off), CGPoint(x: off, y: -off)],
            [CGPoint(x: -off, y: off), CGPoint(x: off, y: off), .zero,
             CGPoint(x: -off, y: -off), CGPoint(x: off, y: -off)],
            [CGPoint(x: -off, y: off), CGPoint(x: off, y: off),
             CGPoint(x: -off, y: 0), CGPoint(x: off, y: 0),
             CGPoint(x: -off, y: -off), CGPoint(x: off, y: -off)]
        ]

        for pos in layouts[value - 1] {
            let pip = SKShapeNode(circleOfRadius: r)
            pip.fillColor = .white
            pip.strokeColor = .clear
            pip.position = pos
            addChild(pip)
            pipNodes.append(pip)
        }
    }
}
