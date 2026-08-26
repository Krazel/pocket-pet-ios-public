import SwiftUI
import UIKit

/// Presents the already-persisted Adult milestone. This view never mutates or
/// acknowledges lifecycle state on its own; the app owns that durable command.
struct AdultEvolutionView: View {
    let petName: String
    let externalError: String?
    let isContinuing: Bool
    let prefersReducedMotion: Bool
    let onCelebrate: () -> Void
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var childOpacity = 1.0
    @State private var adultOpacity = 0.0
    @State private var adultScale: CGFloat = 0.96
    @State private var motesAreReleased = false
    @State private var presentationIsSettled = false

    private var reduceMotion: Bool {
        systemReduceMotion || prefersReducedMotion
    }

    var body: some View {
        GeometryReader { proxy in
            let shouldScroll = dynamicTypeSize.isAccessibilitySize
                || proxy.size.height < 740
            ScrollView {
                VStack(spacing: 0) {
                    evolutionArtwork(
                        width: proxy.size.width,
                        height: artworkHeight(for: proxy.size.height)
                    )

                    messagePanel
                        .padding(.horizontal, 30)
                        .padding(.top, 2)
                        .padding(.bottom, 24)
                }
                .frame(minHeight: proxy.size.height, alignment: .top)
            }
            .scrollDisabled(!shouldScroll)
        }
        .background {
            ZStack(alignment: .top) {
                PocketPetColors.cream
                Image("sunny_patio_environment", bundle: .main)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 650)
                    .clipped()
                LinearGradient(
                    colors: [
                        .clear,
                        PocketPetColors.cream.opacity(0.72),
                        PocketPetColors.cream,
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 430)
                .offset(y: 400)
            }
            .ignoresSafeArea()
            .accessibilityHidden(true)
        }
        .onAppear(perform: onCelebrate)
        .task(id: reduceMotion) {
            await playPresentation()
        }
        .onChange(of: externalError) { _, message in
            guard let message else { return }
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }

    private func evolutionArtwork(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 90, style: .continuous)
                .fill(PocketPetColors.yellow.opacity(0.17))
                .frame(width: min(width * 0.68, 290), height: min(width * 0.68, 290))
                .blur(radius: 18)
                .opacity(adultOpacity)
                .accessibilityHidden(true)

            if !reduceMotion {
                AdultEvolutionMotes(released: motesAreReleased)
                    .frame(width: min(width, 430), height: height * 0.75)
                    .offset(y: -12)
                    .accessibilityHidden(true)
            }

            Image("spriglet_child", bundle: .main)
                .resizable()
                .scaledToFit()
                .frame(width: min(width * 0.88, 360))
                .opacity(childOpacity)
                .accessibilityHidden(true)

            Image("spriglet_adult_neutral", bundle: .main)
                .resizable()
                .scaledToFit()
                .frame(width: min(width * 0.91, 375))
                .scaleEffect(adultScale)
                .opacity(adultOpacity)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipped()
    }

    private var messagePanel: some View {
        VStack(spacing: 12) {
            Text("You grew up!")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundStyle(PocketPetColors.evergreen)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            Text("\(petName) is an adult now.")
                .font(.system(.title3, design: .rounded, weight: .medium))
                .foregroundStyle(PocketPetColors.evergreen)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let externalError {
                Text(externalError)
                    .font(.system(.footnote, design: .rounded, weight: .semibold))
                    .foregroundStyle(PocketPetColors.coral)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("Evolution error: \(externalError)")
            }

            Button(action: onContinue) {
                HStack(spacing: 10) {
                    if isContinuing {
                        ProgressView()
                            .tint(.white)
                            .accessibilityHidden(true)
                    }
                    Text(isContinuing ? "Saving..." : "Continue")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 62)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
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
                )
            }
            .buttonStyle(.plain)
            .disabled(isContinuing)
            .accessibilityIdentifier(
                presentationIsSettled
                    ? "capture.adultEvolution.ready"
                    : "capture.adultEvolution.waiting"
            )
            .accessibilityHint("Saves the adult milestone and opens the habitat")
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
        .background(PocketPetColors.cream.opacity(0.001))
    }

    @MainActor
    private func playPresentation() async {
        childOpacity = 1
        adultOpacity = 0
        adultScale = reduceMotion ? 1 : 0.96
        motesAreReleased = false
        presentationIsSettled = false
        await Task.yield()

        if reduceMotion {
            withAnimation(.easeOut(duration: 0.2)) {
                childOpacity = 0
                adultOpacity = 1
            }
        } else {
            withAnimation(.easeInOut(duration: 0.85)) {
                childOpacity = 0
                adultOpacity = 1
                adultScale = 1
            }
            withAnimation(.easeOut(duration: 0.92)) {
                motesAreReleased = true
            }
        }

        try? await Task.sleep(
            nanoseconds: reduceMotion ? 240_000_000 : 900_000_000
        )
        guard !Task.isCancelled else { return }
        presentationIsSettled = true
        UIAccessibility.post(
            notification: .announcement,
            argument: "You grew up! \(petName) is an adult now."
        )
    }

    private func artworkHeight(for availableHeight: CGFloat) -> CGFloat {
        if dynamicTypeSize.isAccessibilitySize { return 480 }
        return min(585, max(520, availableHeight * 0.70))
    }
}

private struct AdultEvolutionMotes: View {
    let released: Bool

    private let motes = [
        AdultEvolutionMote(id: 0, x: -124, y: -82, rotation: -42, scale: 0.72),
        AdultEvolutionMote(id: 1, x: -88, y: 24, rotation: 18, scale: 0.55),
        AdultEvolutionMote(id: 2, x: -46, y: -132, rotation: -10, scale: 0.48),
        AdultEvolutionMote(id: 3, x: 48, y: -120, rotation: 32, scale: 0.52),
        AdultEvolutionMote(id: 4, x: 102, y: -50, rotation: -24, scale: 0.68),
        AdultEvolutionMote(id: 5, x: 132, y: 28, rotation: 44, scale: 0.50),
        AdultEvolutionMote(id: 6, x: -136, y: 56, rotation: 14, scale: 0.42),
        AdultEvolutionMote(id: 7, x: 78, y: 54, rotation: -16, scale: 0.40),
    ]

    var body: some View {
        ZStack {
            ForEach(motes) { mote in
                Image(systemName: mote.id.isMultiple(of: 3) ? "sparkle" : "leaf.fill")
                    .font(.system(size: mote.id.isMultiple(of: 3) ? 8 : 15))
                    .foregroundStyle(
                        mote.id.isMultiple(of: 3)
                            ? PocketPetColors.cream
                            : PocketPetColors.mutedEvergreen
                    )
                    .scaleEffect(mote.scale)
                    .rotationEffect(.degrees(mote.rotation + (released ? 24 : 0)))
                    .offset(
                        x: released ? mote.x : mote.x * 0.22,
                        y: released ? mote.y : mote.y * 0.22
                    )
                    .opacity(released ? 0 : 0.88)
            }
        }
    }
}

private struct AdultEvolutionMote: Identifiable {
    let id: Int
    let x: CGFloat
    let y: CGFloat
    let rotation: Double
    let scale: CGFloat
}
