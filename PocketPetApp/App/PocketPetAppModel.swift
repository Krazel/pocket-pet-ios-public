import AudioToolbox
import Foundation
import PocketPetCore
import SwiftUI
import UIKit

#if DEBUG
private enum PocketPetVisualScenario: String, CaseIterable {
    case welcomeEmpty = "welcome-empty"
    case welcomeReady = "welcome-ready"
    case hatching
    case childComfortable = "child-comfortable"
    case childNeedsCare = "child-needs-care"
    case childSleeping = "child-sleeping"
    case adultEvolution = "adult-evolution"
    case adultComfortable = "adult-comfortable"
    case adultNeedsCare = "adult-needs-care"
    case adultSleeping = "adult-sleeping"
    case settingsOff = "settings-off"
    case settingsOn = "settings-on"
    case settingsDenied = "settings-denied"

    var opensSettings: Bool {
        switch self {
        case .settingsOff, .settingsOn, .settingsDenied:
            return true
        default:
            return false
        }
    }

    var reminderAuthorization: LocalReminderAuthorization {
        switch self {
        case .settingsOn:
            return .authorized
        case .settingsDenied:
            return .denied
        default:
            return .notDetermined
        }
    }
}

private struct PocketPetVisualClock: PetClock {
    let now: Date
}

private actor PocketPetVisualReminderScheduler: LocalReminderScheduling {
    private let authorization: LocalReminderAuthorization
    private var pendingFireDates: [String: Date] = [:]

    init(authorization: LocalReminderAuthorization) {
        self.authorization = authorization
    }

    func authorizationStatus() async -> LocalReminderAuthorization {
        authorization
    }

    func requestAuthorization() async throws -> LocalReminderAuthorization {
        authorization
    }

    func replaceReminder(
        identifier: String,
        fireDate: Date,
        body _: String
    ) async throws {
        pendingFireDates[identifier] = fireDate
    }

    func cancelReminder(identifier: String) async {
        pendingFireDates[identifier] = nil
    }

    func latestDeliveryDate(identifier _: String) async -> Date? {
        nil
    }

    func pendingReminderFireDate(identifier: String) async -> Date? {
        pendingFireDates[identifier]
    }
}

private struct PocketPetVisualHarness {
    let scenario: PocketPetVisualScenario
    let coordinator: PocketPetStateCoordinator
    let reminderScheduler: any LocalReminderScheduling
}
#endif

enum PocketPetPresentation {
    case loading
    case welcome(existingName: String?)
    case hatching(name: String)
    case adultEvolution(name: String)
    case home
}

enum ReminderEnableOutcome {
    case enabled
    case denied
    case failed
}

/// Main-actor presentation adapter around the serialized Foundation owner.
/// Essential state is committed by `PocketPetStateCoordinator` before this
/// object publishes feedback to SwiftUI or SpriteKit.
@MainActor
final class PocketPetAppModel: ObservableObject {
    @Published private(set) var presentation: PocketPetPresentation = .loading
    @Published private(set) var pet: PetState?
    @Published private(set) var lastReaction: CareAction?
    @Published private(set) var reactionSequence = 0
    @Published private(set) var petTapSequence = 0
    @Published private(set) var prefersReducedMotion = false
    @Published private(set) var isCareInFlight = false
    @Published private(set) var isOnboardingInFlight = false
    @Published private(set) var isMilestoneInFlight = false
    @Published private(set) var onboardingFailure: String?
    @Published private(set) var milestoneFailure: String?
    @Published private(set) var preferences = PocketPetPreferences.defaults
    @Published private(set) var reminderInvitationIsEligible = false
    @Published private(set) var notificationAuthorization: LocalReminderAuthorization = .notDetermined
    @Published private(set) var isSettingsPresented = false
    @Published private(set) var isSettingsOperationInFlight = false
    @Published private(set) var settingsError: String?
    @Published private(set) var appError: String?

    private let coordinator: PocketPetStateCoordinator
    private let reminderScheduler: any LocalReminderScheduling
    private var hasBootstrapped = false
    private var stateOperationTail: Task<Void, Never>?
    private var reactionClearTask: Task<Void, Never>?
    private var reminderTimeUpdateTask: Task<Void, Never>?
    private var shouldEnableAfterSystemSettings = false

