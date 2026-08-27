import PocketPetCore
import SwiftUI

struct PantryNookView: View {
    let state: PocketPetPantryPresentation
    let pet: PetState
    let prefersReducedMotion: Bool
    let offerSequence: Int
    let isOperationInFlight: Bool
    let isRoomTransitionInFlight: Bool
    let message: PocketPetPantryProductMessage?
    let onSelectFood: (ItemID) -> Void
    let onOffer: () -> Void
    let onMove: (PetSpaceID) -> Void
    let onDismissMessage: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        GeometryReader { proxy in
            let useScrollableLayout = dynamicTypeSize.isAccessibilitySize
                || proxy.size.height < 720
            Group {
                if useScrollableLayout {
                    ScrollView {
                        content(sceneHeight: dynamicTypeSize.isAccessibilitySize ? 300 : 320)
                    }
                } else {
                    content(sceneHeight: max(286, min(350, proxy.size.height * 0.39)))
                        .ignoresSafeArea(edges: .top)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(alignment: .bottom) {
                pantryFooter(width: proxy.size.width)
            }
            .background(PocketPetColors.cream.ignoresSafeArea())
        }
    }

    private func pantryFooter(width: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [
                    PocketPetColors.mint.opacity(0),
                    PocketPetColors.mint.opacity(0.78),
                    PocketPetColors.mutedEvergreen.opacity(0.48)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            PocketPetArtwork("pantry_footer_foliage")
                .resizable()
                .scaledToFill()
                .frame(width: width, height: 132, alignment: .bottom)
                .clipped()
        }
        .frame(width: width, height: 132, alignment: .bottom)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .ignoresSafeArea(edges: .bottom)
    }

    private func content(sceneHeight: CGFloat) -> some View {
        VStack(spacing: 5) {
            header
                .padding(.horizontal, 21)

            RoomRibbon(
                currentRoom: .pantryNook,
                isTransitioning: isRoomTransitionInFlight,
                onMove: onMove
            )
            .padding(.horizontal, 12)

            statusChips
                .padding(.horizontal, 58)

            metricStrip
                .padding(.horizontal, 11)

            PantrySceneView(
                pet: pet,
                selectedFood: selectedFood,
                offerSequence: offerSequence,
                prefersReducedMotion: prefersReducedMotion,
                isOfferEnabled: selectedFood?.canOffer == true
                    && !isOperationInFlight
                    && !isRoomTransitionInFlight,
                onOffer: onOffer
            )
            .frame(maxWidth: .infinity)
            .frame(height: sceneHeight)
            .clipped()

            if let message {
                messageBanner(message)
                    .padding(.horizontal, 12)
            }

            foodStrip
                .padding(.horizontal, 12)

            Spacer(minLength: 4)
        }
    }

    private var header: some View {
        ZStack {
            PocketPetArtwork("header_garden_ribbon")
                .resizable()
                .scaledToFill()
                .accessibilityHidden(true)
            Text("Pantry Nook")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(PocketPetColors.evergreen)
                .minimumScaleFactor(0.72)
                .lineLimit(1)
                .padding(.horizontal, 54)
                .accessibilityAddTraits(.isHeader)
        }
        .frame(height: 82)
        .clipped()
    }

    private var statusChips: some View {
        HStack(spacing: 12) {
            Text("Level \(state.level)")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(PocketPetColors.evergreen)
                .frame(maxWidth: .infinity, minHeight: 42)
                .background(Capsule().fill(PocketPetColors.cardCream))
                .overlay { Capsule().stroke(PocketPetColors.outline, lineWidth: 1.2) }
                .accessibilityLabel("Bond level \(state.level)")

            HStack(spacing: 7) {
                PocketPetArtwork("icon_currency_sun_seed")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 34, height: 34)
                    .accessibilityHidden(true)
                VStack(spacing: -2) {
                    Text("\(state.sunSeeds)")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                    Text("Sun Seeds")
                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                }
            }
            .foregroundStyle(PocketPetColors.evergreen)
            .frame(maxWidth: .infinity, minHeight: 42)
            .background(Capsule().fill(PocketPetColors.cardCream))
            .overlay { Capsule().stroke(PocketPetColors.outline, lineWidth: 1.2) }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(state.sunSeeds) Sun Seeds")
        }
    }

