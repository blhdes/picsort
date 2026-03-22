import SwiftUI

struct PhotoCardView: View {
    let assetIdentifier: String
    let photoService: PhotoLibraryService
    let offset: CGSize

    @State private var loader: PhotoImageLoader

    private let swipeThreshold: CGFloat = 150

    init(assetIdentifier: String, photoService: PhotoLibraryService, offset: CGSize = .zero) {
        self.assetIdentifier = assetIdentifier
        self.photoService = photoService
        self.offset = offset
        self._loader = State(initialValue: PhotoImageLoader(
            service: photoService,
            assetIdentifier: assetIdentifier,
            targetSize: CGSize(width: UIScreen.main.bounds.width * 2, height: UIScreen.main.bounds.height * 2)
        ))
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let image = loader.image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geo.size.width, height: geo.size.height)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                swipeOverlay
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .opacity(photoOpacity)
            .rotationEffect(.degrees(Double(offset.width / 20)))
            .offset(x: offset.width, y: offset.height * 0.4)
        }
        .padding()
        .task { await loader.load() }
    }

    // MARK: - Progressive transparency on right drag

    private var photoOpacity: CGFloat {
        guard offset.width > 0 else { return 1.0 }
        return 1.0 - 0.55 * min(offset.width / swipeThreshold, 1.0)
    }

    // MARK: - Dismiss overlay (left drag only)

    @ViewBuilder
    private var swipeOverlay: some View {
        if offset.width < 0 {
            let progress = min(abs(offset.width) / swipeThreshold, 1.0)
            Color.red
                .opacity(0.3 * progress)
                .allowsHitTesting(false)
        }
    }
}
