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

    // Progress
    private(set) var totalCount: Int = 0
    private(set) var processedCount: Int = 0

    // Current photo metadata
    var currentPhotoDate: Date?

    // Focus Session tracking
    private(set) var sessionSortedCount: Int = 0
    private(set) var sessionDismissedCount: Int = 0
    private(set) var sessionGalleries: Set<UUID> = []

    // MARK: - Dependencies

    private let photoService: PhotoLibraryService
    private let modelContext: ModelContext
    private let startDate: Date
    private let albumIdentifier: String?
    private let sortMode: SortMode
    private let isOnThisDay: Bool

    // MARK: - Queue

    private var identifierQueue: [String] = []
    private let batchSize = 50
    private var cachedIdentifiers: [String] = []

    // MARK: - Undo

    private(set) var lastAction: SwipeAction?

    // MARK: - Cached Counts

    /// Cached count of dismissed photos — updated only on dismiss/undo/delete, not every frame.
    private(set) var dismissedCount: Int = 0

    // MARK: - Init

    init(
        photoService: PhotoLibraryService,
        modelContext: ModelContext,
        startDate: Date,
        albumIdentifier: String? = nil,
        sortMode: SortMode = .copy,
        isOnThisDay: Bool = false
    ) {
        self.photoService = photoService
        self.modelContext = modelContext
        self.startDate = startDate
        self.albumIdentifier = albumIdentifier
        self.sortMode = sortMode
        self.isOnThisDay = isOnThisDay
        self.dismissedCount = Self.fetchDismissedCount(modelContext: modelContext)
    }

    private static func fetchDismissedCount(modelContext: ModelContext) -> Int {
        let descriptor = FetchDescriptor<DismissedPhoto>()
        return (try? modelContext.fetchCount(descriptor)) ?? 0
    }

    // MARK: - Initial Load

    @MainActor
    func loadInitialBatch() async {
        guard identifierQueue.isEmpty, currentIdentifier == nil else { return }
        isLoading = true

        let excludedIDs = fetchExcludedIdentifiers()
        let fetched: [String]
        if isOnThisDay {
            fetched = photoService.fetchOnThisDayIdentifiers(
                excluding: excludedIDs,
                inAlbum: albumIdentifier
            )
        } else {
            fetched = photoService.fetchAssetIdentifiers(
                from: startDate,
                excluding: excludedIDs,
                inAlbum: albumIdentifier
            )
        }

        totalCount = fetched.count

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
        currentPhotoDate = photoService.fetchCreationDate(for: currentIdentifier!)

        if !queue.isEmpty {
            nextIdentifier = queue.removeFirst()
        }

        // Put remaining back at the front
        identifierQueue = queue + identifierQueue

        // Preload upcoming photos
        let screenSize = UIScreen.main.bounds.size
        let targetSize = CGSize(width: screenSize.width * 2, height: screenSize.height * 2)
        cachedIdentifiers = Array(identifierQueue.prefix(3))
        photoService.startCaching(identifiers: cachedIdentifiers, targetSize: targetSize)

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
        dismissedCount += 1
        sessionDismissedCount += 1
        advance()
    }

    /// Double-tap: skip photo without dismissing — it will reappear next session.
    @MainActor
    func skipCurrent() {
        guard currentIdentifier != nil else { return }
        lastAction = nil
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
        sessionSortedCount += 1
        sessionGalleries.insert(gallery.id)
        showGalleryPicker = false
        advance()

        // Sync to iPhone Photos album (background, non-blocking)
        Task {
            let albumID = await ensureAlbumExists(for: gallery)
            if let albumID {
                await photoService.addPhoto(assetIdentifier: identifier, toAlbum: albumID)
            }

            // If moving (not copying), remove from source album
            if sortMode == .move, let sourceAlbum = albumIdentifier,
               sourceAlbum != PhoneAlbum.unsortedIdentifier {
                await photoService.removePhoto(assetIdentifier: identifier, fromAlbum: sourceAlbum)
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
            dismissedCount = max(dismissedCount - 1, 0)
            sessionDismissedCount = max(sessionDismissedCount - 1, 0)
            pushBackToFront(identifier: identifier)

        case .sorted(let identifier, let gallery):
            deleteSortedPhoto(identifier: identifier)
            sessionSortedCount = max(sessionSortedCount - 1, 0)
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

    // MARK: - Batch Delete

    /// Deletes all dismissed photos from the iPhone library.
    /// Returns the number of photos deleted (0 if user denied or nothing to delete).
    @MainActor
    func batchDeleteDismissed() async -> Int {
        let descriptor = FetchDescriptor<DismissedPhoto>()
        guard let dismissed = try? modelContext.fetch(descriptor), !dismissed.isEmpty else {
            return 0
        }

        let identifiers = dismissed.map(\.assetIdentifier)
        let deletedCount = await photoService.deletePhotos(identifiers: identifiers)

        // Only clean up records if the deletion actually happened
        if deletedCount > 0 {
            for record in dismissed {
                modelContext.delete(record)
            }
            try? modelContext.save()
            dismissedCount = 0
        }

        return deletedCount
    }

    // MARK: - Private

    @MainActor
    private func advance() {
        processedCount += 1
        currentIdentifier = nextIdentifier

        if let current = currentIdentifier {
            currentPhotoDate = photoService.fetchCreationDate(for: current)
        } else {
            currentPhotoDate = nil
        }

        if identifierQueue.isEmpty {
            nextIdentifier = nil
            if currentIdentifier == nil {
                isEmpty = true
            }
            return
        }

        nextIdentifier = identifierQueue.removeFirst()

        // Update cache window — stop caching old images, start caching new ones
        let screenSize = UIScreen.main.bounds.size
        let targetSize = CGSize(width: screenSize.width * 2, height: screenSize.height * 2)
        let newWindow = Array(identifierQueue.prefix(3))
        let stale = cachedIdentifiers.filter { !newWindow.contains($0) }
        if !stale.isEmpty {
            photoService.stopCaching(identifiers: stale, targetSize: targetSize)
        }
        cachedIdentifiers = newWindow
        photoService.startCaching(identifiers: newWindow, targetSize: targetSize)
    }

    private func pushBackToFront(identifier: String) {
        processedCount = max(processedCount - 1, 0)
        // Move next → back to queue front, current → next, restored → current
        if let next = nextIdentifier {
            identifierQueue.insert(next, at: 0)
        }
        nextIdentifier = currentIdentifier
        currentIdentifier = identifier
        currentPhotoDate = photoService.fetchCreationDate(for: identifier)
        isEmpty = false
    }

    private func fetchExcludedIdentifiers() -> Set<String> {
        var excluded = Set<String>()

        // Only exclude photos the user actually sorted — not imports.
        // Imported photos should still appear so the user can move/copy
        // them to other galleries.
        let sortedDescriptor = FetchDescriptor<SortedPhoto>(
            predicate: #Predicate<SortedPhoto> { !$0.isImported }
        )
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

/// When sorting from an existing album, determines whether photos
/// are moved out of the source album or kept in both.
enum SortMode {
    case move   // remove from source album after sorting
    case copy   // keep in source album too
}
