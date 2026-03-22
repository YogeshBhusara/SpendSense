//
//  SpendSenseAccent.swift
//  SpendSense
//

import SwiftUI

enum SpendSenseAccent {
    /// Matches `SpendSensePalette` accent swatches (warm teal, soft coral, amber, sage).
    static let optionNames: [String] = ["teal", "coral", "amber", "sage"]

    static func color(named name: String) -> Color {
        switch name.lowercased() {
        case "coral":
            return SpendSensePalette.softCoral
        case "amber":
            return SpendSensePalette.amber
        case "sage":
            return SpendSensePalette.sage
        case "lavender":
            // Legacy stored preference — map to sage so older installs keep a calm accent.
            return SpendSensePalette.sage
        default:
            return SpendSensePalette.warmTeal
        }
    }
}
