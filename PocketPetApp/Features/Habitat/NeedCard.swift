import PocketPetCore
import SwiftUI

struct NeedCard: View {
    let need: PetNeed
    let needs: PetNeeds

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var title: String {
        switch need {
        case .hunger: "Hunger"
        case .happiness: "Happiness"
        case .energy: "Energy"
        case .cleanliness: "Cleanliness"
        }
    }

    private var icon: PocketPetIcon {
        switch need {
        case .hunger: .hunger
        case .happiness: .happiness
        case .energy: .energy
        case .cleanliness: .cleanliness
        }
    }

    private var color: Color {
        switch need {
        case .hunger: PocketPetColors.mutedEvergreen
        case .happiness: PocketPetColors.coral
        case .energy: PocketPetColors.yellow
        case .cleanliness: PocketPetColors.blue
        }
    }

    private var rawValue: Double {
        switch need {
        case .hunger: needs.hunger
        case .happiness: needs.happiness
        case .energy: needs.energy
        case .cleanliness: needs.cleanliness
        }
    }

    private var wellbeingValue: Double {
        need == .hunger ? 100 - rawValue : rawValue
    }

    private var filledSegments: Int {
        min(4, max(0, Int(wellbeingValue / 25)))
    }

    private var statusLabel: String {
        switch needs.status(for: need) {
        case .comfortable: "comfortable"
        case .attention: "could use attention"
        case .urgent: "needs care"
        }
    }

    var body: some View {
        VStack(spacing: 7) {
            icon.view
                .frame(width: 44, height: 44)

            HStack(spacing: 4) {
                ForEach(0..<4, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(index < filledSegments ? color : PocketPetColors.outline.opacity(0.45))
                        .frame(height: 10)
                }
            }

            Text(title)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(PocketPetColors.evergreen)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 1 : 0.72)
        }
        .frame(maxWidth: .infinity, minHeight: 84)
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .fill(PocketPetColors.cardCream)
                .stroke(PocketPetColors.outline, lineWidth: 1.2)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(accessibilityValue)
        .accessibilitySortPriority(accessibilitySortPriority)
    }

    private var accessibilityValue: String {
        let value = Int(wellbeingValue.rounded())
        if need == .hunger {
            return "\(value) percent satisfied, \(statusLabel)"
        }
        return "\(value) percent, \(statusLabel)"
    }

    private var accessibilitySortPriority: Double {
        switch need {
        case .hunger: 84
        case .happiness: 83
        case .energy: 82
        case .cleanliness: 81
        }
    }
}
