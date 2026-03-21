import SwiftUI

struct PhotoCardView: View {
    let assetIdentifier: String
    let photoService: PhotoLibraryService
    let onSwipeLeft: () -> Void
    let onSwipeRight: () -> Void

    @State private var loader: PhotoImageLoader
    @State private var offset: CGSize = .zero

    private let swipeThreshold: CGFloat = 150

    init(
        assetIdentifier: String,
        photoService: PhotoLibraryService,
        onSwipeLeft: @escaping () -> Void,
        onSwipeRight: @escaping () -> Void
    ) {
        self.assetIdentifier = assetIdentifier
        self.photoService = photoService
        self.onSwipeLeft = onSwipeLeft
        self.onSwipeRight = onSwipeRight
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
            .rotationEffect(.degrees(Double(offset.width / 20)))
            .offset(x: offset.width, y: offset.height * 0.4)
            .gesture(dragGesture)
            .animation(.interpolatingSpring(stiffness: 150, damping: 15), value: offset)
        }
        .padding()
        .task { await loader.load() }
    }

    // MARK: - Gesture

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = value.translation
            }
            .onEnded { value in
                if value.translation.width > swipeThreshold {
                    flyOff(to: .right)
                } else if value.translation.width < -swipeThreshold {
                    flyOff(to: .left)
                } else {
                    withAnimation(.interpolatingSpring(stiffness: 150, damping: 15)) {
                        offset = .zero
                    }
                }
            }
    }

    private func flyOff(to direction: SwipeDirection) {
        let offScreenX: CGFloat = direction == .right ? 500 : -500
        withAnimation(.easeIn(duration: 0.25)) {
            offset = CGSize(width: offScreenX, height: 0)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            switch direction {
            case .left: onSwipeLeft()
            case .right: onSwipeRight()
            }
        }
    }

    // MARK: - Overlay

    @ViewBuilder
    private var swipeOverlay: some View {
        let progress = min(abs(offset.width) / swipeThreshold, 1.0)

        if offset.width > 0 {
            // Swiping right → green tint
            Color.green
                .opacity(0.3 * progress)
                .allowsHitTesting(false)
        } else if offset.width < 0 {
            // Swiping left → red tint
            Color.red
                .opacity(0.3 * progress)
                .allowsHitTesting(false)
        }
    }
}

private enum SwipeDirection {
    case left, right
}
