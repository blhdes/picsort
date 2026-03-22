import Foundation
import SwiftData

@Model
final class Gallery {
    var id: UUID
    var name: String
    var iconName: String
    var colorHex: String
    var displayOrder: Int
    var createdAt: Date

    /// Links to a real iPhone Photos album. Nil until the album is created.
    var albumIdentifier: String?

    @Relationship(deleteRule: .cascade, inverse: \SortedPhoto.gallery)
    var sortedPhotos: [SortedPhoto]

    init(
        name: String,
        iconName: String = "folder.fill",
        colorHex: String = "#007AFF",
        displayOrder: Int = 0,
        albumIdentifier: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.iconName = iconName
        self.colorHex = colorHex
        self.displayOrder = displayOrder
        self.createdAt = .now
        self.albumIdentifier = albumIdentifier
        self.sortedPhotos = []
    }
}
