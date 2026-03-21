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

    // MARK: - Queue

    private var identifierQueue: [String] = []
    private let batchSize = 50

    // MARK: - Undo

    private(set) var lastAction: SwipeAction?

    // MARK: - Init

    init(photoService: PhotoLibraryService, modelContext: ModelContext, startDate: Date) {
        self.photoService = photoService
        self.modelContext = modelContext
        self.startDate = startDate
    }

    // MARK: - Initial Load

    @MainActor
    func loadInitialBatch() async {
        guard identifierQueue.isEmpty, currentIdentifier == nil else { return }
        isLoading = true

        let excludedIDs = fetchExcludedIdentifiers()
        let fetched = photoService.fetchAssetIdentifiers(from: startDate, excluding: excludedIDs)

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

    /// Called from GalleryPickerSheet when user picks a gallery.
    @MainActor
    func assignToGallery(_ gallery: Gallery) {
        guard let identifier = currentIdentifier else { return }

        let sorted = SortedPhoto(assetIdentifier: identifier, gallery: gallery)
        modelContext.insert(sorted)
        try? modelContext.save()

        lastAction = .sorted(assetIdentifier: identifier, gallery: gallery)
        showGalleryPicker = false
        advance()
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

        case .sorted(let identifier, _):
            deleteSortedPhoto(identifier: identifier)
            pushBackToFront(identifier: identifier)
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
}

// MARK: - Supporting Types

enum SwipeAction {
    case dismissed(assetIdentifier: String)
    case sorted(assetIdentifier: String, gallery: Gallery)
}
