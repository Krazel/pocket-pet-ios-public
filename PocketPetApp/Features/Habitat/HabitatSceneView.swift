import SpriteKit
import SwiftUI
import UIKit

struct HabitatSceneView: View {
    let state: HabitatViewState
    let prefersReducedMotion: Bool
    let onPet: () -> Void

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var scene = SunnyPatioScene()

    var body: some View {
        GeometryReader { geometry in
            SpriteView(scene: scene, options: [.allowsTransparency])
                .accessibilityHidden(true)
                .overlay(alignment: .topLeading) {
                    speechBubble
                        .frame(width: bubbleWidth(in: geometry.size.width))
                        .offset(
                            x: bubbleOffsetX(in: geometry.size.width),
                            y: dynamicTypeSize.isAccessibilitySize
                                ? geometry.size.height * 0.04
                                : geometry.size.height * 0.25
                        )
                }
                .overlay {
                    Button {
                        onPet()
                    } label: {
                        Color.clear
                            .frame(
                                width: geometry.size.width * 0.44,
                                height: geometry.size.height * 0.53
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("habitat.scene")
                    .offset(y: geometry.size.height * 0.12)
                    .accessibilityLabel(state.accessibilitySceneSummary)
                    .accessibilityHint("Double tap for a friendly response")
                    .accessibilitySortPriority(70)
                }
        }
        .onAppear {
            scene.setReduceMotion(systemReduceMotion || prefersReducedMotion)
            scene.apply(stage: state.stage, condition: state.condition)
        }
        .onChange(of: systemReduceMotion) { _, value in
            scene.setReduceMotion(value || prefersReducedMotion)
        }
        .onChange(of: prefersReducedMotion) { _, value in
            scene.setReduceMotion(value || systemReduceMotion)
        }
        .onChange(of: state) { previous, current in
            if previous.stage != current.stage
                || previous.condition != current.condition {
                scene.apply(
                    stage: current.stage,
                    condition: current.condition
                )
            }
            if previous.reactionSequence != current.reactionSequence {
                scene.react(
                    to: current.reaction,
                    stage: current.stage,
                    reconciledCondition: current.condition
                )
                UIAccessibility.post(
                    notification: .announcement,
                    argument: current.speech
                )
            }
        }
        .onChange(of: state.petTapSequence) { _, _ in
            scene.acknowledgePetTap()
        }
    }

    private var speechBubble: some View {
        Text(state.speech)
            .font(.system(.headline, design: .rounded, weight: .semibold))
            .foregroundStyle(PocketPetColors.evergreen)
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.78)
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(
                SpeechBubbleBackground()
            )
            .accessibilityHidden(true)
    }

    private func bubbleWidth(in width: CGFloat) -> CGFloat {
        dynamicTypeSize.isAccessibilitySize
            ? min(width * 0.62, 300)
            : width * 0.32
    }

    private func bubbleOffsetX(in width: CGFloat) -> CGFloat {
        dynamicTypeSize.isAccessibilitySize
            ? (width - bubbleWidth(in: width)) / 2
            : width * 0.29
    }
}

private struct SpeechBubbleBackground: View {
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            SpeechBubbleTail()
                .fill(PocketPetColors.cardCream)
                .stroke(PocketPetColors.outline, lineWidth: 1)
                .frame(width: 28, height: 22)
                .offset(x: 28, y: 10)

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(PocketPetColors.cardCream)
                .stroke(PocketPetColors.outline, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
    }
}

private struct SpeechBubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.28, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
