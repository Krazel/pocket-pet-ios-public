import PocketPetCore
import SwiftUI

struct RoomRibbon: View {
    let currentRoom: PetSpaceID
    let isTransitioning: Bool
    let onMove: (PetSpaceID) -> Void

    private let rooms: [RoomRibbonItem] = [
        RoomRibbonItem(id: .sunnyPatio, title: "Home", artwork: "icon_room_home"),
        RoomRibbonItem(id: .pantryNook, title: "Pantry", artwork: "icon_room_pantry"),
    ]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(rooms) { room in
                Button {
                    onMove(room.id)
                } label: {
                    HStack(spacing: 8) {
                        PocketPetArtwork(room.artwork)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 34, height: 32)
                            .accessibilityHidden(true)
                        Text(room.title)
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundStyle(PocketPetColors.evergreen)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(
                                currentRoom == room.id
                                    ? PocketPetColors.mint
                                    : PocketPetColors.cardCream.opacity(0.82)
                            )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(
                                currentRoom == room.id
                                    ? PocketPetColors.evergreen
                                    : PocketPetColors.outline,
                                lineWidth: currentRoom == room.id ? 2.2 : 1
                            )
                    }
                }
                .buttonStyle(.plain)
                .disabled(isTransitioning || currentRoom == room.id)
                .accessibilityLabel(room.title)
                .accessibilityValue(currentRoom == room.id ? "Current room" : "")
                .accessibilityHint("Opens " + room.title)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(PocketPetColors.cardCream.opacity(0.94))
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(PocketPetColors.outline, lineWidth: 1.2)
                }
        )
        .accessibilityElement(children: .contain)
    }
}

private struct RoomRibbonItem: Identifiable {
    let id: PetSpaceID
    let title: String
    let artwork: String
}
