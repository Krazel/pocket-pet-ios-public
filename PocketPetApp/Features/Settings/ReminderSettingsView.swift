import PocketPetCore
import SwiftUI

struct ReminderSettingsView: View {
    @ObservedObject var model: PocketPetAppModel
    let onBack: () -> Void

    var body: some View {
        Group {
            if model.notificationAuthorization == .denied {
                ReminderPermissionDeniedView(
                    isBusy: model.isSettingsOperationInFlight,
                    onOpenSettings: model.openSystemNotificationSettings,
                    onNotNow: onBack
                )
            } else {
                RemindersEnabledView(model: model, onBack: onBack)
            }
        }
        .navigationBarHidden(true)
    }
}

private struct RemindersEnabledView: View {
    @ObservedObject var model: PocketPetAppModel
    let onBack: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selectedTime: Date

    init(model: PocketPetAppModel, onBack: @escaping () -> Void) {
        self.model = model
        self.onBack = onBack
        _selectedTime = State(initialValue: Self.date(for: model.preferences.reminderTime))
    }

    var body: some View {
        GardenSurface {
            ScrollView {
                VStack(spacing: 22) {
                    GardenNavigationHeader(
                        title: "Reminders",
                        showsTitleLeaf: false,
                        onBack: onBack
                    )

                    GardenMotif(
                        name: "settings_reminder_enabled_bell",
                        width: dynamicTypeSize.isAccessibilitySize ? 145 : 174
                    )

                    GardenInfoCard {
                        Toggle(
                            "Reminders",
                            isOn: Binding(
                                get: { model.preferences.remindersEnabled },
                                set: { isEnabled in
                                    if !isEnabled {
                                        model.disableReminders(completion: onBack)
                                    }
                                }
                            )
                        )
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(PocketPetColors.evergreen)
                        .tint(.green)
                        .disabled(model.isSettingsOperationInFlight)
                        .frame(minHeight: 56)
                    }

                    GardenInfoCard {
                        HStack(alignment: .top, spacing: 16) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(PocketPetColors.mutedEvergreen)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Gentle reminders are on")
                                    .font(.system(.title3, design: .rounded, weight: .bold))
                                    .foregroundStyle(PocketPetColors.evergreen)
                                Text("Pocket Pet will send at most one local reminder in 24 hours.")
                                    .font(.system(.body, design: .rounded))
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }

                    VStack(alignment: .leading, spacing: 9) {
                        Text("REMINDER TIME")
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundStyle(PocketPetColors.evergreen)
                            .padding(.leading, 10)
                            .accessibilityAddTraits(.isHeader)

                        GardenInfoCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Local time")
                                    .font(.system(.headline, design: .rounded, weight: .bold))
                                    .foregroundStyle(PocketPetColors.evergreen)

                                DatePicker(
                                    "Local reminder time",
                                    selection: $selectedTime,
                                    displayedComponents: .hourAndMinute
                                )
                                .datePickerStyle(.wheel)
                                .labelsHidden()
                                .accessibilityIdentifier("settings.reminderTime")
                                .frame(maxWidth: .infinity)
                                .disabled(model.isSettingsOperationInFlight)
                                .accessibilityHint("Selects your local reminder time")

                                Text("We'll only remind you when your little friend could use a check-in.")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                    GardenSecondaryButton(
                        title: "Turn Off Reminders",
                        isBusy: model.isSettingsOperationInFlight,
                        action: {
                            model.disableReminders(completion: onBack)
                        }
                    )
                    .padding(.bottom, 28)
                }
                .padding(.horizontal, dynamicTypeSize.isAccessibilitySize ? 18 : 24)
                .padding(.top, 10)
            }
        }
        .onChange(of: selectedTime) { newValue in
            model.setReminderTime(from: newValue)
        }
    }

    private static func date(for localTime: ReminderLocalTime) -> Date {
        var components = Calendar.current.dateComponents(
            [.year, .month, .day],
            from: Date()
        )
        components.hour = localTime.hour
        components.minute = localTime.minute
        return Calendar.current.date(from: components) ?? Date()
    }
}

private struct ReminderPermissionDeniedView: View {
    let isBusy: Bool
    let onOpenSettings: () -> Void
    let onNotNow: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        GardenSurface {
            ScrollView {
                VStack(spacing: 22) {
                    GardenNavigationHeader(
                        title: "Reminders",
                        showsTitleLeaf: false,
                        onBack: onNotNow
                    )

                    GardenMotif(
                        name: "settings_reminder_muted_bell",
                        width: dynamicTypeSize.isAccessibilitySize ? 160 : 190
                    )

                    GardenInfoCard {
                        VStack(spacing: 14) {
                            Image(systemName: "bell.slash.circle")
                                .font(.system(size: 58, weight: .regular))
                                .foregroundStyle(PocketPetColors.coral)
                                .accessibilityHidden(true)

                            Text("Reminders are off")
                                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                                .foregroundStyle(PocketPetColors.evergreen)
                                .multilineTextAlignment(.center)
                                .accessibilityAddTraits(.isHeader)

                            Text("Notifications are turned off for Pocket Pet in iOS Settings.")
                                .font(.system(.title3, design: .rounded))
                                .foregroundStyle(PocketPetColors.evergreen)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)

                            ViewThatFits(in: .horizontal) {
                                permissionStatus(axis: .horizontal)
                                permissionStatus(axis: .vertical)
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(PocketPetColors.cream.opacity(0.82))
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(PocketPetColors.outline, lineWidth: 1)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Permission denied")
                        }
                    }

                    GardenPrimaryButton(
                        title: "Open iOS Settings",
                        isBusy: isBusy,
                        action: onOpenSettings
                    )
                    .accessibilityHint("Opens Pocket Pet notification settings in iOS")

                    Button("Not Now", action: onNotNow)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(PocketPetColors.evergreen)
                        .frame(minWidth: 120, minHeight: 48)
                        .disabled(isBusy)

                    GardenInfoCard {
                        Label(
                            "Your pet keeps growing gently without reminders.",
                            systemImage: "leaf.fill"
                        )
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(PocketPetColors.evergreen)
                    }
                    .padding(.bottom, 28)
                }
                .padding(.horizontal, dynamicTypeSize.isAccessibilitySize ? 18 : 24)
                .padding(.top, 10)
            }
        }
    }

    private func permissionStatus(axis: Axis) -> some View {
        Group {
            if axis == .horizontal {
                HStack {
                    permissionLabel
                    Spacer()
                    deniedLabel
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    permissionLabel
                    deniedLabel
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var permissionLabel: some View {
        Label("Permission", systemImage: "lock.fill")
            .font(.system(.headline, design: .rounded, weight: .semibold))
            .foregroundStyle(PocketPetColors.evergreen)
    }

    private var deniedLabel: some View {
        Label("Denied", systemImage: "nosign")
            .font(.system(.headline, design: .rounded, weight: .bold))
            .foregroundStyle(PocketPetColors.coral)
    }
}
