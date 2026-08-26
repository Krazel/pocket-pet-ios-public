import PocketPetCore
import SwiftUI

struct HabitatHomeView: View {
    let state: HabitatViewState
    let prefersReducedMotion: Bool
    let isCareInFlight: Bool
    let onCare: (CareAction) -> Void
    let onPet: () -> Void
    let onOpenSettings: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        GeometryReader { proxy in
            let availableHeight = proxy.size.height
            let shouldScroll = dynamicTypeSize.isAccessibilitySize || availableHeight < 700
            let habitatHeight = max(360, min(490, availableHeight - 280))
            Group {
                if shouldScroll {
                    ScrollView {
                        content(habitatHeight: habitatHeight, compact: false)
                    }
                } else {
                    content(habitatHeight: habitatHeight, compact: true)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(PocketPetColors.cream.ignoresSafeArea())
        }
    }

    private func content(habitatHeight: CGFloat, compact: Bool) -> some View {
        VStack(spacing: compact ? 10 : 16) {
            header
                .padding(.horizontal, 16)

            needGrid
                .padding(.horizontal, 16)

            HabitatSceneView(
                state: state,
                prefersReducedMotion: prefersReducedMotion,
                onPet: onPet
            )
                .frame(maxWidth: .infinity)
                .frame(height: habitatHeight)
                .clipped()

            actionGrid
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
        }
    }

    private var header: some View {
        ZStack {
            Text("\(state.name)'s Habitat")
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundStyle(PocketPetColors.evergreen)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 1 : 0.72)
                .padding(.horizontal, 92)
                .accessibilitySortPriority(100)

            HStack {
                stageBadge
                Spacer()
                Button(action: onOpenSettings) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(PocketPetColors.evergreen)
                        .frame(width: 48, height: 48)
                        .background(Circle().fill(PocketPetColors.mint.opacity(0.72)))
                }
                .accessibilityLabel("Settings")
                .accessibilityHint("Opens local settings")
                .accessibilitySortPriority(50)
            }
        }
        .frame(minHeight: 54)
    }

    private var stageBadge: some View {
        HStack(spacing: 6) {
            Image(stageBadgeArtworkName, bundle: .main)
                .resizable()
                .scaledToFit()
                .frame(width: 30, height: 30)
                .accessibilityHidden(true)
            Text(state.stageLabel)
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .foregroundStyle(PocketPetColors.evergreen)
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 46)
        .background(Capsule().fill(PocketPetColors.mint.opacity(0.78)))
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("habitat.stage")
        .accessibilityLabel("\(state.name), \(state.stageLabel.lowercased())")
        .accessibilitySortPriority(90)
    }

    private var stageBadgeArtworkName: String {
        state.stage == .adult ? "icon_stage_adult" : "icon_stage_child"
    }

    private var needGrid: some View {
        LazyVGrid(
            columns: Array(
                repeating: GridItem(.flexible(), spacing: 8),
                count: dynamicTypeSize.isAccessibilitySize ? 2 : 4
            ),
            spacing: 8
        ) {
            NeedCard(need: .hunger, needs: state.needs)
            NeedCard(need: .happiness, needs: state.needs)
            NeedCard(need: .energy, needs: state.needs)
            NeedCard(need: .cleanliness, needs: state.needs)
        }
    }

    private var actionGrid: some View {
        LazyVGrid(
            columns: Array(
                repeating: GridItem(.flexible(), spacing: 10),
                count: dynamicTypeSize.isAccessibilitySize ? 2 : 4
            ),
            spacing: 10
        ) {
            ForEach(CareAction.allCases, id: \.self) { action in
                CareActionButton(
                    action: action,
                    isResting: state.condition == .sleeping,
                    isEnabled: !isCareInFlight,
                    perform: onCare
                )
            }
        }
    }
}
