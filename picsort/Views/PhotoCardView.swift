import SwiftUI

struct PhotoCardView: View {
    let assetIdentifier: String
    let photoService: PhotoLibraryService
    let offset: CGSize
    var isZoomed: Bool = false

    @State private var loader: PhotoImageLoader

    private let swipeThreshold: CGFloat = 100

    init(assetIdentifier: String, photoService: PhotoLibraryService, offset: CGSize = .zero, isZoomed: Bool = false) {
        self.assetIdentifier = assetIdentifier
        self.photoService = photoService
        self.offset = offset
        self.isZoomed = isZoomed
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
                        .aspectRatio(contentMode: isZoomed ? .fill : .fit)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .animation(.easeInOut(duration: 0.3), value: isZoomed)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                swipeOverlay
            }
            .clipped()
            .opacity(photoOpacity)
            .rotationEffect(.degrees(Double(offset.width / 40)))
            .offset(x: offset.width, y: offset.height * 0.4)
        }
        .ignoresSafeArea()
        .task { await loader.load() }
    }

    // MARK: - Progressive transparency on right drag

    private var photoOpacity: CGFloat {
        guard offset.width > 0 else { return 1.0 }
        return 1.0 - 0.3 * min(offset.width / swipeThreshold, 1.0)
    }

    // MARK: - Directional overlays

    @ViewBuilder
    private var swipeOverlay: some View {
        let isVertical = abs(offset.height) > abs(offset.width)

        if offset.width < 0 && !isVertical {
            // Left drag — red (dismiss)
            let progress = min(abs(offset.width) / swipeThreshold, 1.0)
            Color.red
                .opacity(0.3 * progress)
                .allowsHitTesting(false)
        } else if offset.height < 0 && isVertical {
            // Up drag — gold (favorite)
            let progress = min(abs(offset.height) / swipeThreshold, 1.0)
            ZStack {
                Color.yellow
                    .opacity(0.25 * progress)
                Image(systemName: "heart.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.white.opacity(0.8 * progress))
            }
            .allowsHitTesting(false)
        } else if offset.height > 0 && isVertical {
            // Down drag — blue (share)
            let progress = min(abs(offset.height) / swipeThreshold, 1.0)
            ZStack {
                Color.blue
                    .opacity(0.25 * progress)
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 60))
                    .foregroundStyle(.white.opacity(0.8 * progress))
            }
            .allowsHitTesting(false)
        }
    }
}
