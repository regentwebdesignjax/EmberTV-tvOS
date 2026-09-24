import SwiftUI

/// EmberTV focus styling for tvOS text fields.
/// Adds an Ember orange glow + border when focused, and suppresses the default tvOS focus effect.
struct EmberFocusedFieldStyle: ViewModifier {
    let isFocused: Bool

    func body(content: Content) -> some View {
        content
            .padding(.vertical, 18)
            .padding(.horizontal, 22)
            .background(Color.white.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isFocused ? EmberTheme.primary : Color.white.opacity(0.18),
                            lineWidth: isFocused ? 3 : 1)
                    .shadow(color: EmberTheme.primary.opacity(isFocused ? 0.70 : 0.0),
                            radius: isFocused ? 18 : 0,
                            x: 0, y: 0)
            )
            // Turn off the default tvOS focus "sheen"/halo
            .focusEffectDisabled(true)
    }
}

extension View {
    func emberFocusedField(isFocused: Bool) -> some View {
        self.modifier(EmberFocusedFieldStyle(isFocused: isFocused))
    }
}
