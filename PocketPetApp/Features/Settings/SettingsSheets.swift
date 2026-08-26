import SwiftUI

private struct SettingsSheetSurface<Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView {
            content
                .padding(.horizontal, 28)
                .padding(.top, 22)
                .padding(.bottom, 30)
        }
        .background(PocketPetColors.cardCream.ignoresSafeArea())
        .transaction { transaction in
            if systemReduceMotion { transaction.disablesAnimations = true }
        }
    }
}

struct ReminderPermissionExplainer: View {
    let isBusy: Bool
    let onAllow: () -> Void
    let onNotNow: () -> Void

    @AccessibilityFocusState private var titleIsFocused: Bool

    var body: some View {
        SettingsSheetSurface {
            VStack(spacing: 16) {
                GardenMotif(
                    name: "settings_reminder_invitation_bell",
                    width: 155
                )

                Text("A gentle reminder?")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(PocketPetColors.evergreen)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($titleIsFocused)

                Text("Pocket Pet can send one local reminder when your little friend could use a quick check-in.")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 13) {
                    assurance("leaf", "Only after you've asked")
                    assurance("clock", "At your chosen local time")
                    assurance("checkmark.shield", "No account or tracking")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)

                GardenPrimaryButton(
                    title: isBusy ? "Requesting..." : "Allow Reminders",
                    isBusy: isBusy,
                    action: onAllow
                )
                GardenSecondaryButton(
                    title: "Not Now",
                    isBusy: isBusy,
                    action: onNotNow
                )

                Text("You can change this anytime in Settings.")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .onAppear { titleIsFocused = true }
    }

    private func assurance(_ symbol: String, _ text: String) -> some View {
        Label {
            Text(text)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.secondary)
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(PocketPetColors.mutedEvergreen)
        }
    }
}

struct SupportDevelopmentSheet: View {
    let onDone: () -> Void
    @AccessibilityFocusState private var titleIsFocused: Bool

    var body: some View {
        SettingsSheetSurface {
            VStack(spacing: 14) {
                GardenMotif(name: "settings_support_heart", width: 160)

                Text("Support development")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(PocketPetColors.evergreen)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($titleIsFocused)

                Text("Pocket Pet is fully playable without purchases.")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                GardenInfoCard {
                    VStack(spacing: 6) {
                        Text("Thank you for caring")
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundStyle(PocketPetColors.evergreen)
                        Text("Optional support may be added in a future version to help with maintenance and gentle updates.")
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                }

                GardenInfoCard {
                    ViewThatFits(in: .horizontal) {
                        purchaseStatus(axis: .horizontal)
                        purchaseStatus(axis: .vertical)
                    }
                }

                GardenPrimaryButton(title: "Done", action: onDone)

                Text("Nothing is locked.")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear { titleIsFocused = true }
    }

    private func purchaseStatus(axis: Axis) -> some View {
        Group {
            if axis == .horizontal {
                HStack {
                    purchaseLabel
                    Spacer()
                    availabilityLabel
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    purchaseLabel
                    availabilityLabel
                }
            }
        }
    }

    private var purchaseLabel: some View {
        Label("Purchases", systemImage: "info.circle")
            .font(.system(.headline, design: .rounded, weight: .semibold))
            .foregroundStyle(PocketPetColors.evergreen)
    }

    private var availabilityLabel: some View {
        Text("Not available in 0.1")
            .font(.system(.body, design: .rounded))
            .foregroundStyle(.secondary)
    }
}

struct SupportUnavailableSheet: View {
    let onDone: () -> Void
    @AccessibilityFocusState private var titleIsFocused: Bool

    var body: some View {
        SettingsSheetSurface {
            VStack(spacing: 16) {
                GardenMotif(name: "settings_support_envelope", width: 172)

                Text("Support")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(PocketPetColors.evergreen)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($titleIsFocused)

                VStack(spacing: 7) {
                    Text("Support isn't available yet")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(PocketPetColors.evergreen)
                    Text("A public support destination hasn't been configured for this development build.")
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                GardenInfoCard {
                    Label(
                        "No personal contact details are shown.",
                        systemImage: "info.circle"
                    )
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(PocketPetColors.evergreen)
                }

                GardenPrimaryButton(title: "Done", action: onDone)
            }
        }
        .onAppear { titleIsFocused = true }
    }
}
