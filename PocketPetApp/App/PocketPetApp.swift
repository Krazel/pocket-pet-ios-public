import SwiftUI

@main
struct PocketPetApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model = PocketPetAppModel()

    var body: some Scene {
        WindowGroup {
            Group {
                switch model.presentation {
                case .loading:
                    LaunchContinuityView()
                case let .welcome(existingName):
                    WelcomeEggView(
                        initialName: existingName ?? "",
                        nameIsPersisted: existingName != nil,
                        externalError: model.onboardingFailure,
                        isHatching: model.isOnboardingInFlight,
                        prefersReducedMotion: model.prefersReducedMotion,
                        onNameChanged: model.clearOnboardingFailure,
                        onHatch: model.hatchPet
                    )
                case let .hatching(name):
                    HatchingView(
                        petName: name,
                        externalError: model.milestoneFailure,
                        isContinuing: model.isMilestoneInFlight,
                        prefersReducedMotion: model.prefersReducedMotion,
                        onCelebrate: model.playMilestoneFeedback,
                        onContinue: model.continueFromHatching
                    )
                case let .adultEvolution(name):
                    AdultEvolutionView(
                        petName: name,
                        externalError: model.milestoneFailure,
                        isContinuing: model.isMilestoneInFlight,
                        prefersReducedMotion: model.prefersReducedMotion,
                        onCelebrate: model.playMilestoneFeedback,
                        onContinue: model.continueFromAdultEvolution
                    )
                case .home:
                    if let habitatState = model.habitatState {
                        HabitatHomeView(
                            state: habitatState,
                            prefersReducedMotion: model.prefersReducedMotion,
                            isCareInFlight: model.isCareInFlight,
                            onCare: model.perform,
                            onPet: model.petCreature,
                            onOpenSettings: model.openSettings
                        )
                    }
                }
            }
            .background(PocketPetColors.cream.ignoresSafeArea())
            .preferredColorScheme(.light)
            .alert(
                "Pocket Pet needs a moment",
                isPresented: Binding(
                    get: { model.appError != nil },
                    set: { isPresented in
                        if !isPresented { model.clearAppError() }
                    }
                )
            ) {
                Button("Try Again", action: model.retryLocalProgress)
                if !model.isInitialLoadBlocked {
                    Button("Not Now", role: .cancel, action: model.clearAppError)
                }
            } message: {
                Text(model.appError ?? "Please try again.")
            }
            .fullScreenCover(
                isPresented: Binding(
                    get: { model.isSettingsPresented },
                    set: { isPresented in
                        if !isPresented { model.dismissSettings() }
                    }
                )
            ) {
                SettingsRootView(
                    model: model,
                    onClose: model.dismissSettings
                )
                .preferredColorScheme(.light)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            model.handleScenePhase(phase)
        }
    }
}

/// Matches the generated cream launch screen while local state resolves.
/// It has no standalone content, controls or accessibility destination.
private struct LaunchContinuityView: View {
    var body: some View {
        PocketPetColors.cream
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}
