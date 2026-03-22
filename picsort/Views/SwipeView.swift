import SwiftUI
import SwiftData
import Photos

struct SwipeView: View {
    let startDate: Date
    let albumIdentifier: String?

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Gallery.displayOrder) private var galleries: [Gallery]

    @State private var viewModel: SwipeViewModel?
    @State private var photoService = PhotoLibraryService()

    // Drag state
    @State private var cardOffset: CGSize = .zero
    @State private var highlightedGalleryID: UUID?
    @State private var galleryFrames: [UUID: CGRect] = [:]

    // Sidebar gallery selection (up to 10)
    @State private var sidebarGalleryIDs: Set<UUID> = []
    @State private var showGallerySelector = false
    @State private var hasInitializedSidebar = false

    private let swipeThreshold: CGFloat = 150
    private let maxSidebarGalleries = 10

    /// Only galleries the user has selected, in display order.
    private var sidebarGalleries: [Gallery] {
        galleries
            .filter { sidebarGalleryIDs.contains($0.id) }
            .sorted { $0.displayOrder < $1.displayOrder }
    }

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            if let viewModel {
                if viewModel.isLoading {
                    ProgressView("Loading photos...")
                } else if viewModel.isEmpty {
                    emptyStateView
                } else {
                    swipeContent(viewModel: viewModel)
                }
            } else {
                ProgressView()
            }
        }
        .onPreferenceChange(GalleryFramePreferenceKey.self) { frames in
            galleryFrames = frames
        }
        .sheet(isPresented: $showGallerySelector) {
            GallerySelectionSheet(
                selectedIDs: $sidebarGalleryIDs,
                maxSelection: maxSidebarGalleries
            )
        }
        .task {
            if viewModel == nil {
                let vm = SwipeViewModel(
                    photoService: photoService,
                    modelContext: modelContext,
                    startDate: startDate,
                    albumIdentifier: albumIdentifier
                )
                viewModel = vm
                await vm.loadInitialBatch()
            }
        }
        .onChange(of: galleries.count) {
            // On first gallery creation, auto-add to sidebar
            if !hasInitializedSidebar, !galleries.isEmpty {
                sidebarGalleryIDs = Set(galleries.prefix(maxSidebarGalleries).map(\.id))
                hasInitializedSidebar = true
            }
        }
        .onAppear {
            if !hasInitializedSidebar, !galleries.isEmpty {
                sidebarGalleryIDs = Set(galleries.prefix(maxSidebarGalleries).map(\.id))
                hasInitializedSidebar = true
            }
        }
    }

    // MARK: - Swipe Content

    @ViewBuilder
    private func swipeContent(viewModel: SwipeViewModel) -> some View {
        GeometryReader { geo in
            // Card stack — receives the drag gesture
            cardStack(viewModel: viewModel)
                .gesture(dragGesture(viewModel: viewModel))

                // Sidebar overlay — visible ABOVE the photo, non-interactive
                .overlay {
                    HStack(spacing: 0) {
                        Spacer()
                        GallerySidebarView(
                            galleries: sidebarGalleries,
                            highlightedID: highlightedGalleryID,
                            dragProgress: rightDragProgress
                        )
                        .frame(width: geo.size.width * 0.5)
                    }
                    .allowsHitTesting(false)
                }

                // "Manage" button — bottom right, tappable
                .overlay(alignment: .bottomTrailing) {
                    Button {
                        showGallerySelector = true
                    } label: {
                        Text("Manage")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, 16)
                }
        }
        .overlay(alignment: .bottom) {
            undoButton(viewModel: viewModel)
                .padding(.bottom, 32)
        }
    }

    // MARK: - Card Stack

    @ViewBuilder
    private func cardStack(viewModel: SwipeViewModel) -> some View {
        ZStack {
            // Next card (behind, no interaction)
            if let nextID = viewModel.nextIdentifier {
                PhotoCardView(
                    assetIdentifier: nextID,
                    photoService: photoService
                )
                .id(nextID)
                .allowsHitTesting(false)
            }

            // Current card
            if let currentID = viewModel.currentIdentifier {
                PhotoCardView(
                    assetIdentifier: currentID,
                    photoService: photoService,
                    offset: cardOffset
                )
                .id(currentID)
            }
        }
    }

    // MARK: - Gesture

    private func dragGesture(viewModel: SwipeViewModel) -> some Gesture {
        DragGesture(coordinateSpace: .global)
            .onChanged { value in
                cardOffset = value.translation
                updateHighlight(
                    translation: value.translation,
                    location: value.location
                )
            }
            .onEnded { value in
                handleSwipeEnd(value, viewModel: viewModel)
            }
    }

    // MARK: - Gesture Handling

    private func updateHighlight(translation: CGSize, location: CGPoint) {
        if translation.width > 30 {
            highlightedGalleryID = findGallery(at: location)
        } else {
            highlightedGalleryID = nil
        }
    }

    private func handleSwipeEnd(_ value: DragGesture.Value, viewModel: SwipeViewModel) {
        // Compute target gallery from final finger position
        let targetGallery: Gallery? = {
            guard value.translation.width > 30,
                  let id = findGallery(at: value.location) else { return nil }
            return sidebarGalleries.first { $0.id == id }
        }()

        if value.translation.width < -swipeThreshold {
            // Swipe left → dismiss
            flyOff(x: -500) {
                viewModel.dismissCurrent()
            }
        } else if value.translation.width > swipeThreshold, let gallery = targetGallery {
            // Swipe right toward a gallery → assign + haptic
            flyOff(x: 500) {
                viewModel.assignToGallery(gallery)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
        } else {
            // Below threshold or no gallery targeted → snap back
            snapBack()
        }
    }

    private func flyOff(x: CGFloat, action: @escaping () -> Void) {
        withAnimation(.easeIn(duration: 0.25)) {
            cardOffset = CGSize(width: x, height: 0)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            cardOffset = .zero
            highlightedGalleryID = nil
            action()
        }
    }

    private func snapBack() {
        withAnimation(.interpolatingSpring(stiffness: 150, damping: 15)) {
            cardOffset = .zero
        }
        highlightedGalleryID = nil
    }

    // MARK: - Helpers

    private var rightDragProgress: CGFloat {
        min(max(cardOffset.width / swipeThreshold, 0), 1.0)
    }

    private func findGallery(at point: CGPoint) -> UUID? {
        for (id, frame) in galleryFrames {
            if point.y >= frame.minY && point.y <= frame.maxY {
                return id
            }
        }
        return nil
    }

    // MARK: - Undo Button

    @ViewBuilder
    private func undoButton(viewModel: SwipeViewModel) -> some View {
        if viewModel.lastAction != nil {
            Button {
                viewModel.undo()
            } label: {
                Label("Undo", systemImage: "arrow.uturn.backward")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.spring, value: viewModel.lastAction != nil)
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No more photos")
                .font(.title3)
                .fontWeight(.medium)

            Text("All photos from this date have been sorted or dismissed.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}
