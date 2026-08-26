import PocketPetCore
import SpriteKit
import SwiftUI

struct PantrySceneView: View {
    let pet: PetState
    let selectedFood: PocketPetPantryFood?
    let offerSequence: Int
    let prefersReducedMotion: Bool
    let isOfferEnabled: Bool
    let onOffer: () -> Void

    @State private var scene = PantryScene()
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    var body: some View {
        SpriteView(scene: scene, options: [.allowsTransparency])
            .overlay {
                Button(action: onOffer) {
                    Color.clear
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!isOfferEnabled)
                .accessibilityLabel(offerLabel)
                .accessibilityHint("Offers the selected food to " + pet.name)
            }
            .accessibilityElement(children: .contain)
            .onAppear(perform: updateScene)
            .onChange(of: pet, perform: { _ in updateScene() })
            .onChange(of: selectedFood, perform: { _ in updateScene() })
            .onChange(of: offerSequence, perform: { _ in updateScene() })
            .onChange(of: prefersReducedMotion, perform: { _ in updateScene() })
    }

    private var offerLabel: String {
        guard let selectedFood else { return "Select a food to offer" }
        return "Offer " + selectedFood.name
    }

    private func updateScene() {
        scene.configure(
            pet: pet,
            selectedFoodID: selectedFood?.id,
            offerSequence: offerSequence,
            reduceMotion: prefersReducedMotion || systemReduceMotion
        )
    }
}
