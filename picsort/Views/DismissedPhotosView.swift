import SwiftUI
import SwiftData

struct DismissedPhotosView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: DismissedPhotosViewModel?
    @State private var deleteMessage: DeleteFeedback?
    @AppStorage("totalDeletedPhotos") private var totalDeletedPhotos = 0
    @State private var previewIdentifier: String?

    private let photoService = PhotoLibraryService.shared
    private let columns = PhotoThumbnailView.gridColumns

    var body: some View {
        Group {
            if let viewModel {
                if viewModel.dismissedPhotos.isEmpty {
                    ContentUnavailableView(
                        "No Dismissed Photos",
                        systemImage: "trash.slash",
                        description: Text("Photos you dismiss will appear here for review.")
                    )
                } else {
                    VStack(spacing: 0) {
                        // Photo count + selection controls
                        HStack {
                            Text("\(viewModel.dismissedPhotos.count) photos")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Spacer()

                            if viewModel.hasSelection {
                                Button("Deselect All") {
                                    viewModel.deselectAll()
                                }
                                .font(.subheadline)
                            } else {
                                Button("Select All") {
                                    viewModel.selectAll()
                                }
                                .font(.subheadline)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)

                        // Grid
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 1.5) {
                                ForEach(viewModel.dismissedPhotos, id: \.assetIdentifier) { photo in
                                    let isSelected = viewModel.selectedIdentifiers.contains(photo.assetIdentifier)

                                    PhotoThumbnailView(
                                        assetIdentifier: photo.assetIdentifier,
                                        photoService: photoService
                                    )
                                    .overlay(alignment: .topTrailing) {
                                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                            .font(.title3)
                                            .foregroundStyle(isSelected ? .white : .white.opacity(0.7))
                                            .shadow(radius: 2)
                                            .padding(6)
                                    }
                                    .overlay {
                                        if isSelected {
                                            Color.accentColor.opacity(0.2)
                                        }
                                    }
                                    .onTapGesture {
                                        viewModel.toggleSelection(photo.assetIdentifier)
                                    }
                                    .onLongPressGesture {
                                        previewIdentifier = photo.assetIdentifier
                                    }
                                    .id(photo.assetIdentifier)
                                }
                            }
                        }

                        // Bottom action bar
                        actionBar(viewModel: viewModel)
                    }
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Dismissed Photos")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
        .deleteFeedback($deleteMessage)
        // Full-size preview
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
            if viewModel == nil {
                let vm = DismissedPhotosViewModel(modelContext: modelContext)
                vm.loadDismissedPhotos()
                viewModel = vm
            }
        }
    }

    // MARK: - Action Bar

    @ViewBuilder
    private func actionBar(viewModel: DismissedPhotosViewModel) -> some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                if viewModel.hasSelection {
                    Button {
                        withAnimation { viewModel.recoverSelected() }
                    } label: {
                        Text("Recover (\(viewModel.selectedCount))")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)

                    Button {
                        Task {
                            let count = await viewModel.deleteSelected()
                            showDeleteFeedback(count)
                        }
                    } label: {
                        Text("Delete (\(viewModel.selectedCount))")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .controlSize(.regular)
                    .disabled(viewModel.isDeleting)
                } else {
                    Button {
                        withAnimation { viewModel.recoverAll() }
                    } label: {
                        Text("Recover All")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)

                    Button {
                        Task {
                            let count = await viewModel.deleteAll()
                            showDeleteFeedback(count)
                        }
                    } label: {
                        Text("Delete All")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .controlSize(.regular)
                    .disabled(viewModel.isDeleting)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
        }
    }

    private func showDeleteFeedback(_ count: Int) {
        guard count > 0 else { return }
        totalDeletedPhotos += count
        deleteMessage = DeleteFeedback(sessionCount: count, totalCount: totalDeletedPhotos)
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            deleteMessage = nil
        }
    }
}

