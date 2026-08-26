import SwiftUI

struct PrivacySettingsView: View {
    let onDone: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        GardenSurface {
            ScrollView {
                VStack(spacing: 20) {
                    GardenNavigationHeader(
                        title: "Privacy",
                        showsTitleLeaf: false,
                        onBack: onDone
                    )

                    GardenMotif(
                        name: "settings_privacy_shield",
                        width: dynamicTypeSize.isAccessibilitySize ? 125 : 145
                    )

                    VStack(spacing: 8) {
                        Text("Your pocket, your data.")
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                            .foregroundStyle(PocketPetColors.evergreen)
                            .multilineTextAlignment(.center)
                            .accessibilityAddTraits(.isHeader)
                        Text("Pocket Pet is designed to work privately on this iPhone.")
                            .font(.system(.title3, design: .rounded))
                            .foregroundStyle(PocketPetColors.evergreen)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    privacyCard(
                        symbol: "iphone",
                        title: "Stays on this iPhone",
                        body: "Your pet's name, progress and preferences are stored locally."
                    )
                    privacyCard(
                        symbol: "bell.fill",
                        title: "One optional permission",
                        body: "Notifications are used only for reminders you choose.",
                        color: PocketPetColors.coral
                    )
                    privacyCard(
                        symbol: "shield.slash",
                        title: "Nothing follows you",
                        body: "No account, cloud, analytics, ads or tracking."
                    )

                    GardenInfoCard {
                        Label(
                            "Deleting Pocket Pet may also delete your local progress.",
                            systemImage: "leaf.fill"
                        )
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(PocketPetColors.evergreen)
                    }

                    GardenPrimaryButton(title: "Done", action: onDone)
                        .padding(.bottom, 28)
                }
                .padding(.horizontal, dynamicTypeSize.isAccessibilitySize ? 18 : 24)
                .padding(.top, 10)
            }
        }
        .navigationBarHidden(true)
    }

    private func privacyCard(
        symbol: String,
        title: String,
        body: String,
        color: Color = PocketPetColors.mutedEvergreen
    ) -> some View {
        GardenInfoCard {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: symbol)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(color.opacity(0.10)))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(PocketPetColors.evergreen)
                    Text(body)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)
        }
    }
}
