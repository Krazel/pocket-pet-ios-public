import SwiftUI

private enum GardenSettingsRoute: Hashable {
    case reminders
    case privacy
}

struct SettingsRootView: View {
    @ObservedObject var model: PocketPetAppModel
    let onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @State private var path: [GardenSettingsRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            SettingsMainView(
                model: model,
                onClose: onClose,
                onOpenReminders: { path.append(.reminders) },
                onOpenPrivacy: { path.append(.privacy) }
            )
            .navigationBarBackButtonHidden(true)
            .navigationDestination(for: GardenSettingsRoute.self) { route in
                switch route {
                case .reminders:
                    ReminderSettingsView(
                        model: model,
                        onBack: popRoute
                    )
                case .privacy:
                    PrivacySettingsView(onDone: popRoute)
                }
            }
        }
        .tint(PocketPetColors.evergreen)
        .transaction { transaction in
            if systemReduceMotion || model.preferences.reduceMotionEnabled {
                transaction.disablesAnimations = true
            }
        }
        .alert(
            "Couldn't update Settings",
            isPresented: Binding(
                get: { model.settingsError != nil },
                set: { isPresented in
                    if !isPresented { model.clearSettingsError() }
                }
            ),
            actions: {
                Button("OK", action: model.clearSettingsError)
            },
            message: {
                Text(model.settingsError ?? "Please try again.")
            }
        )
    }

    private func popRoute() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }
}

private enum SettingsSheetFocus: Hashable {
    case reminders
    case supportDevelopment
    case support
}

private struct SettingsMainView: View {
    @ObservedObject var model: PocketPetAppModel
    let onClose: () -> Void
    let onOpenReminders: () -> Void
    let onOpenPrivacy: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AccessibilityFocusState private var focusedRow: SettingsSheetFocus?
    @State private var showsReminderExplainer = false
    @State private var showsSupportDevelopment = false
    @State private var showsSupportUnavailable = false
    @State private var opensRemindersAfterDismiss = false

