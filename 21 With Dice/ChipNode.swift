//
//  ChipNode.swift
//  21 With Dice
//

import SpriteKit

class ChipNode: SKNode {

    let denomination: Int

    init(denomination: Int, size: CGFloat) {
        self.denomination = denomination
        super.init()

        let (body, accent) = Self.colors(for: denomination)
        let radius = size / 2

        let circle = SKShapeNode(circleOfRadius: radius)
        circle.fillColor = body
        circle.strokeColor = accent.withAlphaComponent(0.6)
        circle.lineWidth = 3
        addChild(circle)

        let rimHighlight = SKShapeNode(circleOfRadius: radius - 1.5)
        rimHighlight.fillColor = .clear
        rimHighlight.strokeColor = UIColor.white.withAlphaComponent(0.15)
        rimHighlight.lineWidth = 1
        addChild(rimHighlight)

        for i in 0..<12 {
            let angle = CGFloat(i) * (.pi * 2 / 12)
            let dash = SKShapeNode(rectOf: CGSize(width: size * 0.15, height: size * 0.07), cornerRadius: 2)
            dash.fillColor = accent
            dash.strokeColor = accent.withAlphaComponent(0.3)
            dash.lineWidth = 0.5
            dash.position = CGPoint(x: cos(angle) * radius * 0.78, y: sin(angle) * radius * 0.78)
            dash.zRotation = angle
            addChild(dash)
        }

        let outerRing = SKShapeNode(circleOfRadius: radius * 0.65)
        outerRing.fillColor = .clear
        outerRing.strokeColor = accent.withAlphaComponent(0.5)
        outerRing.lineWidth = 1.5
        addChild(outerRing)

        let innerRing = SKShapeNode(circleOfRadius: radius * 0.55)
        innerRing.fillColor = .clear
        innerRing.strokeColor = accent.withAlphaComponent(0.5)
        innerRing.lineWidth = 1.5
        addChild(innerRing)

        let centerDisc = SKShapeNode(circleOfRadius: radius * 0.42)
        centerDisc.fillColor = body.withAlphaComponent(0.9)
        centerDisc.strokeColor = .clear
        addChild(centerDisc)

        let highlight = SKShapeNode(circleOfRadius: radius * 0.35)
        highlight.fillColor = UIColor.white.withAlphaComponent(0.08)
        highlight.strokeColor = .clear
        highlight.position = CGPoint(x: 0, y: radius * 0.1)
        addChild(highlight)

        let label = SKLabelNode(text: "$\(denomination)")
        label.fontName = "Helvetica-Bold"
        label.fontSize = denomination >= 100 ? size * 0.22 : size * 0.28
        label.fontColor = accent
        label.verticalAlignmentMode = .center
        addChild(label)
    }

    required init?(coder: NSCoder) { fatalError() }

    static func colors(for denomination: Int) -> (UIColor, UIColor) {
        switch denomination {
        case 5:   return (UIColor(red: 0.80, green: 0.10, blue: 0.10, alpha: 1), .white)
        case 25:  return (UIColor(red: 0.10, green: 0.50, blue: 0.15, alpha: 1), .black)
        case 100: return (.black, UIColor(red: 0.85, green: 0.68, blue: 0.20, alpha: 1))
        default:  return (.gray, .white)
        }
    }
}
