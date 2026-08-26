import SwiftUI

struct GardenSurface<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            PocketPetColors.cream.ignoresSafeArea()
            PocketPetArtwork("seed_nest_welcome_background")
                .resizable()
                .scaledToFill()
                .opacity(0.72)
                .ignoresSafeArea()
                .accessibilityHidden(true)
            content
        }
    }
}

struct GardenNavigationHeader: View {
    let title: String
    let showsTitleLeaf: Bool
    let onBack: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    backButton
                    titleView
                        .frame(maxWidth: .infinity)
                }
            } else {
                ZStack {
                    titleView
                    HStack {
                        backButton
                        Spacer()
                    }
                }
            }
        }
        .frame(minHeight: 56)
    }

    private var titleView: some View {
        HStack(spacing: 7) {
            Text(title)
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundStyle(PocketPetColors.evergreen)
                .multilineTextAlignment(.center)
            if showsTitleLeaf {
                PocketPetArtwork("settings_title_leaf")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 25, height: 25)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private var backButton: some View {
        Button(action: onBack) {
            Image(systemName: "chevron.left")
                .font(.system(size: 25, weight: .bold))
                .foregroundStyle(PocketPetColors.evergreen)
                .frame(width: 48, height: 48)
                .background(
                    Circle()
                        .fill(PocketPetColors.mint.opacity(0.62))
                        .overlay {
                            Circle().stroke(PocketPetColors.outline, lineWidth: 1.2)
                        }
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back")
    }
}

struct GardenSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title.uppercased())
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(PocketPetColors.evergreen)
                .accessibilityAddTraits(.isHeader)
                .padding(.leading, 10)

            VStack(spacing: 0) {
                content
            }
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(PocketPetColors.cardCream.opacity(0.94))
                    .shadow(color: .brown.opacity(0.07), radius: 8, y: 3)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(PocketPetColors.outline, lineWidth: 1.2)
            }
        }
    }
}

struct GardenDivider: View {
    var body: some View {
        Divider()
            .overlay(PocketPetColors.outline.opacity(0.7))
            .padding(.leading, 58)
    }
}

struct GardenRowLabel: View {
    let symbol: String
    let title: String
    var subtitle: String? = nil

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 23, weight: .semibold))
                .foregroundStyle(PocketPetColors.mutedEvergreen)
                .frame(width: 30)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundStyle(PocketPetColors.evergreen)
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 17)
        .frame(minHeight: 64)
    }
}

struct GardenDisclosureRow: View {
    let symbol: String
    let title: String
    var value: String? = nil
    let action: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button(action: action) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            disclosureIcon
                            Spacer(minLength: 8)
                            if let value {
                                disclosureValue(value)
                            }
                            disclosureChevron
                        }
                        disclosureTitle
                    }
                } else {
                    HStack(spacing: 14) {
                        disclosureIcon
                        disclosureTitle
                        Spacer(minLength: 8)
                        if let value {
                            disclosureValue(value)
                        }
                        disclosureChevron
                    }
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 17)
            .frame(minHeight: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(value ?? "")
        .accessibilityHint("Opens \(title)")
    }

    private var disclosureIcon: some View {
        Image(systemName: symbol)
            .font(.system(size: 23, weight: .semibold))
            .foregroundStyle(PocketPetColors.mutedEvergreen)
            .frame(width: 30)
            .accessibilityHidden(true)
    }

    private var disclosureTitle: some View {
        Text(title)
            .font(.system(.title3, design: .rounded, weight: .semibold))
            .foregroundStyle(PocketPetColors.evergreen)
            .multilineTextAlignment(.leading)
    }

    private func disclosureValue(_ value: String) -> some View {
        Text(value)
            .font(.system(.body, design: .rounded))
            .foregroundStyle(.secondary)
    }

    private var disclosureChevron: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(PocketPetColors.mutedEvergreen)
            .accessibilityHidden(true)
    }
}

struct GardenMotif: View {
    let name: String
    let width: CGFloat

    var body: some View {
        PocketPetArtwork(name)
            .resizable()
            .scaledToFit()
            .frame(width: width)
            .accessibilityHidden(true)
    }
}

struct GardenPrimaryButton: View {
    let title: String
    var isBusy = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                if isBusy {
                    ProgressView()
                        .tint(.white)
                        .accessibilityHidden(true)
                }
                Text(title)
                    .font(.system(.title3, design: .rounded, weight: .bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                PocketPetColors.evergreen,
                                Color(red: 0.15, green: 0.44, blue: 0.22),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
    }
}

struct GardenSecondaryButton: View {
    let title: String
    var isBusy = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(PocketPetColors.evergreen)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(PocketPetColors.cardCream.opacity(0.75))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(PocketPetColors.mutedEvergreen, lineWidth: 1.5)
                }
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
    }
}

struct GardenInfoCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(PocketPetColors.cardCream.opacity(0.92))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(PocketPetColors.outline, lineWidth: 1.1)
            }
    }
}
