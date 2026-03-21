import Foundation
import SwiftData

@Model
final class DismissedPhoto {
    #Unique<DismissedPhoto>([\.assetIdentifier])

    var id: UUID
    var assetIdentifier: String
    var dismissedAt: Date

    init(assetIdentifier: String) {
        self.id = UUID()
        self.assetIdentifier = assetIdentifier
        self.dismissedAt = .now
    }
}
