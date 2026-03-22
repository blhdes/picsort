import SwiftUI
import SwiftData

struct GallerySelectionSheet: View {
    @Query(sort: \Gallery.displayOrder) private var galleries: [Gallery]
    @Binding var selectedIDs: Set<UUID>
    let maxSelection: Int

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var searchText = ""
    @State private var newGalleryName = ""
    @State private var showCreateField = false
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        NavigationStack {
            List {
                if !filteredGalleries.isEmpty {
                    Section {
                        ForEach(filteredGalleries) { gallery in
                            galleryRow(gallery)
                        }
                    } header: {
                        Text("\(selectedIDs.count)/\(maxSelection) selected")
                    }
                }

                Section {
                    if showCreateField {
                        HStack {
                            TextField("Gallery name", text: $newGalleryName)
                                .focused($isFieldFocused)
                                .onSubmit { createGallery() }

                            Button("Add") { createGallery() }
                                .disabled(newGalleryName.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    } else {
                        Button("Create New Gallery") {
                            showCreateField = true
                            isFieldFocused = true
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search galleries")
            .navigationTitle("Select Galleries")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Row

    @ViewBuilder
    private func galleryRow(_ gallery: Gallery) -> some View {
        let isSelected = selectedIDs.contains(gallery.id)
        let atLimit = selectedIDs.count >= maxSelection

        Button {
            if isSelected {
                selectedIDs.remove(gallery.id)
            } else {
                selectedIDs.insert(gallery.id)
            }
        } label: {
            HStack {
                Text(gallery.name)
                    .foregroundStyle(.primary)

                Spacer()

                Text("\(gallery.sortedPhotos.count) photos")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                } else {
                    Image(systemName: "circle")
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .disabled(!isSelected && atLimit)
        .opacity(!isSelected && atLimit ? 0.4 : 1.0)
    }

    // MARK: - Filtering

    private var filteredGalleries: [Gallery] {
        if searchText.isEmpty { return Array(galleries) }
        return galleries.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    // MARK: - Create

    private func createGallery() {
        let name = newGalleryName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        let gallery = Gallery(name: name, displayOrder: galleries.count)
        modelContext.insert(gallery)
        try? modelContext.save()

        if selectedIDs.count < maxSelection {
            selectedIDs.insert(gallery.id)
        }

        newGalleryName = ""
        showCreateField = false

        // Create matching iPhone Photos album
        Task {
            let service = PhotoLibraryService()
            if let albumID = await service.createAlbum(name: name) {
                await MainActor.run {
                    gallery.albumIdentifier = albumID
                    try? modelContext.save()
                }
            }
        }
    }
}