    #if DEBUG
    private let visualScenario: PocketPetVisualScenario?
    private let usesStaticVisualCapture: Bool
    #endif

    private static let reminderIdentifier = "pocket-pet.gentle-reminder"

    init(
        reminderScheduler: any LocalReminderScheduling = UserNotificationReminderScheduler()
    ) {
        #if DEBUG
        if let scenario = Self.requestedVisualScenario() {
            do {
                let harness = try Self.makeVisualHarness(for: scenario)
                coordinator = harness.coordinator
                self.reminderScheduler = harness.reminderScheduler
                visualScenario = harness.scenario
                usesStaticVisualCapture = ProcessInfo.processInfo.arguments
                    .contains("--visual-static")
            } catch {
                fatalError(
                    "Pocket Pet visual harness failed for \(scenario.rawValue): \(error)"
                )
            }
        } else {
            coordinator = Self.makeCoordinator()
            self.reminderScheduler = reminderScheduler
            visualScenario = nil
            usesStaticVisualCapture = false
        }
        #else
        coordinator = Self.makeCoordinator()
        self.reminderScheduler = reminderScheduler
        #endif
        Task { await bootstrap() }
    }

    var habitatState: HabitatViewState? {
        guard case .home = presentation, let pet else { return nil }
        return HabitatViewState(
            pet: pet,
            reaction: lastReaction,
            reactionSequence: reactionSequence,
            petTapSequence: petTapSequence
        )
    }

    var isInitialLoadBlocked: Bool {
        if case .loading = presentation { return true }
        return false
    }

    private var currentDate: Date {
        #if DEBUG
        if visualScenario != nil { return Self.visualNow }
        #endif
        return Date()
    }

    func openSettings() {
        guard case .home = presentation else { return }
        isSettingsPresented = true
        refreshNotificationAuthorization()
    }

    func dismissSettings() {
        guard isSettingsPresented else { return }
        isSettingsPresented = false
        settingsError = nil
        // Settings is a full-screen cover, so spending time there does not
        // necessarily change ScenePhase. Reconcile before Home is revealed.
        refreshNotificationAuthorization()
    }

    func clearSettingsError() {
        settingsError = nil
    }

    func clearAppError() {
        appError = nil
    }

    func retryLocalProgress() {
        appError = nil
        enqueueStateOperation { [weak self] in
            guard let self else { return }
            do {
                let snapshot: PocketPetSnapshot
                if case .loading = presentation {
                    snapshot = try await coordinator.startForegroundSession()
                } else {
                    snapshot = try await coordinator.refresh()
                }
                let reconciled = await synchronizeReminder(using: snapshot)
                apply(reconciled)
            } catch {
                appError = "Local progress still couldn't be loaded. Your saved files were left untouched."
            }
        }
    }

    func setSoundEnabled(_ isEnabled: Bool) {
        updatePreference(.setSoundEnabled(isEnabled))
    }

    func setReduceMotionEnabled(_ isEnabled: Bool) {
        updatePreference(.setReduceMotionEnabled(isEnabled))
    }

    func markReminderInvitationShown() {
        guard !preferences.reminderInvitationShown else { return }
        updatePreference(.markReminderInvitationShown)
    }

    func enableReminders(
        completion: @escaping @MainActor (ReminderEnableOutcome) -> Void
    ) {
        guard !isSettingsOperationInFlight else { return }
        isSettingsOperationInFlight = true
        settingsError = nil

        enqueueStateOperation { [weak self] in
            guard let self else { return }
            defer { isSettingsOperationInFlight = false }
            do {
                var snapshot = try await coordinator.updatePreferences(
                    .markReminderInvitationShown
                )
                var authorization = await reminderScheduler.authorizationStatus()
                if authorization == .notDetermined {
                    authorization = try await reminderScheduler.requestAuthorization()
                }
                notificationAuthorization = authorization

                guard authorization == .authorized else {
                    snapshot = try await coordinator.updatePreferences(
                        .setRemindersEnabled(false)
                    )
                    snapshot = try await cancelReminderAndClearFutureMetadata(
                        using: snapshot,
                        now: currentDate
                    )
                    apply(snapshot)
                    completion(.denied)
                    return
                }

                snapshot = try await coordinator.updatePreferences(
                    .setRemindersEnabled(true)
                )
                snapshot = await synchronizeReminder(using: snapshot)
                apply(snapshot)
                completion(
                    snapshot.preferences.remindersEnabled && settingsError == nil
                        ? .enabled
                        : .failed
                )
            } catch {
                settingsError = "Reminders couldn't be enabled. Please try again."
                completion(.failed)
            }
        }
    }

