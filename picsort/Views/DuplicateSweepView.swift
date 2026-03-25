import SwiftUI
import SwiftData
import PhotosUI

struct DuplicateSweepView: View {
    var onClose: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: DuplicateSweepViewModel?
    @State private var showPicker = true
    @State private var deleteMessage: DeleteFeedback?
    @AppStorage("totalDeletedPhotos") private var totalDeletedPhotos = 0
    @State private var keptID: String?

    private let photoService = PhotoLibraryService.shared

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            if let viewModel {
                switch viewModel.phase {
                case .idle:
                    // Picker is presented as a sheet
                    Color.clear
                case .scanning:
                    scanningView
                case .comparing:
                    comparingView(viewModel: viewModel)
                case .done:
                    doneView(viewModel: viewModel)
                }
            } else {
                Color.clear
            }
        }
        .overlay(alignment: .topLeading) {
            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.body)
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .padding(.leading, 16)
            .padding(.top, 8)
        }
        .deleteFeedback($deleteMessage)
        .onAppear {
            if viewModel == nil {
                viewModel = DuplicateSweepViewModel(modelContext: modelContext)
            }
        }
        .sheet(isPresented: $showPicker, onDismiss: {
            // If user cancelled the picker without selecting, go back
            if viewModel?.phase == .idle {
                onClose()
            }
        }) {
            PhotoPickerView { identifier in
                showPicker = false
                guard let viewModel else { return }
                Task {
                    await viewModel.startSearch(for: identifier)
                }
            }
        }
    }

    // MARK: - Scanning

    private var scanningView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Finding duplicates...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Comparing

    @ViewBuilder
    private func comparingView(viewModel: DuplicateSweepViewModel) -> some View {
        VStack(spacing: 0) {
            // Counter
            if viewModel.totalDuplicatesFound > 0 {
                Text("\(viewModel.currentIndex) of \(viewModel.totalDuplicatesFound) duplicates")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.top, 48)
            }

            Spacer()

            // Side by side: HStack for portrait, VStack for landscape
            let layout = viewModel.isLandscape
                ? AnyLayout(VStackLayout(spacing: 2))
                : AnyLayout(HStackLayout(spacing: 2))

            layout {
                // Reference (left / top)
                if let refID = viewModel.referenceIdentifier {
                    comparisonCard(
                        identifier: refID,
                        label: "Original",
                        isKept: keptID == refID,
                        action: {
                            guard keptID == nil else { return }
                            keptID = refID
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                                viewModel.keepReference()
                                keptID = nil
                            }
                        }
                    )
                    .id(refID)
                }

                // Duplicate (right / bottom)
                if let dupID = viewModel.currentDuplicateIdentifier {
                    comparisonCard(
                        identifier: dupID,
                        label: "Duplicate",
                        isKept: keptID == dupID,
                        action: {
                            guard keptID == nil else { return }
                            keptID = dupID
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                                viewModel.keepDuplicate()
                                keptID = nil
                            }
                        }
                    )
                    .id(dupID)
                }
            }
            .animation(.easeInOut(duration: 0.35), value: viewModel.isLandscape)

            Spacer()

            // Bottom controls
            VStack(spacing: 12) {
                Button {
                    viewModel.skip()
                } label: {
                    Text("Skip")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if viewModel.lastAction != nil {
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            viewModel.undo()
                        }
                    } label: {
                        Label("Undo", systemImage: "arrow.uturn.backward")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.bottom, 32)
        }
    }

    @ViewBuilder
    private func comparisonCard(
        identifier: String,
        label: String,
        isKept: Bool,
        action: @escaping () -> Void
    ) -> some View {
        let isDismissed = keptID != nil && !isKept

        VStack(spacing: 6) {
            Button(action: action) {
                DuplicatePhotoView(
                    assetIdentifier: identifier,
                    photoService: photoService
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay {
                    if isKept {
                        // Green checkmark on the kept photo
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.green.opacity(0.3))
                            .overlay {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.white)
                            }
                            .transition(.opacity)
                    } else if isDismissed {
                        // Red tint on the dismissed photo
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.red.opacity(0.3))
                            .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: isKept)
                .animation(.easeInOut(duration: 0.2), value: isDismissed)
            }
            .buttonStyle(.plain)

            VStack(spacing: 2) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if let date = photoService.fetchCreationDate(for: identifier) {
                    Text(date, format: .dateTime.hour().minute().second())
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Done

    @ViewBuilder
    private func doneView(viewModel: DuplicateSweepViewModel) -> some View {
        VStack(spacing: 20) {
            Spacer()

            if viewModel.totalDuplicatesFound == 0 {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("No duplicates found")
                    .font(.title3)
                    .fontWeight(.semibold)
                Text("Try picking a different photo.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "square.on.square")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("Sweep complete")
                    .font(.title3)
                    .fontWeight(.semibold)
                Text("\(viewModel.totalDuplicatesFound) duplicates found — \(viewModel.markedForDeletion) marked for deletion")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            VStack(spacing: 12) {
                if viewModel.markedForDeletion > 0 {
                    Button {
                        Task {
                            let count = await viewModel.batchDelete()
                            if count > 0 {
                                totalDeletedPhotos += count
                                deleteMessage = DeleteFeedback(sessionCount: count, totalCount: totalDeletedPhotos)
                                try? await Task.sleep(for: .seconds(2.5))
                                deleteMessage = nil
                            }
                        }
                    } label: {
                        Text("Delete \(viewModel.markedForDeletion)")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .controlSize(.large)
                    .padding(.horizontal, 40)
                }

                Button {
                    viewModel.phase = .idle
                    showPicker = true
                } label: {
                    Text("Pick Another Photo")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .padding(.horizontal, 40)

                Button("Done") {
                    onClose()
                }
                .font(.subheadline)
            }
            .padding(.bottom, 40)
        }
    }
}

// MARK: - Photo Picker (PHPicker wrapper)

private struct PhotoPickerView: UIViewControllerRepresentable {
    let onSelect: (String) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.selectionLimit = 1
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onSelect: (String) -> Void

        init(onSelect: @escaping (String) -> Void) {
            self.onSelect = onSelect
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let result = results.first,
                  let identifier = result.assetIdentifier else { return }
            onSelect(identifier)
        }
    }
}

// MARK: - Duplicate Photo View (simple image loader)

private struct DuplicatePhotoView: View {
    let assetIdentifier: String
    let photoService: PhotoLibraryService

    @State private var loader: PhotoImageLoader

    init(assetIdentifier: String, photoService: PhotoLibraryService) {
        self.assetIdentifier = assetIdentifier
        self.photoService = photoService
        let screenSize = UIScreen.main.bounds.size
        self._loader = State(initialValue: PhotoImageLoader(
            service: photoService,
            assetIdentifier: assetIdentifier,
            targetSize: CGSize(width: screenSize.width, height: screenSize.height)
        ))
    }

    var body: some View {
        Group {
            if let image = loader.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.secondarySystemBackground))
            }
        }
        .task { await loader.load() }
    }
}