    var body: some View {
        GardenSurface {
            ScrollView {
                VStack(spacing: 26) {
                    GardenNavigationHeader(
                        title: "Settings",
                        showsTitleLeaf: true,
                        onBack: onClose
                    )

                    GardenSection(title: "Preferences") {
                        preferenceToggle(
                            symbol: "speaker.wave.2.fill",
                            title: "Sound",
                            isOn: Binding(
                                get: { model.preferences.soundEnabled },
                                set: model.setSoundEnabled
                            ),
                            hint: "Controls non-essential in-app sound"
                        )

                        GardenDivider()

                        preferenceToggle(
                            symbol: "circle.dotted",
                            title: "Reduce Motion",
                            subtitle: "System setting is respected.",
                            isOn: Binding(
                                get: { model.preferences.reduceMotionEnabled },
                                set: model.setReduceMotionEnabled
                            ),
                            hint: "Additionally reduces movement inside Pocket Pet"
                        )

                        GardenDivider()

                        GardenDisclosureRow(
                            symbol: "bell.fill",
                            title: "Reminders",
                            value: reminderValue,
                            action: openReminderFlow
                        )
                        .disabled(!reminderSettingsAreAvailable)
                        .accessibilityHint(
                            reminderSettingsAreAvailable
                                ? "Opens Reminders"
                                : "Available after three care moments across two visits"
                        )
                        .accessibilityFocused($focusedRow, equals: .reminders)
                    }

                    GardenSection(title: "About") {
                        GardenDisclosureRow(
                            symbol: "heart.fill",
                            title: "Support development",
                            action: { showsSupportDevelopment = true }
                        )
                        .accessibilityFocused(
                            $focusedRow,
                            equals: .supportDevelopment
                        )

                        GardenDivider()

                        GardenDisclosureRow(
                            symbol: "lock.shield.fill",
                            title: "Privacy",
                            action: onOpenPrivacy
                        )

                        GardenDivider()

                        GardenDisclosureRow(
                            symbol: "questionmark.bubble.fill",
                            title: "Support",
                            action: { showsSupportUnavailable = true }
                        )
                        .accessibilityFocused($focusedRow, equals: .support)
                    }

                    VStack(spacing: 7) {
                        Text("Pocket Pet 0.1 (1)")
                            .font(.system(.body, design: .rounded, weight: .semibold))
                            .foregroundStyle(PocketPetColors.evergreen)
                        Text("Made for small, gentle moments.")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .multilineTextAlignment(.center)
                    .accessibilityElement(children: .combine)
                    .padding(.bottom, 38)
                }
                .padding(.horizontal, dynamicTypeSize.isAccessibilitySize ? 18 : 24)
                .padding(.top, 10)
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showsReminderExplainer, onDismiss: {
            focusedRow = .reminders
            if opensRemindersAfterDismiss {
                opensRemindersAfterDismiss = false
                onOpenReminders()
            }
        }) {
            ReminderPermissionExplainer(
                isBusy: model.isSettingsOperationInFlight,
                onAllow: {
                    model.enableReminders { outcome in
                        switch outcome {
                        case .enabled, .denied:
                            opensRemindersAfterDismiss = true
                            showsReminderExplainer = false
                        case .failed:
                            showsReminderExplainer = false
                        }
                    }
                },
                onNotNow: { showsReminderExplainer = false }
            )
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(32)
            .presentationDetents(
                dynamicTypeSize.isAccessibilitySize
                    ? Set([.large])
                    : Set([.fraction(0.64)])
            )
        }
        .sheet(isPresented: $showsSupportDevelopment, onDismiss: {
            focusedRow = .supportDevelopment
        }) {
            SupportDevelopmentSheet(
                onDone: { showsSupportDevelopment = false }
            )
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(32)
            .presentationDetents(
                dynamicTypeSize.isAccessibilitySize
                    ? Set([.large])
                    : Set([.fraction(0.55)])
            )
        }
        .sheet(isPresented: $showsSupportUnavailable, onDismiss: {
            focusedRow = .support
        }) {
            SupportUnavailableSheet(
                onDone: { showsSupportUnavailable = false }
            )
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(32)
            .presentationDetents(
                dynamicTypeSize.isAccessibilitySize
                    ? Set([.large])
                    : Set([.fraction(0.58)])
            )
        }
    }

    private func openReminderFlow() {
        guard reminderSettingsAreAvailable else { return }
        if model.preferences.remindersEnabled
            || model.notificationAuthorization == .denied {
            onOpenReminders()
        } else {
            model.markReminderInvitationShown()
            showsReminderExplainer = true
        }
    }

    @ViewBuilder
    private func preferenceToggle(
        symbol: String,
        title: String,
        subtitle: String? = nil,
        isOn: Binding<Bool>,
        hint: String
    ) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 0) {
                GardenRowLabel(
                    symbol: symbol,
                    title: title,
                    subtitle: subtitle
                )
                .accessibilityHidden(true)

                HStack {
                    Text(isOn.wrappedValue ? "On" : "Off")
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Toggle("", isOn: isOn)
                        .labelsHidden()
                        .accessibilityLabel(title)
                        .accessibilityValue(isOn.wrappedValue ? "On" : "Off")
                        .accessibilityHint(hint)
                }
                .padding(.horizontal, 17)
                .padding(.bottom, 14)
            }
            .tint(.green)
            .disabled(model.isSettingsOperationInFlight)
        } else {
            Toggle(isOn: isOn) {
                GardenRowLabel(
                    symbol: symbol,
                    title: title,
                    subtitle: subtitle
                )
            }
            .tint(.green)
            .disabled(model.isSettingsOperationInFlight)
            .accessibilityHint(hint)
        }
    }

    private var reminderSettingsAreAvailable: Bool {
        model.preferences.remindersEnabled
            || model.preferences.reminderInvitationShown
            || model.reminderInvitationIsEligible
            || model.notificationAuthorization == .denied
    }

    private var reminderValue: String {
        if model.preferences.remindersEnabled { return "On" }
        return "Off"
    }
}