    func disableReminders(completion: (@MainActor () -> Void)? = nil) {
        guard !isSettingsOperationInFlight else { return }
        isSettingsOperationInFlight = true
        settingsError = nil

        // Cancellation does not wait behind persistence or presentation work.
        let persistedIdentifier = preferences.localNotificationIdentifier
        Task {
            await cancelPendingReminder(
                persistedIdentifier: persistedIdentifier
            )
        }

        enqueueStateOperation { [weak self] in
            guard let self else { return }
            defer { isSettingsOperationInFlight = false }
            do {
                var snapshot = try await coordinator.updatePreferences(
                    .setRemindersEnabled(false)
                )
                snapshot = try await cancelReminderAndClearFutureMetadata(
                    using: snapshot,
                    now: currentDate
                )
                apply(snapshot)
                completion?()
            } catch {
                settingsError = "Reminders couldn't be turned off. Please try again."
            }
        }
    }

    func setReminderTime(from date: Date) {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        guard let hour = components.hour,
              let minute = components.minute,
              let localTime = try? ReminderLocalTime(hour: hour, minute: minute) else {
            return
        }

        reminderTimeUpdateTask?.cancel()
        reminderTimeUpdateTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled, let self else { return }
            updatePreference(.setReminderTime(localTime), reschedule: true)
        }
    }

    func openSystemNotificationSettings() {
        guard let url = URL(
            string: UIApplication.openNotificationSettingsURLString
        ) else {
            return
        }
        UIApplication.shared.open(url, options: [:]) { [weak self] didOpen in
            guard didOpen else { return }
            Task { @MainActor in
                self?.shouldEnableAfterSystemSettings = true
            }
        }
    }

    func refreshNotificationAuthorization() {
        enqueueStateOperation { [weak self] in
            guard let self else { return }
            let snapshot: PocketPetSnapshot
            do {
                snapshot = try await coordinator.refresh()
            } catch {
                if isSettingsPresented {
                    settingsError = "Notification status couldn't be refreshed."
                } else {
                    appError = "Local progress couldn't be refreshed after Settings. The last saved state is still safe."
                }
                return
            }
            let reconciled = await synchronizeReminder(using: snapshot)
            apply(reconciled)
        }
    }

    func hatchPet(named rawName: String) {
        guard !isOnboardingInFlight else { return }

        let validatedName: PetName
        do {
            validatedName = try PetName(rawName)
        } catch {
            onboardingFailure = Self.validationMessage(for: error)
            return
        }

        isOnboardingInFlight = true
        onboardingFailure = nil
        enqueueStateOperation { [weak self] in
            guard let self else { return }
            defer { isOnboardingInFlight = false }
            do {
                let snapshot: PocketPetSnapshot
                if let pet, pet.stage == .egg {
                    // A saved egg can exist if the app was interrupted between
                    // the two durable writes. Its persisted name is canonical.
                    let result = try await coordinator.hatch()
                    snapshot = result.snapshot
                } else {
                    _ = try await coordinator.createEgg(named: validatedName.value)
                    let result = try await coordinator.hatch()
                    snapshot = result.snapshot
                }
                apply(snapshot)
            } catch {
                // Refresh exposes a successfully saved egg after a partial
                // transition, so the user can retry without losing progress.
                if let snapshot = try? await coordinator.refresh() {
                    apply(snapshot)
                }
                onboardingFailure = "We couldn't save your pet. Please try again."
            }
        }
    }

    func clearOnboardingFailure() {
        onboardingFailure = nil
    }

    func continueFromHatching() {
        guard !isMilestoneInFlight else { return }
        isMilestoneInFlight = true
        milestoneFailure = nil
        enqueueStateOperation { [weak self] in
            guard let self else { return }
            defer { isMilestoneInFlight = false }
            do {
                let result = try await coordinator.acknowledgeMilestone(.hatching)
                // The coordinator returns only after the acknowledgement and
                // resulting Home state have been saved locally.
                apply(result.snapshot)
            } catch {
                milestoneFailure = "We couldn't finish hatching. Please try again."
            }
        }
    }

    func continueFromAdultEvolution() {
        guard !isMilestoneInFlight else { return }
        isMilestoneInFlight = true
        milestoneFailure = nil
        enqueueStateOperation { [weak self] in
            guard let self else { return }
            defer { isMilestoneInFlight = false }
            do {
                let result = try await coordinator.acknowledgeMilestone(
                    .adultEvolution
                )
                apply(result.snapshot)
            } catch {
                milestoneFailure = "We couldn't finish growing up. Please try again."
            }
        }
    }

    func perform(_ action: CareAction) {
        guard !isCareInFlight, case .home = presentation else { return }
        isCareInFlight = true
        enqueueStateOperation { [weak self] in
            guard let self else { return }
            defer { isCareInFlight = false }
            do {
                let result = try await coordinator.performCareAction(action)
                let snapshot = await synchronizeReminder(using: result.snapshot)
                apply(snapshot)
                if case .home = presentation {
                    playCareFeedback()
                    showTransientReaction(action)
                }
            } catch let error as PocketPetCoordinatorError {
                handleCoordinatorError(error)
            } catch {
                appError = "That care wasn't saved. Your previous progress is safe; please try again."
            }
        }
    }

    func petCreature() {
        guard pet != nil, case .home = presentation else { return }
        petTapSequence += 1
    }

    func handleScenePhase(_ phase: ScenePhase) {
        guard hasBootstrapped else { return }
        enqueueStateOperation { [weak self] in
            guard let self else { return }
            do {
                var snapshot: PocketPetSnapshot
                switch phase {
                case .active:
                    snapshot = try await coordinator.startForegroundSession()
                    if shouldEnableAfterSystemSettings {
                        shouldEnableAfterSystemSettings = false
                        let authorization = await reminderScheduler.authorizationStatus()
                        if authorization == .authorized {
                            snapshot = try await coordinator.updatePreferences(
                                .setRemindersEnabled(true)
                            )
                        }
                    }
                case .background:
                    snapshot = try await coordinator.endForegroundSession()
                case .inactive:
                    return
                @unknown default:
                    return
                }
                let reconciled = await synchronizeReminder(using: snapshot)
                apply(reconciled)
            } catch {
                appError = "Local progress couldn't be refreshed. The last saved state is still safe."
            }
        }
    }

    /// App-facing state changes are queued in request order. The domain actor
    /// serializes writes, while this tail also serializes the snapshots that
    /// are published back to SwiftUI after suspension points.
    private func enqueueStateOperation(
        _ operation: @escaping @MainActor () async -> Void
    ) {
        let previous = stateOperationTail
        stateOperationTail = Task { @MainActor in
            await previous?.value
            guard !Task.isCancelled else { return }
            await operation()
        }
    }

    private func updatePreference(
        _ command: PocketPetPreferenceCommand,
        reschedule: Bool = false
    ) {
        guard !isSettingsOperationInFlight else { return }
        isSettingsOperationInFlight = true
        settingsError = nil
        enqueueStateOperation { [weak self] in
            guard let self else { return }
            defer { isSettingsOperationInFlight = false }
            do {
                var snapshot = try await coordinator.updatePreferences(command)
                if reschedule {
                    snapshot = await synchronizeReminder(using: snapshot)
                }
                apply(snapshot)
            } catch {
                settingsError = "That setting couldn't be saved. Please try again."
            }
        }
    }

    /// Replaces the single pending request from current persisted state. It
    /// never asks for permission; only `enableReminders` may do that after the
    /// user has seen the explainer and tapped its primary action.
    private func synchronizeReminder(
        using initialSnapshot: PocketPetSnapshot
    ) async -> PocketPetSnapshot {
        var snapshot = initialSnapshot
        let authorization = await reminderScheduler.authorizationStatus()
        notificationAuthorization = authorization
        let now = currentDate

        do {
            guard snapshot.preferences.remindersEnabled else {
                return try await cancelReminderAndClearFutureMetadata(
                    using: snapshot,
                    now: now
                )
            }

            guard authorization == .authorized else {
                snapshot = try await coordinator.updatePreferences(
                    .setRemindersEnabled(false)
                )
                return try await cancelReminderAndClearFutureMetadata(
                    using: snapshot,
                    now: now
                )
            }

            let latestDelivery = await reminderScheduler.latestDeliveryDate(
                identifier: Self.reminderIdentifier
            )
            let existingPendingFire = await reminderScheduler.pendingReminderFireDate(
                identifier: Self.reminderIdentifier
            )
            let deliveryBoundary = ReminderDeliveryBoundary()
            let earliestFire = deliveryBoundary.earliestPermittedFireDate(
                now: now,
                recordedFireDate: snapshot.preferences.lastReminderFireDate,
                latestVisibleDeliveryDate: latestDelivery
            )

            guard let pet = snapshot.pet else {
                return try await cancelReminderAndClearFutureMetadata(
                    using: snapshot,
                    now: now
                )
            }

            let projection = ReminderProjection()
            var fireDate = projection.nextReminderDate(
                for: pet,
                after: now,
                localTime: snapshot.preferences.reminderTime
            )
            if let candidate = fireDate,
               !deliveryBoundary.permits(
                   fireDate: candidate,
                   earliestPermittedFireDate: earliestFire
               ) {
                // Projection searches strictly after its start. A millisecond
                // epsilon keeps an exactly-24-hour candidate eligible while a
                // 23-hour DST interval remains excluded by the boundary.
                fireDate = projection.nextReminderDate(
                    for: pet,
                    after: earliestFire.addingTimeInterval(-0.001),
                    localTime: snapshot.preferences.reminderTime
                )
            }

            guard let fireDate else {
                return try await cancelReminderAndClearFutureMetadata(
                    using: snapshot,
                    now: now
                )
            }

            if let existingPendingFire,
               Self.reminderDatesMatch(existingPendingFire, fireDate) {
                if let persistedIdentifier = snapshot.preferences
                    .localNotificationIdentifier,
                   persistedIdentifier != Self.reminderIdentifier {
                    await reminderScheduler.cancelReminder(
                        identifier: persistedIdentifier
                    )
                }
                if let recordedFire = snapshot.preferences.lastReminderFireDate {
                    if !Self.reminderDatesMatch(recordedFire, fireDate) {
                        snapshot = try await coordinator.updatePreferences(
                            .setLastReminderFireDate(fireDate)
                        )
                    }
                } else {
                    snapshot = try await coordinator.updatePreferences(
                        .setLastReminderFireDate(fireDate)
                    )
                }
                if snapshot.preferences.localNotificationIdentifier
                    != Self.reminderIdentifier {
                    snapshot = try await coordinator.updatePreferences(
                        .setLocalNotificationIdentifier(Self.reminderIdentifier)
                    )
                }
                return snapshot
            }

            if let persistedIdentifier = snapshot.preferences.localNotificationIdentifier,
               persistedIdentifier != Self.reminderIdentifier {
                await reminderScheduler.cancelReminder(
                    identifier: persistedIdentifier
                )
            }
            try await reminderScheduler.replaceReminder(
                identifier: Self.reminderIdentifier,
                fireDate: fireDate,
                body: ReminderProjection.privacyPreservingBody
            )
            snapshot = try await coordinator.updatePreferences(
                .setLastReminderFireDate(fireDate)
            )
            if snapshot.preferences.localNotificationIdentifier
                != Self.reminderIdentifier {
                snapshot = try await coordinator.updatePreferences(
                    .setLocalNotificationIdentifier(Self.reminderIdentifier)
                )
            }
            return snapshot
        } catch {
            await cancelPendingReminder(
                persistedIdentifier: snapshot.preferences.localNotificationIdentifier
            )
            settingsError = "A local reminder couldn't be scheduled."

            do {
                snapshot = try await coordinator.updatePreferences(
                    .setRemindersEnabled(false)
                )
                snapshot = try await cancelReminderAndClearFutureMetadata(
                    using: snapshot,
                    now: now
                )
            } catch {
                // Keep the last saved snapshot visible. The fixed identifier is
                // already cancelled, so no orphan request remains pending.
            }
            return snapshot
        }
    }

    private func cancelReminderAndClearFutureMetadata(
        using initialSnapshot: PocketPetSnapshot,
        now: Date
    ) async throws -> PocketPetSnapshot {
        var snapshot = initialSnapshot
        await cancelPendingReminder(
            persistedIdentifier: snapshot.preferences.localNotificationIdentifier
        )
        if snapshot.preferences.localNotificationIdentifier != nil {
            snapshot = try await coordinator.updatePreferences(
                .setLocalNotificationIdentifier(nil)
            )
        }
        if let recordedFire = snapshot.preferences.lastReminderFireDate,
           recordedFire > now {
            snapshot = try await coordinator.updatePreferences(
                .setLastReminderFireDate(nil)
            )
        }
        return snapshot
    }

    private static func reminderDatesMatch(_ lhs: Date, _ rhs: Date) -> Bool {
        abs(lhs.timeIntervalSince(rhs)) < 0.5
    }

    private func cancelPendingReminder(
        persistedIdentifier: String?
    ) async {
        await reminderScheduler.cancelReminder(
            identifier: Self.reminderIdentifier
        )
        if let persistedIdentifier,
           persistedIdentifier != Self.reminderIdentifier {
            await reminderScheduler.cancelReminder(identifier: persistedIdentifier)
        }
    }

    private func bootstrap() async {
        defer { hasBootstrapped = true }
        do {
            var snapshot = try await coordinator.startForegroundSession()

            snapshot = await synchronizeReminder(using: snapshot)
            apply(snapshot)

            #if DEBUG
            if visualScenario?.opensSettings == true,
               snapshot.destination == .home {
                isSettingsPresented = true
            }
            #endif
        } catch {
            appError = "Pocket Pet couldn't load local progress. Your saved files were left untouched."
        }
    }

    private func apply(_ snapshot: PocketPetSnapshot) {
        preferences = snapshot.preferences
        reminderInvitationIsEligible = snapshot.reminderInvitationIsEligible
        prefersReducedMotion = snapshot.preferences.reduceMotionEnabled
        #if DEBUG
        if usesStaticVisualCapture
            || ProcessInfo.processInfo.arguments.contains(
                "--runtime-qa-system-reduce-motion"
            ) {
            // Keeps screenshot frames deterministic without changing the
            // persisted Reduce Motion preference shown in Settings.
            prefersReducedMotion = true
        }
        #endif
        pet = snapshot.pet

        guard let state = snapshot.pet else {
            clearReaction()
            presentation = .welcome(existingName: nil)
            return
        }

        switch snapshot.destination {
        case .onboarding where state.stage == .egg:
            clearReaction()
            presentation = .welcome(existingName: state.name)
        case .milestone(.hatching):
            clearReaction()
            presentation = .hatching(name: state.name)
        case .milestone(.adultEvolution):
            clearReaction()
            presentation = .adultEvolution(name: state.name)
        case .home where state.stage != .egg:
            presentation = .home
        default:
            clearReaction()
            appError = "Pocket Pet found an unexpected local state. Your saved files were left untouched."
            presentation = state.stage == .egg
                ? .welcome(existingName: state.name)
                : .home
        }
    }

    private func showTransientReaction(_ action: CareAction) {
        reactionClearTask?.cancel()
        lastReaction = action
        reactionSequence += 1
        let visibilityNanoseconds: UInt64
        #if DEBUG
        // XCTest waits for the application to become idle after a tap. Keep the
        // approved response frame observable only in the deterministic capture
        // harness; production feedback still expires after exactly one second.
        visibilityNanoseconds = (
            usesStaticVisualCapture
                || ProcessInfo.processInfo.arguments.contains(
                    "--runtime-qa-extended-reactions"
                )
        )
            ? 5_000_000_000
            : 1_000_000_000
        #else
        visibilityNanoseconds = 1_000_000_000
        #endif
        reactionClearTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: visibilityNanoseconds)
            guard !Task.isCancelled else { return }
            self?.lastReaction = nil
        }
    }

    func playMilestoneFeedback() {
        if preferences.soundEnabled {
            AudioServicesPlaySystemSound(SystemSoundID(1104))
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func playCareFeedback() {
        if preferences.soundEnabled {
            // A short system tick keeps the MVP asset-free, local and respects
            // the device's current volume and silent-mode behavior.
            AudioServicesPlaySystemSound(SystemSoundID(1104))
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func clearReaction() {
        reactionClearTask?.cancel()
        reactionClearTask = nil
        lastReaction = nil
    }

    private func handleCoordinatorError(_ error: PocketPetCoordinatorError) {
        clearReaction()
        switch error {
        case let .milestonePending(milestone):
            guard let name = pet?.name else {
                appError = "Local progress needs recovery. Your saved files were left untouched."
                return
            }
            switch milestone {
            case .hatching:
                presentation = .hatching(name: name)
            case .adultEvolution:
                presentation = .adultEvolution(name: name)
            }
        case .hatchingRequired:
            presentation = .welcome(existingName: pet?.name)
        case .noPet, .petAlreadyExists, .milestoneNotPending(_):
            appError = "Local progress needs recovery. Your saved files were left untouched."
        }
    }

    private static func validationMessage(for error: Error) -> String {
        guard let nameError = error as? PetNameError else {
            return "Enter a valid name."
        }
        switch nameError {
        case .empty:
            return "Enter a name."
        case .tooLong:
            return "Use 12 characters or fewer."
        case .containsControlCharacter:
            return "Use a single-line name."
        }
    }

    private static func makeCoordinator() -> PocketPetStateCoordinator {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        let folder = base.appendingPathComponent("PocketPet", isDirectory: true)
        let petStore = JSONFilePetStateStore(
            fileURL: folder.appendingPathComponent("pet-state.json")
        )
        let preferencesStore = JSONFilePocketPetPreferencesStore(
            fileURL: folder.appendingPathComponent("preferences.json")
        )
        return PocketPetStateCoordinator(
            petStore: petStore,
            preferencesStore: preferencesStore
        )
    }

    #if DEBUG
    private static let visualNow = Date(timeIntervalSince1970: 1_735_689_600)

    private static func requestedVisualScenario() -> PocketPetVisualScenario? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flagIndex = arguments.firstIndex(of: "--visual-state") else {
            return nil
        }
        let valueIndex = arguments.index(after: flagIndex)
        guard arguments.indices.contains(valueIndex),
              let scenario = PocketPetVisualScenario(rawValue: arguments[valueIndex]) else {
            let supported = PocketPetVisualScenario.allCases
                .map(\.rawValue)
                .joined(separator: ", ")
            fatalError("--visual-state requires one of: \(supported)")
        }
        return scenario
    }

    private static func makeVisualHarness(
        for scenario: PocketPetVisualScenario
    ) throws -> PocketPetVisualHarness {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory.appendingPathComponent(
            "PocketPetVisualHarness",
            isDirectory: true
        )
        let folder = root.appendingPathComponent(
            scenario.rawValue,
            isDirectory: true
        )
        if fileManager.fileExists(atPath: folder.path) {
            try fileManager.removeItem(at: folder)
        }
        try fileManager.createDirectory(
            at: folder,
            withIntermediateDirectories: true
        )

        let petStore = JSONFilePetStateStore(
            fileURL: folder.appendingPathComponent("pet-state.json")
        )
        let preferencesStore = JSONFilePocketPetPreferencesStore(
            fileURL: folder.appendingPathComponent("preferences.json")
        )
        if let pet = makeVisualPet(for: scenario) {
            try petStore.save(pet)
        }
        try preferencesStore.save(makeVisualPreferences(for: scenario))

        let coordinator = PocketPetStateCoordinator(
            engine: PetEngine(clock: PocketPetVisualClock(now: visualNow)),
            petStore: petStore,
            preferencesStore: preferencesStore
        )
        let scheduler = PocketPetVisualReminderScheduler(
            authorization: scenario.reminderAuthorization
        )
        return PocketPetVisualHarness(
            scenario: scenario,
            coordinator: coordinator,
            reminderScheduler: scheduler
        )
    }

    private static func makeVisualPreferences(
        for scenario: PocketPetVisualScenario
    ) -> PocketPetPreferences {
        let reduceMotionEnabled = ProcessInfo.processInfo.arguments.contains(
            "--runtime-qa-local-reduce-motion"
        )
        switch scenario {
        case .settingsOn:
            return PocketPetPreferences(
                reduceMotionEnabled: reduceMotionEnabled,
                remindersEnabled: true,
                reminderInvitationShown: true,
                foregroundSessionCount: 3
            )
        case .settingsOff, .settingsDenied:
            return PocketPetPreferences(
                reduceMotionEnabled: reduceMotionEnabled,
                remindersEnabled: false,
                reminderInvitationShown: true,
                foregroundSessionCount: 3
            )
        default:
            return PocketPetPreferences(
                reduceMotionEnabled: reduceMotionEnabled
            )
        }
    }

    private static func makeVisualPet(
        for scenario: PocketPetVisualScenario
    ) -> PetState? {
        if scenario == .welcomeEmpty {
            return nil
        }

        guard let petID = UUID(
            uuidString: "50504950-0000-4000-8000-000000000001"
        ) else {
            preconditionFailure("The visual harness pet UUID must be valid.")
        }

        let comfortableNeeds = PetNeeds(
            hunger: 20,
            happiness: 80,
            energy: 80,
            cleanliness: 80
        )
        let needsCare = PetNeeds(
            hunger: 82,
            happiness: 24,
            energy: 20,
            cleanliness: 26
        )
        let sleepingNeeds = PetNeeds(
            hunger: 34,
            happiness: 72,
            energy: 42,
            cleanliness: 68
        )

        if scenario == .welcomeReady {
            return PetState(
                id: petID,
                name: "Pip",
                createdAt: visualNow,
                lastReconciledAt: visualNow,
                stage: .egg,
                needs: comfortableNeeds
            )
        }

        let usesAdult = scenario == .adultEvolution
            || scenario == .adultComfortable
            || scenario == .adultNeedsCare
            || scenario == .adultSleeping
        let isSleeping = scenario == .childSleeping
            || scenario == .adultSleeping
        let selectedNeeds: PetNeeds
        switch scenario {
        case .childNeedsCare, .adultNeedsCare:
            selectedNeeds = needsCare
        case .childSleeping, .adultSleeping:
            selectedNeeds = sleepingNeeds
        default:
            selectedNeeds = comfortableNeeds
        }

        if usesAdult {
            let createdAt = visualNow.addingTimeInterval(-96 * 60 * 60)
            let hatchedAt = visualNow.addingTimeInterval(-80 * 60 * 60)
            let careMarks = [
                hatchedAt.addingTimeInterval(6 * 60 * 60),
                hatchedAt.addingTimeInterval(30 * 60 * 60),
                hatchedAt.addingTimeInterval(54 * 60 * 60),
            ]
            return PetState(
                id: petID,
                name: "Pip",
                createdAt: createdAt,
                lastReconciledAt: visualNow,
                stage: .adult,
                hatchedAt: hatchedAt,
                childAgeSeconds: 80 * 60 * 60,
                needs: selectedNeeds,
                isResting: isSleeping,
                restStartedAt: isSleeping ? visualNow : nil,
                careMarks: careMarks,
                completedCareActions: 3,
                unseenMilestones: scenario == .adultEvolution
                    ? [.adultEvolution]
                    : []
            )
        }

        let createdAt = visualNow.addingTimeInterval(-24 * 60 * 60)
        let hatchedAt = visualNow.addingTimeInterval(-12 * 60 * 60)
        return PetState(
            id: petID,
            name: "Pip",
            createdAt: createdAt,
            lastReconciledAt: visualNow,
            stage: .child,
            hatchedAt: hatchedAt,
            childAgeSeconds: 12 * 60 * 60,
            needs: selectedNeeds,
            isResting: isSleeping,
            restStartedAt: isSleeping ? visualNow : nil,
            unseenMilestones: scenario == .hatching ? [.hatching] : []
        )
    }
    #endif
}
