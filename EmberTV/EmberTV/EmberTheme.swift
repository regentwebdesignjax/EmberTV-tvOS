import SwiftUI
import UIKit

struct EmberTheme {
    // MARK: - Colors
    static let primary = Color(red: 0.937, green: 0.392, blue: 0.094) // #EF6418
    static let background = Color(red: 0.05, green: 0.05, blue: 0.05)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.7)
    
    // Premium Accents
    static let glassBackground = Color.white.opacity(0.1)
    static let shadowColor = Color.black.opacity(0.5)

    // MARK: - Internal helper
    private static func albert(
        _ name: String,
        size: CGFloat,
        fallbackWeight: Font.Weight
    ) -> Font {
        if UIFont(name: name, size: size) != nil {
            return .custom(name, size: size)
        } else {
            return .system(size: size, weight: fallbackWeight, design: .rounded)
        }
    }

    // MARK: - Public font helpers
    static func titleFont(_ size: CGFloat = 64) -> Font {
        // RESTORED: Back to SemiBold which works perfectly on your setup
        albert("AlbertSans-SemiBold", size: size, fallbackWeight: .semibold)
    }

    static func headingFont(_ size: CGFloat = 36) -> Font {
        albert("AlbertSans-SemiBold", size: size, fallbackWeight: .semibold)
    }

    static func bodyFont(_ size: CGFloat = 28) -> Font {
        albert("AlbertSans-Regular", size: size, fallbackWeight: .regular)
    }

    static func bodySemibold(_ size: CGFloat = 24) -> Font {
        albert("AlbertSans-SemiBold", size: size, fallbackWeight: .semibold)
    }

    static func captionFont(_ size: CGFloat = 18) -> Font {
        albert("AlbertSans-Light", size: size, fallbackWeight: .regular)
    }
}
