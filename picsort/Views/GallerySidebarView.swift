import SwiftUI

/// Pure display component — shows selected galleries on the right side.
/// No buttons or interactive elements (parent handles that).
struct GallerySidebarView: View {
    let galleries: [Gallery]
    let highlightedID: UUID?
    let dragProgress: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            if galleries.isEmpty {
                Spacer()
                Text("Tap Manage to\nadd galleries")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Spacer()
            } else {
                Spacer()

                ForEach(galleries) { gallery in
                    GallerySidebarItem(
                        gallery: gallery,
                        isHighlighted: gallery.id == highlightedID
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

                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .opacity(0.4 + 0.6 * dragProgress)
    }
}

// MARK: - Single Gallery Item (text-only, clean)

struct GallerySidebarItem: View {
    let gallery: Gallery
    let isHighlighted: Bool

    var body: some View {
        Text(gallery.name)
            .font(.title3)
            .fontWeight(isHighlighted ? .bold : .regular)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial.opacity(isHighlighted ? 1.0 : 0.6))
            )
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(isHighlighted ? galleryColor : .primary)
            .scaleEffect(isHighlighted ? 1.08 : 1.0)
            .animation(.spring(duration: 0.2), value: isHighlighted)
    }

    private var galleryColor: Color {
        Color(hex: gallery.colorHex) ?? .blue
    }
}

// MARK: - Preference Key

struct GalleryFramePreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}
