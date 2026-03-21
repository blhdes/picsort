import SwiftUI
import SwiftData

struct SwipeView: View {
    let startDate: Date

    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: SwipeViewModel?
    @State private var photoService = PhotoLibraryService()

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
                    cardStack(viewModel: viewModel)
                }
            } else {
                ProgressView()
            }
        }
        .task {
            if viewModel == nil {
                let vm = SwipeViewModel(
                    photoService: photoService,
                    modelContext: modelContext,
                    startDate: startDate
                )
                viewModel = vm

                let status = await photoService.requestAuthorization()
                guard status == .authorized || status == .limited else { return }
                await vm.loadInitialBatch()
            }
        }
    }

    // MARK: - Card Stack

    @ViewBuilder
    private func cardStack(viewModel: SwipeViewModel) -> some View {
        ZStack {
            // Next card (behind)
            if let nextID = viewModel.nextIdentifier {
                PhotoCardView(
                    assetIdentifier: nextID,
                    photoService: photoService,
                    onSwipeLeft: {},
                    onSwipeRight: {}
                )
                .id(nextID)
                .allowsHitTesting(false)
            }

            // Current card (on top, interactive)
            if let currentID = viewModel.currentIdentifier {
                PhotoCardView(
                    assetIdentifier: currentID,
                    photoService: photoService,
                    onSwipeLeft: { viewModel.dismissCurrent() },
                    onSwipeRight: { viewModel.sortCurrent() }
                )
                .id(currentID)
            }
        }
        .overlay(alignment: .bottom) {
            undoButton(viewModel: viewModel)
                .padding(.bottom, 32)
        }
        .sheet(isPresented: Binding(
            get: { viewModel.showGalleryPicker },
            set: { newValue in
                if !newValue { viewModel.cancelSort() }
            }
        )) {
            GalleryPickerSheet { gallery in
                viewModel.assignToGallery(gallery)
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
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
