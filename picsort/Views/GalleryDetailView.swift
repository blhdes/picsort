import SwiftUI

struct GalleryDetailView: View {
    let gallery: Gallery

    @State private var photoService = PhotoLibraryService()

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 2)]

    var body: some View {
        Group {
            if gallery.sortedPhotos.isEmpty {
                ContentUnavailableView(
                    "No Photos Yet",
                    systemImage: "photo",
                    description: Text("Swipe photos into this gallery to see them here.")
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(sortedPhotos) { photo in
                            PhotoThumbnailView(
                                assetIdentifier: photo.assetIdentifier,
                                photoService: photoService
                            )
                            .aspectRatio(1, contentMode: .fill)
                            .clipped()
                        }
                    }
                }
            }
        }
        .navigationTitle(gallery.name)
    }

    private var sortedPhotos: [SortedPhoto] {
        gallery.sortedPhotos.sorted { $0.sortedAt < $1.sortedAt }
    }
}

// MARK: - Thumbnail View

struct PhotoThumbnailView: View {
    let assetIdentifier: String
    let photoService: PhotoLibraryService

    @State private var loader: PhotoImageLoader

    init(assetIdentifier: String, photoService: PhotoLibraryService) {
        self.assetIdentifier = assetIdentifier
        self.photoService = photoService
        self._loader = State(initialValue: PhotoImageLoader(
            service: photoService,
            assetIdentifier: assetIdentifier,
            targetSize: CGSize(width: 200, height: 200)
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
