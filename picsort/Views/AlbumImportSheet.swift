import SwiftUI
import SwiftData

/// Lets the user pick from their iPhone photo albums and import them as app galleries.
/// Albums already imported (matched by albumIdentifier) are hidden.
struct AlbumImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var galleries: [Gallery]

    @State private var phoneAlbums: [PhoneAlbum] = []
    @State private var selectedAlbumIDs: Set<String> = []
    @State private var searchText = ""
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading albums…")
                } else if availableAlbums.isEmpty {
                    ContentUnavailableView(
                        "No Albums to Import",
                        systemImage: "photo.on.rectangle",
                        description: Text("All phone albums have already been imported.")
                    )
                } else {
                    List {
                        Section {
                            ForEach(filteredAlbums) { album in
                                albumRow(album)
                            }
                        } header: {
                            Text("\(selectedAlbumIDs.count) selected")
                        }
                    }
                    .listStyle(.plain)
                    .searchable(text: $searchText, prompt: "Search albums")
                }
            }
            .navigationTitle("Import Albums")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Import") { importSelected() }
                        .fontWeight(.semibold)
                        .disabled(selectedAlbumIDs.isEmpty)
                }
            }
            .task {
                phoneAlbums = PhotoLibraryService.shared.fetchAlbums()
                isLoading = false
            }
        }
    }

    // MARK: - Filtering

    /// Albums not yet imported — no existing Gallery has a matching albumIdentifier.
    private var availableAlbums: [PhoneAlbum] {
        let importedIDs = Set(galleries.compactMap(\.albumIdentifier))
        return phoneAlbums.filter { !importedIDs.contains($0.collectionIdentifier) }
    }

    private var filteredAlbums: [PhoneAlbum] {
        if searchText.isEmpty { return availableAlbums }
        return availableAlbums.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    // MARK: - Row

    @ViewBuilder
    private func albumRow(_ album: PhoneAlbum) -> some View {
        let isSelected = selectedAlbumIDs.contains(album.id)

        Button {
            if isSelected {
                selectedAlbumIDs.remove(album.id)
            } else {
                selectedAlbumIDs.insert(album.id)
            }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(album.name)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)

                    Text("\(album.photoCount) photos")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .primary : .quaternary)
                    .font(.title3)
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: - Import

    private func importSelected() {
        let existingCount = galleries.count
        let albumsToImport = availableAlbums.filter { selectedAlbumIDs.contains($0.id) }
        let service = PhotoLibraryService.shared

        for (index, album) in albumsToImport.enumerated() {
            let gallery = Gallery(
                name: album.name,
                displayOrder: existingCount + index,
                albumIdentifier: album.collectionIdentifier
            )
            modelContext.insert(gallery)

            // Link existing photos in this album as SortedPhoto records
            let identifiers = service.fetchAssetIdentifiers(
                from: .distantPast,
                excluding: [],
                inAlbum: album.collectionIdentifier
            )
            for id in identifiers {
                let sorted = SortedPhoto(assetIdentifier: id, gallery: gallery)
                modelContext.insert(sorted)
            }
        }

        try? modelContext.save()
        dismiss()
    }
}
