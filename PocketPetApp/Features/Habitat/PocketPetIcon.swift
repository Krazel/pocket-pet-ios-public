import SwiftUI

enum PocketPetIcon: Int, CaseIterable {
    case hunger = 0
    case happiness = 1
    case energy = 2
    case cleanliness = 3
    case feed = 4
    case play = 5
    case rest = 6
    case clean = 7

    var accessibilityLabel: String {
        switch self {
        case .hunger: "Hunger"
        case .happiness: "Happiness"
        case .energy: "Energy"
        case .cleanliness: "Cleanliness"
        case .feed: "Feed"
        case .play: "Play"
        case .rest: "Rest"
        case .clean: "Clean"
        }
    }

    @ViewBuilder
    var view: some View {
        switch self {
        case .happiness:
            generatedImage(named: "icon_heart")
        case .play:
            generatedImage(named: "icon_ball")
        case .hunger:
            LeafIcon(role: .need)
                .accessibilityHidden(true)
        case .feed:
            LeafIcon(role: .action)
                .accessibilityHidden(true)
        case .energy:
            EnergyIcon()
                .accessibilityHidden(true)
        case .cleanliness:
            DropIcon(role: .need)
                .accessibilityHidden(true)
        case .clean:
            DropIcon(role: .action)
                .accessibilityHidden(true)
        case .rest:
            RestIcon()
                .accessibilityHidden(true)
        }
    }

    private func generatedImage(named name: String) -> some View {
        Image(name, bundle: .main)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .accessibilityHidden(true)
    }
}

private enum IconRole: Equatable {
    case need
    case action
}

private struct LeafIcon: View {
    let role: IconRole

    var body: some View {
        ZStack {
            LeafShape()
                .fill(
                    LinearGradient(
                        colors: [.green.opacity(0.92), PocketPetColors.mutedEvergreen],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    LeafShape().stroke(
                        PocketPetColors.evergreen,
                        lineWidth: role == .need ? 1.8 : 2.8
                    )
                )
            LeafVeinShape()
                .stroke(PocketPetColors.evergreen.opacity(0.72), style: .init(lineWidth: 1.7, lineCap: .round))
        }
        .padding(role == .need ? 7 : 3)
        .rotationEffect(.degrees(role == .need ? -8 : -13))
    }
}

private struct LeafShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.12, y: rect.maxY * 0.86))
        path.addCurve(
            to: CGPoint(x: rect.maxX * 0.88, y: rect.minY + rect.height * 0.12),
            control1: CGPoint(x: rect.minX + rect.width * 0.10, y: rect.minY + rect.height * 0.28),
            control2: CGPoint(x: rect.maxX * 0.62, y: rect.minY + rect.height * 0.06)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.12, y: rect.maxY * 0.86),
            control1: CGPoint(x: rect.maxX * 0.94, y: rect.maxY * 0.56),
            control2: CGPoint(x: rect.minX + rect.width * 0.50, y: rect.maxY * 0.94)
        )
        path.closeSubpath()
        return path
    }
}

private struct LeafVeinShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.08, y: rect.maxY * 0.96))
        path.addLine(to: CGPoint(x: rect.maxX * 0.74, y: rect.minY + rect.height * 0.28))
        path.move(to: CGPoint(x: rect.maxX * 0.43, y: rect.maxY * 0.55))
        path.addLine(to: CGPoint(x: rect.maxX * 0.42, y: rect.minY + rect.height * 0.30))
        path.move(to: CGPoint(x: rect.maxX * 0.54, y: rect.maxY * 0.44))
        path.addLine(to: CGPoint(x: rect.maxX * 0.77, y: rect.maxY * 0.43))
        return path
    }
}

private struct EnergyIcon: View {
    var body: some View {
        LightningShape()
            .fill(
                LinearGradient(
                    colors: [.yellow, PocketPetColors.yellow],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(LightningShape().stroke(.orange, lineWidth: 2.4))
            .padding(7)
    }
}

private struct LightningShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX * 0.58, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.18, y: rect.maxY * 0.56))
        path.addLine(to: CGPoint(x: rect.maxX * 0.47, y: rect.maxY * 0.56))
        path.addLine(to: CGPoint(x: rect.maxX * 0.38, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX * 0.84, y: rect.maxY * 0.40))
        path.addLine(to: CGPoint(x: rect.maxX * 0.55, y: rect.maxY * 0.40))
        path.closeSubpath()
        return path
    }
}

private struct DropIcon: View {
    let role: IconRole

    var body: some View {
        DropShape()
            .fill(
                LinearGradient(
                    colors: [.cyan.opacity(0.75), PocketPetColors.blue],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                DropShape().stroke(
                    Color(red: 0.08, green: 0.40, blue: 0.56),
                    lineWidth: role == .need ? 1.8 : 2.8
                )
            )
            .overlay(alignment: .topLeading) {
                Capsule()
                    .fill(.white.opacity(0.72))
                    .frame(
                        width: role == .need ? 4 : 7,
                        height: role == .need ? 11 : 17
                    )
                    .rotationEffect(.degrees(28))
                    .offset(x: 16, y: 16)
            }
            .padding(role == .need ? 8 : 4)
    }
}

private struct DropShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY),
            control1: CGPoint(x: rect.maxX * 0.88, y: rect.maxY * 0.40),
            control2: CGPoint(x: rect.maxX * 0.86, y: rect.maxY)
        )
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.minY),
            control1: CGPoint(x: rect.minX + rect.width * 0.14, y: rect.maxY),
            control2: CGPoint(x: rect.minX + rect.width * 0.12, y: rect.maxY * 0.40)
        )
        path.closeSubpath()
        return path
    }
}

private struct RestIcon: View {
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: "moon.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple.opacity(0.55), .indigo.opacity(0.70)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(Image(systemName: "moon").resizable().scaledToFit().foregroundStyle(.indigo))
            VStack(spacing: -2) {
                Text("Z")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                Text("Z")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .offset(x: 7)
            }
            .foregroundStyle(.indigo)
            .offset(x: 6, y: -4)
        }
        .padding(7)
    }
}
