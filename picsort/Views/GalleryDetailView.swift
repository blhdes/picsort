import SwiftUI
import SwiftData

struct GalleryDetailView: View {
    let gallery: Gallery

    @Environment(\.modelContext) private var modelContext
    private let photoService = PhotoLibraryService.shared

    @State private var allIdentifiers: [String] = []
    @State private var hasSynced = false
    @State private var showColorPicker = false
    @State private var previewIdentifier: String?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 1.5), count: 3)

    private static let thumbnailSize: CGSize = {
        let side = (UIScreen.main.bounds.width / 3) * UIScreen.main.scale
        return CGSize(width: side, height: side)
    }()

    var body: some View {
        Group {
            if allIdentifiers.isEmpty && hasSynced {
                ContentUnavailableView(
                    "No Photos Yet",
                    systemImage: "photo",
                    description: Text("Swipe photos into this gallery to see them here.")
                )
            } else if allIdentifiers.isEmpty {
                ProgressView()
            } else {
                VStack(spacing: 0) {
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showColorPicker.toggle()
                                }
                            } label: {
                                Circle()
                                    .fill(gallery.color)
                                    .frame(width: 12, height: 12)
                            }

                            Text("\(allIdentifiers.count) photos")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Spacer()
                        }

                        if showColorPicker {
                            VStack(spacing: 12) {
                                // Quick-pick pastel presets
                                HStack(spacing: 10) {
                                    ForEach(Array(Color.pastelHexes.enumerated()), id: \.offset) { _, hex in
                                        Button {
                                            gallery.colorHex = hex
                                            try? modelContext.save()
                                        } label: {
                                            Circle()
                                                .fill(Color(hex: hex))
                                                .frame(width: 24, height: 24)
                                                .overlay {
                                                    if gallery.colorHex == hex {
                                                        Circle()
                                                            .strokeBorder(.primary, lineWidth: 2)
                                                    }
                                                }
                                        }
                                    }
                                }

                                // Full color picker for custom colors
                                ColorPicker(
                                    "Custom color",
                                    selection: Binding(
                                        get: { gallery.color },
                                        set: { newColor in
                                            gallery.colorHex = newColor.hexString
                                            try? modelContext.save()
                                        }
                                    ),
                                    supportsOpacity: false
                                )
                                .font(.subheadline)
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(.systemBackground))

                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 1.5) {
                            ForEach(allIdentifiers, id: \.self) { identifier in
                                Color.clear
                                    .aspectRatio(1, contentMode: .fit)
                                    .overlay {
                                        PhotoThumbnailView(
                                            assetIdentifier: identifier,
                                            photoService: photoService,
                                            targetSize: Self.thumbnailSize
                                        )
                                    }
                                    .clipped()
                                    .onLongPressGesture {
                                        previewIdentifier = identifier
                                    }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(gallery.name)
        .fullScreenCover(item: Binding(
            get: { previewIdentifier.map { PhotoPreviewItem(id: $0) } },
            set: { previewIdentifier = $0?.id }
        )) { item in
            PhotoPreviewOverlay(
                identifier: item.id,
                photoService: photoService,
                onDismiss: { previewIdentifier = nil }
            )
        }
        .task {
            await syncAndLoad()
        }
    }

    // MARK: - Sync

    /// Syncs missing photos from the linked iPhone album into SortedPhoto records,
    /// then builds the full identifier list.
    private func syncAndLoad() async {
        // If gallery is linked to a real album, sync any photos not yet tracked
        if let albumID = gallery.albumIdentifier {
            let albumIdentifiers = photoService.fetchAssetIdentifiers(
                from: .distantPast,
                excluding: [],
                inAlbum: albumID
            )

            let existingIDs = Set(gallery.sortedPhotos.map(\.assetIdentifier))
            var added = false

            for id in albumIdentifiers {
                if !existingIDs.contains(id) {
                    let sorted = SortedPhoto(assetIdentifier: id, gallery: gallery, isImported: true)
                    modelContext.insert(sorted)
                    added = true
                }
            }

            if added {
                try? modelContext.save()
            }
        }

        // Build the display list from SortedPhoto records
        allIdentifiers = gallery.sortedPhotos
            .sorted { $0.sortedAt < $1.sortedAt }
            .map(\.assetIdentifier)

        hasSynced = true
    }
}

// MARK: - Thumbnail View

struct PhotoThumbnailView: View {
    let assetIdentifier: String
    let photoService: PhotoLibraryService
    let targetSize: CGSize

    @State private var loader: PhotoImageLoader

    init(assetIdentifier: String, photoService: PhotoLibraryService, targetSize: CGSize = CGSize(width: 400, height: 400)) {
        self.assetIdentifier = assetIdentifier
        self.photoService = photoService
        self.targetSize = targetSize
        self._loader = State(initialValue: PhotoImageLoader(
            service: photoService,
            assetIdentifier: assetIdentifier,
            targetSize: targetSize
        ))
    }

    var body: some View {
        Group {
            if let image = loader.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .overlay { ProgressView() }
            }
        }
        .task { await loader.load() }
    }
}
