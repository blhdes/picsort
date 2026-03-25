import SwiftUI
import SwiftData

@Observable
final class DismissedPhotosViewModel {

    var dismissedPhotos: [DismissedPhoto] = []
    var selectedIdentifiers: Set<String> = []
    var isDeleting = false

    var hasSelection: Bool { !selectedIdentifiers.isEmpty }
    var selectedCount: Int { selectedIdentifiers.count }

    private let photoService = PhotoLibraryService.shared
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Load

    func loadDismissedPhotos() {
        let descriptor = FetchDescriptor<DismissedPhoto>(
            sortBy: [SortDescriptor(\.dismissedAt, order: .reverse)]
        )
        dismissedPhotos = (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - Selection

    func toggleSelection(_ identifier: String) {
        if selectedIdentifiers.contains(identifier) {
            selectedIdentifiers.remove(identifier)
        } else {
            selectedIdentifiers.insert(identifier)
        }
    }

    func selectAll() {
        selectedIdentifiers = Set(dismissedPhotos.map(\.assetIdentifier))
    }

    func deselectAll() {
        selectedIdentifiers.removeAll()
    }

    // MARK: - Recover

    /// Removes DismissedPhoto records from SwiftData. Photos stay in the library.
    func recoverSelected() {
        for photo in dismissedPhotos where selectedIdentifiers.contains(photo.assetIdentifier) {
            modelContext.delete(photo)
        }
        try? modelContext.save()
        selectedIdentifiers.removeAll()
        loadDismissedPhotos()
    }

    func recoverAll() {
        for photo in dismissedPhotos {
            modelContext.delete(photo)
        }
        try? modelContext.save()
        selectedIdentifiers.removeAll()
        loadDismissedPhotos()
    }

    // MARK: - Delete

    /// Permanently deletes photos from the library and removes SwiftData records.
    @MainActor
    func deleteSelected() async -> Int {
        isDeleting = true
        let targets = dismissedPhotos.filter { selectedIdentifiers.contains($0.assetIdentifier) }
        let identifiers = targets.map(\.assetIdentifier)

        let count = await photoService.deletePhotos(identifiers: identifiers)

        if count > 0 {
            for record in targets {
                modelContext.delete(record)
            }
            try? modelContext.save()
        }

        selectedIdentifiers.removeAll()
        loadDismissedPhotos()
        isDeleting = false
        return count
    }

    @MainActor
    func deleteAll() async -> Int {
        isDeleting = true
        let identifiers = dismissedPhotos.map(\.assetIdentifier)

        let count = await photoService.deletePhotos(identifiers: identifiers)

        if count > 0 {
            for record in dismissedPhotos {
                modelContext.delete(record)
            }
            try? modelContext.save()
        }

        selectedIdentifiers.removeAll()
        loadDismissedPhotos()
        isDeleting = false
        return count
    }
}
