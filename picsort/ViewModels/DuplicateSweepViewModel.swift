import SwiftUI
import SwiftData

@Observable
final class DuplicateSweepViewModel {

    enum Phase { case idle, scanning, comparing, done }

    // MARK: - State

    var phase: Phase = .idle

    /// The photo the user picked as reference.
    var referenceIdentifier: String?

    /// The current duplicate being compared against the reference.
    var currentDuplicateIdentifier: String?

    // Stats
    private(set) var totalDuplicatesFound: Int = 0
    private(set) var markedForDeletion: Int = 0
    private(set) var currentIndex: Int = 0

    // MARK: - Private

    private var duplicateQueue: [String] = []
    private let scanner = DuplicateScannerService()
    private let photoService = PhotoLibraryService.shared
    private let modelContext: ModelContext

    // Undo: stores (dismissed identifier, previous reference if it changed)
    private(set) var lastAction: DuplicateSweepAction?

    // MARK: - Init

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Search

    @MainActor
    func startSearch(for assetIdentifier: String) async {
        phase = .scanning
        referenceIdentifier = assetIdentifier
        lastAction = nil

        let matches = await scanner.findDuplicates(
            of: assetIdentifier,
            excluding: []
        )

        totalDuplicatesFound = matches.count

        if matches.isEmpty {
            phase = .done
            return
        }

        duplicateQueue = matches
        currentDuplicateIdentifier = duplicateQueue.removeFirst()
        currentIndex = 1
        phase = .comparing
    }

    // MARK: - Actions

    /// User taps the reference photo — keep it, dismiss the duplicate.
    @MainActor
    func keepReference() {
        guard let duplicateID = currentDuplicateIdentifier else { return }

        dismiss(identifier: duplicateID)
        lastAction = .dismissedDuplicate(identifier: duplicateID)
        advance()
    }

    /// User taps the duplicate — keep it, dismiss the reference, duplicate becomes new reference.
    @MainActor
    func keepDuplicate() {
        guard let referenceID = referenceIdentifier,
              let duplicateID = currentDuplicateIdentifier else { return }

        dismiss(identifier: referenceID)
        lastAction = .dismissedReference(
            identifier: referenceID,
            newReference: duplicateID
        )
        referenceIdentifier = duplicateID
        advance()
    }

    /// Skip this comparison without deciding.
    @MainActor
    func skip() {
        lastAction = nil
        advance()
    }

    /// Undo the last keep/dismiss action.
    @MainActor
    func undo() {
        guard let action = lastAction else { return }

        switch action {
        case .dismissedDuplicate(let identifier):
            removeDismissedRecord(identifier: identifier)
            markedForDeletion = max(markedForDeletion - 1, 0)
            // Push current duplicate back and restore the undone one
            if let current = currentDuplicateIdentifier {
                duplicateQueue.insert(current, at: 0)
            }
            currentDuplicateIdentifier = identifier
            currentIndex = max(currentIndex - 1, 1)
            phase = .comparing

        case .dismissedReference(let identifier, let newReference):
            removeDismissedRecord(identifier: identifier)
            markedForDeletion = max(markedForDeletion - 1, 0)
            // Restore the old reference, push current duplicate back
            referenceIdentifier = identifier
            if let current = currentDuplicateIdentifier {
                duplicateQueue.insert(current, at: 0)
            }
            currentDuplicateIdentifier = newReference
            currentIndex = max(currentIndex - 1, 1)
            phase = .comparing
        }

        lastAction = nil
    }

    /// Batch delete all dismissed photos. Returns the count deleted.
    @MainActor
    func batchDelete() async -> Int {
        let descriptor = FetchDescriptor<DismissedPhoto>()
        guard let dismissed = try? modelContext.fetch(descriptor), !dismissed.isEmpty else {
            return 0
        }

        let identifiers = dismissed.map(\.assetIdentifier)
        let deletedCount = await photoService.deletePhotos(identifiers: identifiers)

        if deletedCount > 0 {
            for record in dismissed {
                modelContext.delete(record)
            }
            try? modelContext.save()
        }

        return deletedCount
    }

    // MARK: - Private

    @MainActor
    private func advance() {
        if duplicateQueue.isEmpty {
            currentDuplicateIdentifier = nil
            phase = .done
            return
        }

        currentDuplicateIdentifier = duplicateQueue.removeFirst()
        currentIndex += 1
    }

    private func dismiss(identifier: String) {
        let dismissed = DismissedPhoto(assetIdentifier: identifier)
        modelContext.insert(dismissed)
        try? modelContext.save()
        markedForDeletion += 1
    }

    private func removeDismissedRecord(identifier: String) {
        let predicate = #Predicate<DismissedPhoto> { $0.assetIdentifier == identifier }
        let descriptor = FetchDescriptor(predicate: predicate)
        if let match = try? modelContext.fetch(descriptor).first {
            modelContext.delete(match)
            try? modelContext.save()
        }
    }

}

// MARK: - Action Types

enum DuplicateSweepAction {
    case dismissedDuplicate(identifier: String)
    case dismissedReference(identifier: String, newReference: String)
}
