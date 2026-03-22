import SwiftUI
import SwiftData
import Photos

struct SwipeView: View {
    let startDate: Date
    let albumIdentifier: String?
    let sortMode: SortMode

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Gallery.displayOrder) private var galleries: [Gallery]

    @State private var viewModel: SwipeViewModel?
    private let photoService = PhotoLibraryService.shared

    // Drag state
    @State private var cardOffset: CGSize = .zero
    @State private var highlightedGalleryID: UUID?
    @State private var galleryFrames: [UUID: CGRect] = [:]

    // Long-press preview
    @State private var isLongPressing = false

    // Sidebar gallery selection (up to 10)
    @State private var sidebarGalleryIDs: Set<UUID> = []
    @State private var showGallerySelector = false
    @State private var hasInitializedSidebar = false

    // Delete state
    @State private var isDeleting = false
    @State private var deleteMessage: DeleteFeedback?
    @AppStorage("totalDeletedPhotos") private var totalDeletedPhotos = 0

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
                    albumIdentifier: albumIdentifier,
                    sortMode: sortMode
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
            // Card stack — receives drag, double-tap, and long-press gestures
            cardStack(viewModel: viewModel)
                .onTapGesture(count: 2) {
                    viewModel.skipCurrent()
                }
                .gesture(longPressGesture)
                .gesture(dragGesture(viewModel: viewModel))

                // Sidebar overlay — visible ABOVE the photo, non-interactive
                .overlay {
                    HStack(spacing: 0) {
                        Spacer()
                        GallerySidebarView(
                            galleries: sidebarGalleries,
                            highlightedID: highlightedGalleryID,
                            dragProgress: isLongPressing ? 1.0 : rightDragProgress
                        )
                        .frame(width: geo.size.width * 0.5)
                    }
                    .ignoresSafeArea()
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

                // "Delete All" button — bottom left
                .overlay(alignment: .bottomLeading) {
                    if viewModel.dismissedCount > 0 {
                        Button {
                            performBatchDelete(viewModel: viewModel)
                        } label: {
                            Text("Delete \(viewModel.dismissedCount)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(.ultraThinMaterial, in: Capsule())
                        }
                        .disabled(isDeleting)
                        .padding(.leading, 16)
                        .padding(.bottom, 16)
                    }
                }
        }
        // Success message overlay
        .overlay {
            if let feedback = deleteMessage {
                deleteFeedbackOverlay(feedback)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: deleteMessage != nil)
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

    // MARK: - Long Press

    private var longPressGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.3)
            .onEnded { _ in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isLongPressing = true
                }
            }
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onEnded { _ in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isLongPressing = false
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
            isLongPressing = false
            action()
        }
    }

    private func snapBack() {
        withAnimation(.interpolatingSpring(stiffness: 150, damping: 15)) {
            cardOffset = .zero
        }
        highlightedGalleryID = nil
        isLongPressing = false
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

    // MARK: - Batch Delete

    private func performBatchDelete(viewModel: SwipeViewModel) {
        isDeleting = true
        Task {
            let count = await viewModel.batchDeleteDismissed()
            await MainActor.run {
                isDeleting = false
                if count > 0 {
                    totalDeletedPhotos += count
                    deleteMessage = DeleteFeedback(
                        sessionCount: count,
                        totalCount: totalDeletedPhotos
                    )
                    // Auto-dismiss after 2.5 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        deleteMessage = nil
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func deleteFeedbackOverlay(_ feedback: DeleteFeedback) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 36))
                .foregroundStyle(.primary)

            Text("\(feedback.sessionCount) photos deleted")
                .font(.title3)
                .fontWeight(.semibold)

            Text("\(feedback.totalCount) cleaned up in total")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(32)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
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

// MARK: - Delete Feedback

struct DeleteFeedback: Equatable {
    let sessionCount: Int
    let totalCount: Int
}
