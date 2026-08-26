import PocketPetCore
import SwiftUI

struct RoomRibbon: View {
    let currentRoom: PetSpaceID
    let isTransitioning: Bool
    let onMove: (PetSpaceID) -> Void

    private let rooms: [RoomRibbonItem] = [
        RoomRibbonItem(id: .sunnyPatio, title: "Home", artwork: "icon_room_home", isAvailable: true),
        RoomRibbonItem(id: .pantryNook, title: "Pantry", artwork: "icon_room_pantry", isAvailable: true),
        RoomRibbonItem(id: .washNook, title: "Wash", artwork: "icon_room_wash", isAvailable: false),
        RoomRibbonItem(id: .playLoft, title: "Play", artwork: "icon_room_play", isAvailable: false),
        RoomRibbonItem(id: .nestRoom, title: "Nest", artwork: "icon_room_nest", isAvailable: false),
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(rooms) { room in
                    Button {
                        if room.isAvailable { onMove(room.id) }
                    } label: {
                        VStack(spacing: 3) {
                            PocketPetArtwork(room.artwork)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 43, height: 38)
                                .accessibilityHidden(true)
                            Text(room.title)
                                .font(.system(.caption, design: .rounded, weight: .bold))
                                .foregroundStyle(PocketPetColors.evergreen)
                                .lineLimit(1)
                        }
                        .frame(minWidth: 61, minHeight: 68)
                        .padding(.horizontal, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(
                                    currentRoom == room.id
                                        ? PocketPetColors.mint
                                        : PocketPetColors.cardCream.opacity(0.82)
                                )
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(
                                    currentRoom == room.id
                                        ? PocketPetColors.evergreen
                                        : PocketPetColors.outline,
                                    lineWidth: currentRoom == room.id ? 2.2 : 1
                                )
                        }
                        .opacity(room.isAvailable ? 1 : 0.62)
                    }
                    .buttonStyle(.plain)
                    .disabled(isTransitioning || !room.isAvailable)
                    .accessibilityLabel(room.title)
                    .accessibilityValue(currentRoom == room.id ? "Current room" : "")
                    .accessibilityHint(
                        room.isAvailable
                            ? "Opens " + room.title
                            : "This room is still growing"
                    )
                }
            }
            .padding(.horizontal, 5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 5)
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
    let isAvailable: Bool
}
