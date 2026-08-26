import SwiftUI
import UIKit

struct HatchingView: View {
    let petName: String
    let externalError: String?
    let isContinuing: Bool
    let prefersReducedMotion: Bool
    let onCelebrate: () -> Void
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var creatureIsRevealed = false
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
                    revealArtwork(
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
                PocketPetArtwork("sunny_patio_environment")
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 620)
                    .clipped()
                LinearGradient(
                    colors: [.clear, PocketPetColors.cream.opacity(0.75), PocketPetColors.cream],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 420)
                .offset(y: 390)
            }
            .ignoresSafeArea()
            .accessibilityHidden(true)
        }
        .onAppear(perform: onCelebrate)
        .task(id: reduceMotion) {
            creatureIsRevealed = false
            motesAreReleased = false
            presentationIsSettled = false
            await Task.yield()

            if reduceMotion {
                withAnimation(.easeOut(duration: 0.2)) {
                    creatureIsRevealed = true
                }
            } else {
                withAnimation(.easeOut(duration: 0.65)) {
                    creatureIsRevealed = true
                }
                withAnimation(.easeOut(duration: 1.1)) {
                    motesAreReleased = true
                }
            }

            try? await Task.sleep(
                nanoseconds: reduceMotion ? 240_000_000 : 760_000_000
            )
            guard !Task.isCancelled else { return }
            presentationIsSettled = true
            UIAccessibility.post(
                notification: .announcement,
                argument: "Hello, \(petName)! Your little friend is ready."
            )
        }
        .onChange(of: externalError) { _, message in
            guard let message else { return }
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }

    private func revealArtwork(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            if !reduceMotion {
                SeedNestMotes(released: motesAreReleased)
                    .frame(width: min(width, 430), height: height * 0.72)
                    .offset(y: -28)
                    .accessibilityHidden(true)
            }

            PocketPetArtwork("spriglet_child")
                .resizable()
                .scaledToFit()
                .frame(width: min(width * 0.91, 365))
                .opacity(creatureIsRevealed ? 1 : 0)
                .offset(
                    y: reduceMotion
                        ? -42
                        : (creatureIsRevealed ? -42 : -8)
                )
                .accessibilityHidden(true)

            PocketPetArtwork("seed_nest_open_hero")
                .resizable()
                .scaledToFit()
                .frame(width: min(width * 1.08, 430))
                .offset(y: 75)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipped()
    }

    private var messagePanel: some View {
        VStack(spacing: 12) {
            Text("Hello, \(petName)!")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundStyle(PocketPetColors.evergreen)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            Text("Your little friend is ready.")
                .font(.system(.title3, design: .rounded, weight: .medium))
                .foregroundStyle(PocketPetColors.evergreen)
                .multilineTextAlignment(.center)

            if let externalError {
                Text(externalError)
                    .font(.system(.footnote, design: .rounded, weight: .semibold))
                    .foregroundStyle(PocketPetColors.coral)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("Hatching error: \(externalError)")
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
                    ? "capture.hatching.ready"
                    : "capture.hatching.waiting"
            )
            .accessibilityHint("Saves the hatching milestone and opens the habitat")
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
        .background(PocketPetColors.cream.opacity(0.001))
    }

    private func artworkHeight(for availableHeight: CGFloat) -> CGFloat {
        if dynamicTypeSize.isAccessibilitySize { return 480 }
        return min(585, max(520, availableHeight * 0.70))
    }
}

private struct SeedNestMotes: View {
    let released: Bool

    private let motes = [
        SeedNestMote(id: 0, x: -118, y: -80, rotation: -38, scale: 0.72),
        SeedNestMote(id: 1, x: -82, y: 18, rotation: 22, scale: 0.55),
        SeedNestMote(id: 2, x: -42, y: -126, rotation: -12, scale: 0.48),
        SeedNestMote(id: 3, x: 48, y: -112, rotation: 34, scale: 0.52),
        SeedNestMote(id: 4, x: 96, y: -44, rotation: -28, scale: 0.68),
        SeedNestMote(id: 5, x: 126, y: 24, rotation: 46, scale: 0.50),
        SeedNestMote(id: 6, x: -132, y: 50, rotation: 16, scale: 0.42),
        SeedNestMote(id: 7, x: 72, y: 48, rotation: -18, scale: 0.40),
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
                    .rotationEffect(.degrees(mote.rotation + (released ? 26 : 0)))
                    .offset(
                        x: released ? mote.x : mote.x * 0.28,
                        y: released ? mote.y : mote.y * 0.24
                    )
                    .opacity(released ? 0 : 0.88)
            }
        }
    }
}

private struct SeedNestMote: Identifiable {
    let id: Int
    let x: CGFloat
    let y: CGFloat
    let rotation: Double
    let scale: CGFloat
}
