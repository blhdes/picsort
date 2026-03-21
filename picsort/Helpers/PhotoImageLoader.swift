import SwiftUI

@Observable
final class PhotoImageLoader {
    var image: UIImage?
    var isLoading = false

    private let service: PhotoLibraryService
    private let assetIdentifier: String
    private let targetSize: CGSize

    init(service: PhotoLibraryService, assetIdentifier: String, targetSize: CGSize) {
        self.service = service
        self.assetIdentifier = assetIdentifier
        self.targetSize = targetSize
    }

    @MainActor
    func load() async {
        guard image == nil, !isLoading else { return }
        isLoading = true
        image = await service.loadImage(for: assetIdentifier, targetSize: targetSize)
        isLoading = false
    }
}
