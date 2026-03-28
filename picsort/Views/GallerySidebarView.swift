import SwiftUI

/// Displays selected galleries as colored panels that split the screen equally.
/// 2 galleries = 50/50, 3 = 33/33/33, etc.
struct GallerySidebarView: View {
    let galleries: [Gallery]
    let highlightedID: UUID?
    let dragProgress: CGFloat

    /// Whether the user is actively dragging (any rightward movement).
    private var isDragging: Bool { dragProgress > 0 }

    var body: some View {
        if galleries.isEmpty {
            VStack {
                Spacer()
                Text("Tap Manage to\nadd galleries")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .opacity(isDragging ? 0.4 + 0.6 * dragProgress : 0.4)
        } else {
            VStack(spacing: 0) {
                ForEach(Array(galleries.enumerated()), id: \.element.id) { index, gallery in
                    GallerySidebarItem(
                        gallery: gallery,
                        neonColor: gallery.color,
                        isHighlighted: gallery.id == highlightedID,
                        isDragging: isDragging,
                        dragProgress: dragProgress
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                GeometryReader { geo in
                    Color.clear.preference(
                        key: SidebarFramePreferenceKey.self,
                        value: geo.frame(in: .global)
                    )
                }
            )
        }
    }

}

// MARK: - Shared Neon Palette & Hex Support

extension Color {

    /// Canonical palette — stored in SwiftData and used as identity keys.
    static let neonHexes: [String] = [
        "#FF2D78", "#00B4FF", "#39FF14", "#BF00FF",
        "#FFE600", "#FF6600", "#00FFEE", "#FF0040",
        "#CCFF00", "#FF00FF",
    ]

    /// Dark mode display — slightly toned down where raw neons are too harsh.
    private static let neonHexesDark: [String] = [
        "#FF2D78", "#00B4FF", "#30E612", "#BF00FF",
        "#FFCC00", "#FF6600", "#00E6D6", "#FF0040",
        "#B8E600", "#FF00FF",
    ]

    /// Light mode display — deeper, richer versions readable on white.
    private static let neonHexesLight: [String] = [
        "#D42560", "#0088CC", "#1DAF00", "#9500CC",
        "#B88700", "#D45500", "#008877", "#CC0033",
        "#6E9E00", "#CC00CC",
    ]

    /// Returns a Color that automatically adapts between light and dark mode.
    /// If the hex matches a known neon, it maps to the curated variant.
    /// Custom colors pass through unchanged.
    static func adaptiveNeon(hex: String) -> Color {
        let darkHex: String
        let lightHex: String
        if let index = neonHexes.firstIndex(of: hex) {
            darkHex = neonHexesDark[index]
            lightHex = neonHexesLight[index]
        } else {
            darkHex = hex
            lightHex = hex
        }
        return Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(Color(hex: darkHex))
                : UIColor(Color(hex: lightHex))
        })
    }

    /// Adaptive neon palette — ready to render in any color scheme.
    static let neons: [Color] = neonHexes.map { adaptiveNeon(hex: $0) }

    static func neon(for index: Int) -> Color {
        neons[index % neons.count]
    }

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgb)
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }

    var hexString: String {
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X",
                      Int(r * 255), Int(g * 255), Int(b * 255))
    }
}

// MARK: - Single Gallery Panel

struct GallerySidebarItem: View {
    let gallery: Gallery
    let neonColor: Color
    let isHighlighted: Bool
    let isDragging: Bool
    let dragProgress: CGFloat

    var body: some View {
        ZStack(alignment: .leading) {
            neonColor
                .opacity(backgroundOpacity)

            Text(gallery.name)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(isDragging ? .white : .secondary)
                .shadow(color: isDragging ? .black.opacity(0.25) : .clear, radius: 2, x: 0, y: 1)
                .padding(.leading, 20)
                .opacity(textOpacity)
                .scaleEffect(isHighlighted ? 1.08 : 1.0, anchor: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .animation(.snappy(duration: 0.25), value: isHighlighted)
        .animation(.easeInOut(duration: 0.2), value: isDragging)
    }

    private var backgroundOpacity: Double {
        guard isDragging else { return 0 }
        return isHighlighted ? 0.85 : 0.2 + 0.4 * dragProgress
    }

    private var textOpacity: Double {
        if !isDragging { return 0.5 }
        return isHighlighted ? 1.0 : 0.65
    }
}

// MARK: - Preference Key

struct SidebarFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}
