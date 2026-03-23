import SwiftUI
import SwiftData
import Photos
import Combine

struct SwipeView: View {
    let startDate: Date
    let albumIdentifier: String?
    let sortMode: SortMode
    let focusDuration: TimeInterval?
    let isOnThisDay: Bool
    var onSessionEnd: (() -> Void)?

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

    // Toast state
    @State private var toastMessage: String?
    @State private var toastTask: Task<Void, Never>?

    // Focus session timer
    @State private var remainingSeconds: Int = 0
    @State private var timerActive: Bool = false
    @State private var showSessionSummary: Bool = false

    // Delete state
    @State private var isDeleting = false
    @State private var deleteMessage: DeleteFeedback?
    @AppStorage("totalDeletedPhotos") private var totalDeletedPhotos = 0

    private let swipeThreshold: CGFloat = 100
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
                    sortMode: sortMode,
                    isOnThisDay: isOnThisDay
                )
                viewModel = vm
                await vm.loadInitialBatch()

                if let duration = focusDuration {
                    remainingSeconds = Int(duration)
                    timerActive = true
                }
            }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            guard timerActive, remainingSeconds > 0 else { return }
            remainingSeconds -= 1
            if remainingSeconds == 0 {
                timerActive = false
                showSessionSummary = true
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
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    viewModel.skipCurrent()
                }
                .gesture(longPressGesture)
                .highPriorityGesture(dragGesture(viewModel: viewModel))

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
        // Counter + toast at top
        .overlay(alignment: .top) {
            VStack(spacing: 6) {
                if focusDuration != nil, timerActive {
                    FocusTimerArcView(
                        remainingSeconds: remainingSeconds,
                        totalSeconds: Int(focusDuration ?? 0)
                    )
                }
                if viewModel.totalCount > 0 {
                    Text("\(viewModel.processedCount + 1) / \(viewModel.totalCount)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                if let toastMessage {
                    Text(toastMessage)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            .padding(.top, 8)
            .animation(.easeInOut(duration: 0.25), value: toastMessage)
        }
        // Focus session summary
        .overlay {
            if showSessionSummary {
                sessionSummaryOverlay(viewModel: viewModel)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .animation(.easeInOut(duration: 0.4), value: showSessionSummary)
        // Photo date + undo at bottom
        .overlay(alignment: .bottom) {
            VStack(spacing: 10) {
                if let date = viewModel.currentPhotoDate {
                    Text(date, format: .dateTime.month(.wide).day().year())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                undoButton(viewModel: viewModel)
            }
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

            // Opaque divider — hides next card at rest,
            // revealed as the current card drags away
            Color(.systemBackground)
                .ignoresSafeArea()

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
        let tx = value.translation.width
        let ptx = value.predictedEndTranslation.width

        // Left swipe: dismiss if actual OR predicted distance exceeds threshold
        if tx < -swipeThreshold || ptx < -swipeThreshold {
            flyOff(x: -500) {
                viewModel.dismissCurrent()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showToast("Dismissed")
            }
            return
        }

        // Right swipe: use the gallery that was highlighted during drag
        if tx > swipeThreshold || ptx > swipeThreshold,
           let id = highlightedGalleryID,
           let gallery = sidebarGalleries.first(where: { $0.id == id }) {
            flyOff(x: 500) {
                viewModel.assignToGallery(gallery)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                showToast("\u{2192} \(gallery.name)")
            }
            return
        }

        // Below threshold and no gallery → snap back
        snapBack()
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

    // MARK: - Toast

    private func showToast(_ message: String) {
        toastTask?.cancel()
        toastMessage = message
        toastTask = Task {
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.3)) {
                    toastMessage = nil
                }
            }
        }
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

    // MARK: - Session Summary

    @ViewBuilder
    private func sessionSummaryOverlay(viewModel: SwipeViewModel) -> some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture { }

            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 40))
                    .foregroundStyle(.primary)

                Text("Session Complete")
                    .font(.title2)
                    .fontWeight(.semibold)

                VStack(spacing: 12) {
                    summaryRow("Time", value: formatDuration(Int(focusDuration ?? 0)))
                    summaryRow("Reviewed", value: "\(viewModel.processedCount)")
                    summaryRow("Sorted", value: "\(viewModel.sessionSortedCount)")
                    summaryRow("Dismissed", value: "\(viewModel.sessionDismissedCount)")
                    summaryRow("Galleries", value: "\(viewModel.sessionGalleries.count)")
                }

                VStack(spacing: 12) {
                    Button("Keep Going") {
                        showSessionSummary = false
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)

                    Button("Done") {
                        showSessionSummary = false
                        onSessionEnd?()
                    }
                    .font(.subheadline)
                }
                .padding(.top, 8)
            }
            .padding(32)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal, 40)
        }
    }

    private func summaryRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .monospacedDigit()
        }
        .font(.body)
    }

    private func formatDuration(_ totalSeconds: Int) -> String {
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        if s == 0 { return "\(m) min" }
        return "\(m)m \(s)s"
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
