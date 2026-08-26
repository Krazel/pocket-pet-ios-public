import SwiftUI
import UIKit

enum PocketPetColors {
    static let cream = Color(red: 0.996, green: 0.976, blue: 0.910)
    static let cardCream = Color(red: 0.996, green: 0.984, blue: 0.933)
    static let evergreen = Color(red: 0.075, green: 0.286, blue: 0.165)
    static let mutedEvergreen = Color(red: 0.290, green: 0.520, blue: 0.215)
    static let outline = Color(red: 0.710, green: 0.710, blue: 0.520).opacity(0.52)
    static let mint = Color(red: 0.890, green: 0.925, blue: 0.790)
    static let coral = Color(red: 0.980, green: 0.420, blue: 0.340)
    static let yellow = Color(red: 0.990, green: 0.710, blue: 0.080)
    static let blue = Color(red: 0.260, green: 0.700, blue: 0.880)
    static let peach = Color(red: 0.984, green: 0.855, blue: 0.682)
    static let lavender = Color(red: 0.784, green: 0.765, blue: 0.875)
    static let actionBlue = Color(red: 0.518, green: 0.816, blue: 0.929)
}

/// Loads loose PNG resources by bundle URL. SwiftUI's asset-name initializer
/// does not reliably resolve non-asset-catalog PNGs on every supported iOS SDK.
func PocketPetArtwork(_ name: String) -> Image {
    if let url = Bundle.main.url(forResource: name, withExtension: "png"),
       let image = UIImage(contentsOfFile: url.path) {
        return Image(uiImage: image)
    }
    assertionFailure("Missing bundled artwork: \(name).png")
    return Image(uiImage: UIImage())
}
