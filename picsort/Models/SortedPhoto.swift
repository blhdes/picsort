import Foundation
import SwiftData

@Model
final class SortedPhoto {
    var id: UUID
    var assetIdentifier: String
    var sortedAt: Date
    var gallery: Gallery?

    init(assetIdentifier: String, gallery: Gallery) {
        self.id = UUID()
        self.assetIdentifier = assetIdentifier
        self.sortedAt = .now
        self.gallery = gallery
    }
}
