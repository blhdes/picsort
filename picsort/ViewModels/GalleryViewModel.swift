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
            let service = PhotoLibraryService()
            if let albumID = await service.createAlbum(name: name) {
                await MainActor.run {
                    gallery.albumIdentifier = albumID
                    self.save()
                }
            }
        }
    }

    // MARK: - Delete

    func deleteGallery(_ gallery: Gallery) {
        modelContext.delete(gallery)
        save()
        fetchGalleries()
        renumberDisplayOrder()
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
