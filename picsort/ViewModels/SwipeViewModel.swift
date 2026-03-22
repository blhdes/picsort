import SwiftUI
import SwiftData
import Photos

@Observable
final class SwipeViewModel {

    // MARK: - State

    var currentIdentifier: String?
    var nextIdentifier: String?
    var isLoading = false
    var isEmpty = false
    var showGalleryPicker = false

    // MARK: - Dependencies

    private let photoService: PhotoLibraryService
    private let modelContext: ModelContext
    private let startDate: Date
    private let albumIdentifier: String?

    // MARK: - Queue

    private var identifierQueue: [String] = []
    private let batchSize = 50

    // MARK: - Undo

    private(set) var lastAction: SwipeAction?

    // MARK: - Init

    init(
        photoService: PhotoLibraryService,
        modelContext: ModelContext,
        startDate: Date,
        albumIdentifier: String? = nil
    ) {
        self.photoService = photoService
        self.modelContext = modelContext
        self.startDate = startDate
        self.albumIdentifier = albumIdentifier
    }

    // MARK: - Initial Load

    @MainActor
    func loadInitialBatch() async {
        guard identifierQueue.isEmpty, currentIdentifier == nil else { return }
        isLoading = true

        let excludedIDs = fetchExcludedIdentifiers()
        let fetched = photoService.fetchAssetIdentifiers(
            from: startDate,
            excluding: excludedIDs,
            inAlbum: albumIdentifier
        )

        // Take the first batch
        let batch = Array(fetched.prefix(batchSize))
        identifierQueue = Array(fetched.dropFirst(batchSize))

        if batch.isEmpty {
            isEmpty = true
            isLoading = false
            return
        }

        var queue = batch
        currentIdentifier = queue.removeFirst()

        if !queue.isEmpty {
            nextIdentifier = queue.removeFirst()
        }

        // Put remaining back at the front
        identifierQueue = queue + identifierQueue

        // Preload upcoming photos
        let cacheWindow = Array(identifierQueue.prefix(3))
        let screenSize = UIScreen.main.bounds.size
        photoService.startCaching(
            identifiers: cacheWindow,
            targetSize: CGSize(width: screenSize.width * 2, height: screenSize.height * 2)
        )

        isLoading = false
    }

    // MARK: - Swipe Actions

    /// Swipe left: dismiss current photo.
    @MainActor
    func dismissCurrent() {
        guard let identifier = currentIdentifier else { return }

        let dismissed = DismissedPhoto(assetIdentifier: identifier)
        modelContext.insert(dismissed)
        try? modelContext.save()

        lastAction = .dismissed(assetIdentifier: identifier)
        advance()
    }

    /// Swipe right: show gallery picker (don't advance yet).
    @MainActor
    func sortCurrent() {
        guard currentIdentifier != nil else { return }
        showGalleryPicker = true
    }

    /// Called when user sorts a photo into a gallery.
    @MainActor
    func assignToGallery(_ gallery: Gallery) {
        guard let identifier = currentIdentifier else { return }

        let sorted = SortedPhoto(assetIdentifier: identifier, gallery: gallery)
        modelContext.insert(sorted)
        try? modelContext.save()

        lastAction = .sorted(assetIdentifier: identifier, gallery: gallery)
        showGalleryPicker = false
        advance()

        // Sync to iPhone Photos album (background, non-blocking)
        Task {
            let albumID = await ensureAlbumExists(for: gallery)
            if let albumID {
                await photoService.addPhoto(assetIdentifier: identifier, toAlbum: albumID)
            }
        }
    }

    /// Cancel gallery picking (user dismissed the sheet).
    @MainActor
    func cancelSort() {
        showGalleryPicker = false
    }

    // MARK: - Undo

    @MainActor
    func undo() {
        guard let action = lastAction else { return }

        switch action {
        case .dismissed(let identifier):
            deleteDismissedPhoto(identifier: identifier)
            pushBackToFront(identifier: identifier)

        case .sorted(let identifier, let gallery):
            deleteSortedPhoto(identifier: identifier)
            pushBackToFront(identifier: identifier)

            // Also remove from iPhone Photos album
            if let albumID = gallery.albumIdentifier {
                Task {
                    await photoService.removePhoto(assetIdentifier: identifier, fromAlbum: albumID)
                }
            }
        }

        lastAction = nil
    }

    // MARK: - Private

    @MainActor
    private func advance() {
        currentIdentifier = nextIdentifier

        if identifierQueue.isEmpty {
            nextIdentifier = nil
            if currentIdentifier == nil {
                isEmpty = true
            }
            return
        }

        nextIdentifier = identifierQueue.removeFirst()

        // Update cache window
        let cacheWindow = Array(identifierQueue.prefix(3))
        let screenSize = UIScreen.main.bounds.size
        let targetSize = CGSize(width: screenSize.width * 2, height: screenSize.height * 2)
        photoService.startCaching(identifiers: cacheWindow, targetSize: targetSize)
    }

    private func pushBackToFront(identifier: String) {
        // Move next → back to queue front, current → next, restored → current
        if let next = nextIdentifier {
            identifierQueue.insert(next, at: 0)
        }
        nextIdentifier = currentIdentifier
        currentIdentifier = identifier
        isEmpty = false
    }

    private func fetchExcludedIdentifiers() -> Set<String> {
        var excluded = Set<String>()

        let sortedDescriptor = FetchDescriptor<SortedPhoto>()
        if let sorted = try? modelContext.fetch(sortedDescriptor) {
            for photo in sorted {
                excluded.insert(photo.assetIdentifier)
            }
        }

        let dismissedDescriptor = FetchDescriptor<DismissedPhoto>()
        if let dismissed = try? modelContext.fetch(dismissedDescriptor) {
            for photo in dismissed {
                excluded.insert(photo.assetIdentifier)
            }
        }

        return excluded
    }

    private func deleteDismissedPhoto(identifier: String) {
        let predicate = #Predicate<DismissedPhoto> { $0.assetIdentifier == identifier }
        let descriptor = FetchDescriptor(predicate: predicate)
        if let match = try? modelContext.fetch(descriptor).first {
            modelContext.delete(match)
            try? modelContext.save()
        }
    }

    private func deleteSortedPhoto(identifier: String) {
        let predicate = #Predicate<SortedPhoto> { $0.assetIdentifier == identifier }
        let descriptor = FetchDescriptor(predicate: predicate)
        if let match = try? modelContext.fetch(descriptor).first {
            modelContext.delete(match)
            try? modelContext.save()
        }
    }

    /// Creates the iPhone album for a gallery if it doesn't exist yet.
    /// Returns the album identifier.
    private func ensureAlbumExists(for gallery: Gallery) async -> String? {
        if let existing = gallery.albumIdentifier {
            return existing
        }

        let albumID = await photoService.createAlbum(name: gallery.name)
        if let albumID {
            await MainActor.run {
                gallery.albumIdentifier = albumID
                try? modelContext.save()
            }
        }
        return albumID
    }
}

// MARK: - Supporting Types

enum SwipeAction {
    case dismissed(assetIdentifier: String)
    case sorted(assetIdentifier: String, gallery: Gallery)
}
