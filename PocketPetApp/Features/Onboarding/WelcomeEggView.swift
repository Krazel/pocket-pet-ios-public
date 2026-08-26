import PocketPetCore
import SwiftUI
import UIKit

struct WelcomeEggView: View {
    let initialName: String
    let nameIsPersisted: Bool
    let externalError: String?
    let isHatching: Bool
    let prefersReducedMotion: Bool
    let onNameChanged: () -> Void
    let onHatch: (String) -> Void

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @FocusState private var nameFieldIsFocused: Bool
    @State private var petName: String
    @State private var hasEditedName = false
    @State private var hasAttemptedSubmit = false
    @State private var isBreathing = false

    init(
        initialName: String,
        nameIsPersisted: Bool,
        externalError: String?,
        isHatching: Bool,
        prefersReducedMotion: Bool,
        onNameChanged: @escaping () -> Void,
        onHatch: @escaping (String) -> Void
    ) {
        _petName = State(initialValue: initialName)
        self.initialName = initialName
        self.nameIsPersisted = nameIsPersisted
        self.externalError = externalError
        self.isHatching = isHatching
        self.prefersReducedMotion = prefersReducedMotion
        self.onNameChanged = onNameChanged
        self.onHatch = onHatch
    }

    private var reduceMotion: Bool {
        systemReduceMotion || prefersReducedMotion
    }

    private var nameError: String? {
        do {
            _ = try PetName(petName)
            return nil
        } catch let error as PetNameError {
            switch error {
            case .empty:
                return "Enter a name."
            case .tooLong:
                return "Use 12 characters or fewer."
            case .containsControlCharacter:
                return "Use a single-line name."
            }
        } catch {
            return "Enter a valid name."
        }
    }

    private var displayedError: String? {
        externalError ?? ((hasAttemptedSubmit || hasEditedName) ? nameError : nil)
    }

    private var canHatch: Bool {
        nameError == nil && !isHatching
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(spacing: dynamicTypeSize.isAccessibilitySize ? 20 : 14) {
                        Text("Pocket Pet")
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                            .foregroundStyle(PocketPetColors.evergreen)
                            .accessibilityAddTraits(.isHeader)

                        hero(height: heroHeight(for: proxy.size.height))

                        VStack(spacing: 8) {
                            Text("A tiny friend is waiting.")
                                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                                .foregroundStyle(PocketPetColors.evergreen)
                                .multilineTextAlignment(.center)
                                .accessibilityAddTraits(.isHeader)

                            Text("Give your little seed a name,\nthen help it hatch.")
                                .font(.system(.title3, design: .rounded, weight: .medium))
                                .foregroundStyle(PocketPetColors.evergreen.opacity(0.88))
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        nameEntry
                            .id("name-entry")

                        Label("Stays on this iPhone.", systemImage: "lock.fill")
                            .font(.system(.body, design: .rounded, weight: .semibold))
                            .foregroundStyle(PocketPetColors.mutedEvergreen.opacity(0.84))
                            .accessibilityLabel("Your pet's information stays on this iPhone")

                        Button(action: submit) {
                            HStack(spacing: 10) {
                                if isHatching {
                                    ProgressView()
                                        .tint(.white)
                                        .accessibilityHidden(true)
                                }
                                Text(isHatching ? "Hatching..." : "Hatch My Pet")
                                    .font(.system(.title2, design: .rounded, weight: .bold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 62)
                            .background(
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                PocketPetColors.evergreen,
                                                Color(red: 0.14, green: 0.43, blue: 0.22),
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .opacity(canHatch ? 1 : 0.48)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(!canHatch)
                        .accessibilityHint("Creates and hatches your pet on this iPhone")
                        .padding(.top, 2)
                    }
                    .padding(.horizontal, 30)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                    .frame(minHeight: proxy.size.height, alignment: .top)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: nameFieldIsFocused) { _, isFocused in
                    if isFocused {
                        withAnimation(.easeOut(duration: 0.2)) {
                            scrollProxy.scrollTo("name-entry", anchor: .center)
                        }
                    }
                }
            }
        }
        .background {
            PocketPetArtwork("seed_nest_welcome_background")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .accessibilityHidden(true)
        }
        .onChange(of: petName) { _, newName in
            guard !(nameIsPersisted && newName == initialName) else { return }
            hasEditedName = true
            onNameChanged()
        }
        .onChange(of: initialName) { _, savedName in
            guard nameIsPersisted else { return }
            petName = savedName
            hasEditedName = false
            hasAttemptedSubmit = false
        }
        .onChange(of: nameError) { oldError, newError in
            guard hasEditedName, oldError != newError else { return }
            announce(newError)
        }
        .onChange(of: externalError) { _, error in
            announce(error)
        }
    }

    private func hero(height: CGFloat) -> some View {
        PocketPetArtwork("seed_nest_closed_hero")
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .scaleEffect(reduceMotion ? 1 : (isBreathing ? 1.01 : 0.98))
            .offset(y: reduceMotion ? 0 : (isBreathing ? -2 : 1))
            .accessibilityLabel("A little seed egg resting in a leafy moss nest")
            .task(id: reduceMotion) {
                var reset = Transaction()
                reset.disablesAnimations = true
                withTransaction(reset) {
                    isBreathing = false
                }
                guard !reduceMotion else { return }
                await Task.yield()
                guard !Task.isCancelled else { return }
                withAnimation(
                    .easeInOut(duration: 2.4)
                        .repeatForever(autoreverses: true)
                ) {
                    isBreathing = true
                }
            }
    }

    private var nameEntry: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Pet name")
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(PocketPetColors.evergreen)

            TextField("Pip", text: $petName)
                .font(.system(.title2, design: .rounded))
                .foregroundStyle(PocketPetColors.evergreen)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .focused($nameFieldIsFocused)
                .onSubmit(submit)
                .disabled(nameIsPersisted)
                .padding(.horizontal, 17)
                .frame(minHeight: 58)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.white.opacity(0.42))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            displayedError == nil
                                ? PocketPetColors.outline
                                : PocketPetColors.coral,
                            lineWidth: displayedError == nil ? 1.5 : 2
                        )
                }
                .accessibilityLabel("Pet name")
                .accessibilityHint(
                    nameIsPersisted
                        ? "This name was already saved on this iPhone"
                        : "Enter between 1 and 12 characters"
                )

            if let displayedError {
                Text(displayedError)
                    .font(.system(.footnote, design: .rounded, weight: .semibold))
                    .foregroundStyle(PocketPetColors.coral)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("Name error: \(displayedError)")
            }
        }
    }

    private func heroHeight(for availableHeight: CGFloat) -> CGFloat {
        if dynamicTypeSize.isAccessibilitySize { return 230 }
        return min(335, max(275, availableHeight * 0.42))
    }

    private func submit() {
        hasAttemptedSubmit = true
        guard let error = nameError else {
            nameFieldIsFocused = false
            onHatch(petName)
            return
        }
        announce(error)
        nameFieldIsFocused = true
    }

    private func announce(_ message: String?) {
        guard let message else { return }
        UIAccessibility.post(notification: .announcement, argument: message)
    }
}
