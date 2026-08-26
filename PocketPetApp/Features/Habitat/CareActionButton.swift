import PocketPetCore
import SwiftUI

struct CareActionButton: View {
    let action: CareAction
    let isResting: Bool
    let isEnabled: Bool
    let perform: (CareAction) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var title: String {
        if action == .rest && isResting { return "Wake" }
        switch action {
        case .feed: "Feed"
        case .play: "Play"
        case .rest: "Rest"
        case .clean: "Clean"
        }
    }

    private var icon: PocketPetIcon {
        switch action {
        case .feed: .feed
        case .play: .play
        case .rest: .rest
        case .clean: .clean
        }
    }

    private var background: Color {
        switch action {
        case .feed: PocketPetColors.mint
        case .play: PocketPetColors.peach
        case .rest: PocketPetColors.lavender
        case .clean: PocketPetColors.actionBlue
        }
    }

    private var accessibilityHint: String {
        switch action {
        case .feed: "Feeds your pet immediately"
        case .play: "Plays with your pet immediately"
        case .rest where isResting: "Wakes your pet immediately"
        case .rest: "Starts rest immediately"
        case .clean: "Cleans your pet immediately"
        }
    }

    var body: some View {
        Button {
            perform(action)
        } label: {
            VStack(spacing: 8) {
                icon.view
                    .frame(width: 58, height: 58)
                Text(title)
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundStyle(PocketPetColors.evergreen)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                    .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 1 : 0.75)
            }
            .frame(maxWidth: .infinity, minHeight: 90)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(background.opacity(0.76))
                    .stroke(.white.opacity(0.88), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.62)
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityLabel(title)
        .accessibilityHint(accessibilityHint)
        .accessibilitySortPriority(accessibilitySortPriority)
    }

    private var accessibilitySortPriority: Double {
        switch action {
        case .feed: 64
        case .play: 63
        case .rest: 62
        case .clean: 61
        }
    }
}