    @ViewBuilder
    private var metricStrip: some View {
        if dynamicTypeSize.isAccessibilitySize {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 7) {
                metricCards
            }
        } else {
            HStack(spacing: 5) { metricCards }
        }
    }

    @ViewBuilder
    private var metricCards: some View {
        ForEach(state.metrics, id: \.id) { metric in
            PantryMetricCard(metric: metric)
        }
    }

    @ViewBuilder
    private var foodStrip: some View {
        if dynamicTypeSize.isAccessibilitySize {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                foodCards
            }
        } else {
            HStack(spacing: 7) { foodCards }
                .frame(height: 137)
        }
    }

    @ViewBuilder
    private var foodCards: some View {
        ForEach(state.foods, id: \.id) { food in
            PantryFoodCard(
                food: food,
                isOperationInFlight: isOperationInFlight,
                onSelect: { onSelectFood(food.id) }
            )
        }
    }

    private var selectedFood: PocketPetPantryFood? {
        state.foods.first(where: \.isSelected)
    }

    private func messageBanner(
        _ message: PocketPetPantryProductMessage
    ) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(message.text)
                .font(.system(.footnote, design: .rounded, weight: .semibold))
                .foregroundStyle(PocketPetColors.evergreen)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onDismissMessage) {
                Image(systemName: "xmark")
                    .frame(width: 30, height: 30)
            }
            .accessibilityLabel("Dismiss message")
        }
        .padding(.leading, 12)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 14).fill(PocketPetColors.peach))
    }
}

private struct PantryMetricCard: View {
    let metric: PocketPetPantryMetric

    private var filledSegments: Int {
        min(4, max(0, Int(metric.value / 25)))
    }

    private var color: Color {
        switch metric.id {
        case .hungerSatisfaction: return PocketPetColors.mutedEvergreen
        case .health: return PocketPetColors.coral
        case .joy, .energy: return PocketPetColors.yellow
        case .clean: return PocketPetColors.blue
        }
    }

    private var artworkName: String {
        switch metric.id {
        case .hungerSatisfaction: return "icon_need_hunger"
        case .health: return "icon_need_health"
        case .joy: return "icon_need_joy"
        case .energy: return "icon_need_energy"
        case .clean: return "icon_need_clean"
        }
    }

    var body: some View {
        VStack(spacing: 5) {
            PocketPetArtwork(artworkName)
                .resizable()
                .scaledToFit()
                .frame(width: 38, height: 38)
                .accessibilityHidden(true)
            HStack(spacing: 2) {
                ForEach(0..<4, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(index < filledSegments ? color : PocketPetColors.outline.opacity(0.4))
                        .frame(height: 7)
                }
            }
            Text(metric.title)
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(PocketPetColors.evergreen)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, minHeight: 82)
        .padding(.horizontal, 5)
        .background(RoundedRectangle(cornerRadius: 17).fill(PocketPetColors.cardCream))
        .overlay { RoundedRectangle(cornerRadius: 17).stroke(PocketPetColors.outline) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(metric.title)
        .accessibilityValue("\(Int(metric.value.rounded())) percent")
    }
}

private struct PantryFoodCard: View {
    let food: PocketPetPantryFood
    let isOperationInFlight: Bool
    let onSelect: () -> Void

    private var artworkName: String {
        switch food.id.rawValue {
        case "food.dewberry": return "food_dewberry"
        case "food.seed-biscuit": return "food_seed_biscuit"
        default: return "food_moss_melon"
        }
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 2) {
                Text(food.name)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(PocketPetColors.evergreen)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                PocketPetArtwork(artworkName)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 78)
                    .accessibilityHidden(true)
                Text("×\(food.quantity)")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(PocketPetColors.evergreen)
                    .padding(.horizontal, 10)
                    .background(Capsule().fill(PocketPetColors.mint))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(5)
            .background(RoundedRectangle(cornerRadius: 21).fill(PocketPetColors.cardCream))
            .overlay {
                RoundedRectangle(cornerRadius: 21)
                    .stroke(
                        food.isSelected ? PocketPetColors.evergreen : PocketPetColors.outline,
                        style: StrokeStyle(
                            lineWidth: food.isSelected ? 2.4 : 1.2,
                            dash: food.isSelected ? [] : [4, 3]
                        )
                    )
            }
        }
        .buttonStyle(.plain)
        .disabled(isOperationInFlight || food.availability == .outOfStock)
        .opacity(food.availability == .outOfStock ? 0.55 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(food.name)
        .accessibilityValue(
            "\(food.quantity) available"
                + (food.isSelected ? ", selected" : "")
        )
        .accessibilityAddTraits(food.isSelected ? .isSelected : [])
    }
}
