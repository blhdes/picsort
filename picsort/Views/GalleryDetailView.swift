import SwiftUI

struct GalleryDetailView: View {
    let gallery: Gallery

    @Environment(\.modelContext) private var modelContext
    private let photoService = PhotoLibraryService.shared

    @State private var allIdentifiers: [String] = []
    @State private var hasSynced = false

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 2)]

    /// Thumbnail size accounting for retina scale (3 columns ≈ 130pt each).
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
                ScrollView {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.pastel(for: gallery.displayOrder))
                            .frame(width: 8, height: 8)

                        Text("\(allIdentifiers.count) photos")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(allIdentifiers, id: \.self) { identifier in
                            PhotoThumbnailView(
                                assetIdentifier: identifier,
                                photoService: photoService,
                                targetSize: Self.thumbnailSize
                            )
                            .aspectRatio(1, contentMode: .fill)
                            .clipped()
                        }
                    }
                }
            }
        }
        .navigationTitle(gallery.name)
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
                    let sorted = SortedPhoto(assetIdentifier: id, gallery: gallery)
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
