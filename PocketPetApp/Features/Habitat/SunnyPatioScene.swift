import PocketPetCore
import SpriteKit

/// The single visual owner of the reconciled Habitat state.
///
/// SwiftUI owns semantic text and controls. SpriteKit owns only the approved
/// environment, whole-pose texture, decorative cues and bounded movement.
final class SunnyPatioScene: SKScene {
    private let environmentNode = SKSpriteNode(imageNamed: "sunny_patio_environment")
    private let groundShadow = SKShapeNode(ellipseOf: CGSize(width: 180, height: 34))
    private let petRoot = SKNode()
    private let poseRoot = SKNode()
    private let cueRoot = SKNode()
    private let sparkleRoot = SKNode()

    private var activePet = SKSpriteNode()
    private var configured = false
    private var reduceMotion = false
    private var currentStage: PetStage = .child
    private var currentCondition: PetCondition = .comfortable
    private var reactionGeneration = 0

    override init(size: CGSize = CGSize(width: 853, height: 1067)) {
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = .clear
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func didMove(to view: SKView) {
        configureIfNeeded()
        layoutNodes()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutNodes()
    }

    func setReduceMotion(_ enabled: Bool) {
        guard reduceMotion != enabled else { return }
        reduceMotion = enabled
        guard configured else { return }
        if enabled {
            reactionGeneration += 1
            clearTransientPresentation()
            presentBasePose(animated: false)
        } else {
            configureIdleAnimation()
        }
    }

    func apply(stage: PetStage, condition: PetCondition) {
        configureIfNeeded()
        currentStage = stage
        currentCondition = condition
        reactionGeneration += 1
        clearTransientPresentation()
        presentBasePose(animated: activePet.texture != nil)
    }

    func react(
        to action: CareAction?,
        stage: PetStage,
        reconciledCondition: PetCondition
    ) {
        guard let action else { return }
        configureIfNeeded()
        currentStage = stage
        currentCondition = reconciledCondition
        reactionGeneration += 1
        let generation = reactionGeneration

        clearTransientPresentation()
        poseRoot.removeAllActions()

        switch action {
        case .feed:
            presentFeedResponse()
            scheduleBasePose(after: 0.9, generation: generation)
        case .play:
            presentPose(
                named: textureName(stage: stage, condition: .comfortable),
                duration: transitionDuration
            )
            presentBallCue()
            performPlayMotion()
            scheduleBasePose(after: 0.9, generation: generation)
        case .rest:
            if reconciledCondition == .sleeping {
                presentPose(
                    named: textureName(stage: stage, condition: .sleeping),
                    duration: transitionDuration
                )
                presentSleepCue()
                performRestSettle()
            } else {
                presentBasePose(animated: true)
                performWakeMotion()
            }
        case .clean:
            if stage == .child {
                presentPose(
                    named: textureName(stage: stage, condition: .comfortable),
                    duration: transitionDuration
                )
            } else {
                presentBasePose(animated: false)
            }
            presentCleanCue()
            scheduleBasePose(after: 0.72, generation: generation)
        }
    }

    func acknowledgePetTap() {
        guard !reduceMotion else {
            activePet.run(.sequence([
                .fadeAlpha(to: 0.84, duration: 0.08),
                .fadeIn(withDuration: 0.12),
            ]))
            return
        }
        poseRoot.removeAction(forKey: "friendlyTap")
        let tap = SKAction.sequence([
            .moveBy(x: 0, y: 10, duration: 0.16),
            .moveBy(x: 0, y: -10, duration: 0.22),
        ])
        tap.timingMode = .easeInEaseOut
        poseRoot.run(tap, withKey: "friendlyTap")
    }

    private var transitionDuration: TimeInterval {
        reduceMotion ? 0.2 : 0.18
    }

    private func configureIfNeeded() {
        guard !configured else { return }
        configured = true

        environmentNode.zPosition = -100
        addChild(environmentNode)

        groundShadow.fillColor = SKColor(white: 0.12, alpha: 0.12)
        groundShadow.strokeColor = .clear
        groundShadow.zPosition = -1
        addChild(groundShadow)

        petRoot.zPosition = 2
        petRoot.addChild(poseRoot)
        addChild(petRoot)

        cueRoot.zPosition = 3
        addChild(cueRoot)

        sparkleRoot.zPosition = 4
        addChild(sparkleRoot)

        presentBasePose(animated: false)
        configureIdleAnimation()
    }

    private func layoutNodes() {
        guard configured, size.width > 0, size.height > 0 else { return }
        environmentNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
        environmentNode.size = aspectFill(
            textureSize: environmentNode.texture?.size() ?? size
        )

        let textureWidth = max(1, activePet.texture?.size().width ?? 1254)
        petRoot.setScale((size.width * 0.72) / textureWidth)
        petRoot.position = CGPoint(x: size.width * 0.495, y: size.height * 0.18)

        groundShadow.position = CGPoint(x: size.width * 0.495, y: size.height * 0.17)
        groundShadow.xScale = size.width / 853
        groundShadow.yScale = size.height / 1067

        cueRoot.position = CGPoint(x: size.width * 0.495, y: size.height * 0.18)
        sparkleRoot.position = cueRoot.position
    }

    private func presentBasePose(animated: Bool) {
        presentPose(
            named: textureName(stage: currentStage, condition: currentCondition),
            duration: animated ? transitionDuration : 0
        )
        if currentCondition == .sleeping {
            presentSleepCue()
        }
        configureIdleAnimation()
    }

    private func textureName(stage: PetStage, condition: PetCondition) -> String {
        switch (stage, condition) {
        case (.adult, .comfortable): "spriglet_adult_neutral"
        case (.adult, .needsCare): "spriglet_adult_needs_care"
        case (.adult, .sleeping): "spriglet_adult_sleeping"
        case (_, .comfortable): "spriglet_child"
        case (_, .needsCare): "spriglet_child_needs_care"
        case (_, .sleeping): "spriglet_child_sleeping"
        }
    }

    private func presentPose(named textureName: String, duration: TimeInterval) {
        let replacement = SKSpriteNode(imageNamed: textureName)
        replacement.anchorPoint = CGPoint(x: 0.5, y: 0.08)
        replacement.alpha = duration > 0 ? 0 : 1
        replacement.zPosition = 1
        poseRoot.addChild(replacement)

        let outgoing = activePet
        activePet = replacement

        if duration > 0, outgoing.parent != nil {
            outgoing.zPosition = 0
            outgoing.run(.sequence([
                .fadeOut(withDuration: duration),
                .removeFromParent(),
            ]))
            replacement.run(.fadeIn(withDuration: duration))
        } else {
            outgoing.removeFromParent()
        }
        layoutNodes()
    }

    private func presentFeedResponse() {
        if currentStage == .child {
            presentPose(named: "spriglet_child_feed", duration: transitionDuration)
        } else {
            presentPose(named: "spriglet_adult_neutral", duration: transitionDuration)
            presentLeafCue()
        }
        presentSparkles(
            color: SKColor(red: 0.69, green: 0.82, blue: 0.45, alpha: 1)
        )
        performFeedMotion()
    }

    private func performFeedMotion() {
        guard !reduceMotion else { return }
        let bob = SKAction.sequence([
            .moveBy(x: 0, y: 14, duration: 0.22),
            .moveBy(x: 0, y: -14, duration: 0.33),
        ])
        bob.timingMode = .easeInEaseOut
        poseRoot.run(bob, withKey: "careResponse")
    }

    private func performPlayMotion() {
        guard !reduceMotion else { return }
        let hop = SKAction.sequence([
            .group([
                .moveBy(x: 0, y: 20, duration: 0.26),
                .rotate(toAngle: .pi / 30, duration: 0.26, shortestUnitArc: true),
            ]),
            .group([
                .moveBy(x: 0, y: -20, duration: 0.39),
                .rotate(toAngle: 0, duration: 0.39, shortestUnitArc: true),
            ]),
        ])
        hop.timingMode = .easeInEaseOut
        poseRoot.run(hop, withKey: "careResponse")
    }

    private func performRestSettle() {
        guard !reduceMotion else { return }
        let settle = SKAction.moveBy(x: 0, y: -8, duration: 0.4)
        settle.timingMode = .easeInEaseOut
        poseRoot.run(settle, withKey: "careResponse")
    }

    private func performWakeMotion() {
        guard !reduceMotion else { return }
        poseRoot.position.y = -8
        let rise = SKAction.moveBy(x: 0, y: 8, duration: 0.5)
        rise.timingMode = .easeInEaseOut
        poseRoot.run(rise, withKey: "careResponse")
    }

    private func presentBallCue() {
        let ball = SKSpriteNode(imageNamed: "icon_ball")
        ball.name = "ball"
        ball.size = CGSize(width: size.width * 0.14, height: size.width * 0.14)
        ball.position = CGPoint(x: size.width * 0.17, y: size.height * 0.31)
        cueRoot.addChild(ball)
        presentSparkles(
            color: SKColor(red: 0.96, green: 0.42, blue: 0.34, alpha: 1)
        )

        guard !reduceMotion else {
            ball.run(.sequence([.wait(forDuration: 0.6), .removeFromParent()]))
            return
        }
        let arc = SKAction.sequence([
            .group([
                .moveBy(x: 18, y: 24, duration: 0.28),
                .rotate(byAngle: .pi / 4, duration: 0.28),
            ]),
            .group([
                .moveBy(x: -18, y: -24, duration: 0.37),
                .rotate(byAngle: .pi / 4, duration: 0.37),
            ]),
            .fadeOut(withDuration: 0.18),
            .removeFromParent(),
        ])
        arc.timingMode = .easeInEaseOut
        ball.run(arc)
    }

    private func presentLeafCue() {
        let leaf = SKShapeNode(path: leafPath())
        leaf.fillColor = SKColor(red: 0.47, green: 0.67, blue: 0.30, alpha: 1)
        leaf.strokeColor = SKColor(red: 0.12, green: 0.34, blue: 0.16, alpha: 1)
        leaf.lineWidth = 2
        leaf.position = CGPoint(x: -size.width * 0.065, y: size.height * 0.38)
        leaf.zRotation = -.pi / 7
        cueRoot.addChild(leaf)
    }

    private func presentSleepCue() {
        guard cueRoot.childNode(withName: "sleepCue") == nil else { return }
        let sleepCue = SKNode()
        sleepCue.name = "sleepCue"

        let moon = SKShapeNode(path: crescentPath())
        moon.fillColor = SKColor(red: 0.54, green: 0.49, blue: 0.72, alpha: 0.9)
        moon.strokeColor = .clear
        moon.position = CGPoint(x: size.width * 0.17, y: size.height * 0.46)
        sleepCue.addChild(moon)

        let zScales: [CGFloat] = [0.86, 0.64]
        for (index, scale) in zScales.enumerated() {
            let zed = SKLabelNode(fontNamed: "AvenirNext-Bold")
            zed.text = "Z"
            zed.fontSize = 28 * scale
            zed.fontColor = SKColor(red: 0.35, green: 0.31, blue: 0.56, alpha: 0.88)
            zed.position = CGPoint(
                x: size.width * (0.22 + CGFloat(index) * 0.035),
                y: size.height * (0.49 + CGFloat(index) * 0.04)
            )
            sleepCue.addChild(zed)
        }
        cueRoot.addChild(sleepCue)
    }

    private func presentCleanCue() {
        let positions = [
            CGPoint(x: -size.width * 0.16, y: size.height * 0.31),
            CGPoint(x: size.width * 0.15, y: size.height * 0.35),
        ]
        for (index, position) in positions.enumerated() {
            let drop = SKShapeNode(path: dropPath())
            drop.fillColor = SKColor(red: 0.30, green: 0.72, blue: 0.90, alpha: 0.86)
            drop.strokeColor = SKColor(red: 0.08, green: 0.40, blue: 0.56, alpha: 0.9)
            drop.lineWidth = 1.5
            drop.position = position
            cueRoot.addChild(drop)

            let delay = Double(index) * 0.08
            if reduceMotion {
                drop.run(.sequence([
                    .wait(forDuration: delay),
                    .fadeOut(withDuration: 0.2),
                    .removeFromParent(),
                ]))
            } else {
                drop.run(.sequence([
                    .wait(forDuration: delay),
                    .group([
                        .moveBy(x: 0, y: 34, duration: 0.52),
                        .fadeOut(withDuration: 0.7),
                    ]),
                    .removeFromParent(),
                ]))
            }
        }

        let highlight = SKShapeNode(path: sparklePath(radius: 10))
        highlight.fillColor = SKColor(
            red: 0.92,
            green: 0.98,
            blue: 0.92,
            alpha: 0.92
        )
        highlight.strokeColor = .clear
        highlight.position = CGPoint(
            x: size.width * 0.20,
            y: size.height * 0.42
        )
        cueRoot.addChild(highlight)
        highlight.run(.sequence([
            .fadeOut(withDuration: reduceMotion ? 0.2 : 0.7),
            .removeFromParent(),
        ]))
    }

    private func presentSparkles(color: SKColor) {
        let offsets = [
            CGPoint(x: -size.width * 0.18, y: size.height * 0.39),
            CGPoint(x: size.width * 0.17, y: size.height * 0.42),
            CGPoint(x: size.width * 0.22, y: size.height * 0.31),
        ]
        for (index, offset) in offsets.enumerated() {
            let sparkle = SKShapeNode(path: sparklePath(radius: 8 - CGFloat(index)))
            sparkle.fillColor = color
            sparkle.strokeColor = .clear
            sparkle.position = offset
            sparkleRoot.addChild(sparkle)
            let duration = reduceMotion ? 0.2 : 0.62 + Double(index) * 0.08
            sparkle.run(.sequence([
                .fadeOut(withDuration: duration),
                .removeFromParent(),
            ]))
        }
    }

    private func scheduleBasePose(after delay: TimeInterval, generation: Int) {
        run(.sequence([
            .wait(forDuration: reduceMotion ? min(0.6, delay) : delay),
            .run { [weak self] in
                guard let self, self.reactionGeneration == generation else { return }
                self.clearTransientPresentation()
                self.presentBasePose(animated: true)
            },
        ]), withKey: "returnToBase")
    }

    private func clearTransientPresentation() {
        removeAction(forKey: "returnToBase")
        poseRoot.removeAllActions()
        poseRoot.position = .zero
        poseRoot.zRotation = 0
        poseRoot.xScale = 1
        poseRoot.yScale = 1
        cueRoot.removeAllChildren()
        sparkleRoot.removeAllChildren()
    }

    private func configureIdleAnimation() {
        poseRoot.removeAction(forKey: "idle")
        poseRoot.xScale = 1
        poseRoot.yScale = 1
        guard configured, !reduceMotion, currentCondition == .comfortable else { return }
        let breathe = SKAction.sequence([
            .scaleY(to: 1.012, duration: 2.1),
            .scaleY(to: 1, duration: 2.1),
        ])
        breathe.timingMode = .easeInEaseOut
        poseRoot.run(.repeatForever(breathe), withKey: "idle")
    }

    private func aspectFill(textureSize: CGSize) -> CGSize {
        let scale = max(
            size.width / max(1, textureSize.width),
            size.height / max(1, textureSize.height)
        )
        return CGSize(width: textureSize.width * scale, height: textureSize.height * scale)
    }

    private func leafPath() -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: -12))
        path.addCurve(
            to: CGPoint(x: 18, y: 14),
            control1: CGPoint(x: -2, y: 7),
            control2: CGPoint(x: 8, y: 16)
        )
        path.addCurve(
            to: CGPoint(x: 0, y: -12),
            control1: CGPoint(x: 20, y: -4),
            control2: CGPoint(x: 8, y: -13)
        )
        path.closeSubpath()
        return path
    }

    private func crescentPath() -> CGPath {
        let path = CGMutablePath()
        path.addArc(
            center: .zero,
            radius: 23,
            startAngle: 0,
            endAngle: .pi * 2,
            clockwise: false
        )
        path.addArc(
            center: CGPoint(x: 10, y: 8),
            radius: 20,
            startAngle: 0,
            endAngle: .pi * 2,
            clockwise: true
        )
        return path
    }

    private func dropPath() -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 14))
        path.addCurve(
            to: CGPoint(x: 0, y: -13),
            control1: CGPoint(x: 14, y: -2),
            control2: CGPoint(x: 10, y: -13)
        )
        path.addCurve(
            to: CGPoint(x: 0, y: 14),
            control1: CGPoint(x: -10, y: -13),
            control2: CGPoint(x: -14, y: -2)
        )
        path.closeSubpath()
        return path
    }

    private func sparklePath(radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: radius))
        path.addLine(to: CGPoint(x: radius * 0.28, y: radius * 0.28))
        path.addLine(to: CGPoint(x: radius, y: 0))
        path.addLine(to: CGPoint(x: radius * 0.28, y: -radius * 0.28))
        path.addLine(to: CGPoint(x: 0, y: -radius))
        path.addLine(to: CGPoint(x: -radius * 0.28, y: -radius * 0.28))
        path.addLine(to: CGPoint(x: -radius, y: 0))
        path.addLine(to: CGPoint(x: -radius * 0.28, y: radius * 0.28))
        path.closeSubpath()
        return path
    }
}
