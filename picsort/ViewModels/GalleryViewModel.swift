import SwiftUI
import SwiftData

@Observable
final class GalleryViewModel {
    var galleries: [Gallery] = []

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        fetchGalleries()
    }

    // MARK: - Fetch

    func fetchGalleries() {
        let descriptor = FetchDescriptor<Gallery>(sortBy: [SortDescriptor(\.displayOrder)])
        galleries = (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - Create

    func createGallery(name: String, iconName: String = "folder.fill", colorHex: String = "#007AFF") {
        let gallery = Gallery(
            name: name,
            iconName: iconName,
            colorHex: colorHex,
            displayOrder: galleries.count
        )
        modelContext.insert(gallery)
        save()
        fetchGalleries()

        // Create matching iPhone Photos album
        Task {
            let service = PhotoLibraryService.shared
            if let albumID = await service.createAlbum(name: name) {
                await MainActor.run {
                    gallery.albumIdentifier = albumID
                    self.save()
                }
            }
        }
    }

    // MARK: - Delete

    /// Unlinks the gallery from picsort only. iPhone album and photos stay untouched.
    /// The gallery can be re-imported later via "Import from Phone."
    func unlinkGallery(_ gallery: Gallery) {
        modelContext.delete(gallery)
        save()
        fetchGalleries()
        renumberDisplayOrder()
    }

    /// Removes the gallery from picsort AND deletes the iPhone album.
    /// Photos stay in the library but lose their album grouping.
    func deleteGallery(_ gallery: Gallery) {
        let albumID = gallery.albumIdentifier
        modelContext.delete(gallery)
        save()
        fetchGalleries()
        renumberDisplayOrder()

        if let albumID {
            Task {
                await PhotoLibraryService.shared.deleteAlbum(identifier: albumID)
            }
        }
    }

    /// Removes the gallery, deletes the iPhone album, AND permanently deletes all photos.
    func deleteGalleryAndPhotos(_ gallery: Gallery) {
        let identifiers = gallery.sortedPhotos.map(\.assetIdentifier)
        let albumID = gallery.albumIdentifier

        modelContext.delete(gallery)
        save()
        fetchGalleries()
        renumberDisplayOrder()

        Task {
            // Delete the photos from the phone library
            let service = PhotoLibraryService.shared
            if !identifiers.isEmpty {
                _ = await service.deletePhotos(identifiers: identifiers)
            }
            // Delete the album itself
            if let albumID {
                await service.deleteAlbum(identifier: albumID)
            }
        }
    }

    // MARK: - Rename

    func renameGallery(_ gallery: Gallery, to newName: String) {
        gallery.name = newName
        save()
    }

    // MARK: - Reorder

    func moveGallery(from source: IndexSet, to destination: Int) {
        galleries.move(fromOffsets: source, toOffset: destination)
        renumberDisplayOrder()
    }

    // MARK: - Private

    private func renumberDisplayOrder() {
        for (index, gallery) in galleries.enumerated() {
            gallery.displayOrder = index
        }
        save()
    }

    private func save() {
        try? modelContext.save()
    }
}
