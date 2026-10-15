import SwiftUI

/// Hell, Dunkel oder wie das iPhone eingestellt ist.
enum Appearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "Automatisch"
        case .light: "Hell"
        case .dark: "Dunkel"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// Bewusst kleine Palette: warmes Papier, Tinte und ein einziger Akzent (Paprika).
enum Theme {
    static let background = Color("Background")
    static let card = Color("Card")
    static let ink = Color("Ink")
    static let muted = Color("Muted")
    static let accent = Color.accentColor

    static let corner: CGFloat = 22
}

extension Font {
    /// Grosse Titel mit Serifen: wirkt erwachsen und "kulinarisch".
    static func feinsTitle(_ style: Font.TextStyle = .largeTitle) -> Font {
        .system(style, design: .serif).weight(.semibold)
    }

    /// Kleine Labels, verspielt gerundet.
    static func feinsLabel(_ style: Font.TextStyle = .caption) -> Font {
        .system(style, design: .rounded).weight(.semibold)
    }
}

struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(18)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                    .strokeBorder(Theme.ink.opacity(0.06))
            )
    }
}

extension View {
    func feinsCard() -> some View { modifier(CardBackground()) }

    func feinsScreenBackground() -> some View {
        background(Theme.background.ignoresSafeArea())
    }
}

/// Kleines Etikett mit Emoji und Kategorie.
struct CategoryChip: View {
    let category: DishCategory

    var body: some View {
        Label {
            Text(category.title)
        } icon: {
            Text(category.emoji)
        }
        .font(.feinsLabel())
        .foregroundStyle(Theme.ink.opacity(0.8))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Theme.ink.opacity(0.06), in: Capsule())
    }
}

/// Das Logo der App: handgezeichneter Smiley mit Zunge.
struct SmileyMark: View {
    var size: CGFloat = 96

    var body: some View {
        Image("Smiley")
            .resizable()
            .renderingMode(.template)
            .scaledToFit()
            .foregroundStyle(Theme.ink)
            .background {
                Image("SmileyTongue")
                    .resizable()
                    .scaledToFit()
            }
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
