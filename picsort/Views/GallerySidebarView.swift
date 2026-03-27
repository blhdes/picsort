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
                        pastelColor: gallery.color,
                        isHighlighted: gallery.id == highlightedID,
                        isDragging: isDragging,
                        dragProgress: dragProgress
                    )
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: GalleryFramePreferenceKey.self,
                                value: [gallery.id: geo.frame(in: .global)]
                            )
                        }
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

}

// MARK: - Shared Pastel Palette & Hex Support

extension Color {
    static let pastels: [Color] = [
        Color(red: 1.0, green: 0.18, blue: 0.47),   // neon pink
        Color(red: 0.0, green: 0.71, blue: 1.0),    // neon blue
        Color(red: 0.22, green: 1.0, blue: 0.08),   // neon green
        Color(red: 0.75, green: 0.0, blue: 1.0),    // neon purple
        Color(red: 1.0, green: 0.90, blue: 0.0),    // neon yellow
        Color(red: 1.0, green: 0.40, blue: 0.0),    // neon orange
        Color(red: 0.0, green: 1.0, blue: 0.93),    // neon cyan
        Color(red: 1.0, green: 0.0, blue: 0.25),    // neon red
        Color(red: 0.80, green: 1.0, blue: 0.0),    // neon lime
        Color(red: 1.0, green: 0.0, blue: 1.0),     // neon magenta
    ]

    static let pastelHexes: [String] = [
        "#FF2D78", "#00B4FF", "#39FF14", "#BF00FF",
        "#FFE600", "#FF6600", "#00FFEE", "#FF0040",
        "#CCFF00", "#FF00FF",
    ]

    static func pastel(for index: Int) -> Color {
        pastels[index % pastels.count]
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
    let pastelColor: Color
    let isHighlighted: Bool
    let isDragging: Bool
    let dragProgress: CGFloat

    var body: some View {
        ZStack(alignment: .leading) {
            // Pastel background — only visible during drag, fades in with progress
            if isDragging {
                pastelColor
                    .opacity(isHighlighted ? 0.9 : 0.3 + 0.5 * dragProgress)
            }

            // Gallery name — always visible, but subtle at rest
            Text(gallery.name)
                .font(isHighlighted ? .title2 : .title3)
                .fontWeight(isHighlighted ? .bold : .medium)
                .foregroundStyle(isDragging ? .white : .secondary)
                .shadow(color: isDragging ? .black.opacity(0.3) : .clear, radius: 2, x: 0, y: 1)
                .padding(.leading, 20)
                .opacity(isDragging ? 1.0 : 0.5)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .animation(.easeInOut(duration: 0.2), value: isDragging)
    }
}

// MARK: - Preference Key

struct GalleryFramePreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}
