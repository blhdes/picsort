import Photos
import UIKit

@Observable
final class PhotoLibraryService {

    var authorizationStatus: PHAuthorizationStatus = .notDetermined

    private let imageManager = PHCachingImageManager()

    // MARK: - Authorization

    @MainActor
    func requestAuthorization() async -> PHAuthorizationStatus {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        authorizationStatus = status
        return status
    }

    // MARK: - Fetching

    /// Returns asset identifiers for photos taken on or after `startDate`,
    /// sorted by creation date ascending, excluding identifiers in `excludedIDs`.
    func fetchAssetIdentifiers(
        from startDate: Date,
        excluding excludedIDs: Set<String>
    ) -> [String] {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(
            format: "creationDate >= %@ AND mediaType == %d",
            startDate as NSDate,
            PHAssetMediaType.image.rawValue
        )
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]

        let result = PHAsset.fetchAssets(with: options)

        var identifiers: [String] = []
        identifiers.reserveCapacity(result.count)

        result.enumerateObjects { asset, _, _ in
            if !excludedIDs.contains(asset.localIdentifier) {
                identifiers.append(asset.localIdentifier)
            }
        }

        return identifiers
    }

    // MARK: - Image Loading

    /// Loads a display-quality UIImage for the given asset identifier.
    func loadImage(
        for assetIdentifier: String,
        targetSize: CGSize
    ) async -> UIImage? {
        guard let asset = PHAsset.fetchAssets(
            withLocalIdentifiers: [assetIdentifier],
            options: nil
        ).firstObject else {
            return nil
        }

        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.resizeMode = .fast

        return await withCheckedContinuation { continuation in
            imageManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: options
            ) { image, info in
                // PHImageManager can call this twice (low-quality then high-quality).
                // Only resolve on the final delivery.
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if !isDegraded {
                    continuation.resume(returning: image)
                }
            }
        }
    }

    // MARK: - Preloading

    /// Tells PHCachingImageManager to start caching images for upcoming identifiers.
    func startCaching(identifiers: [String], targetSize: CGSize) {
        let assets = fetchAssets(for: identifiers)
        imageManager.startCachingImages(
            for: assets,
            targetSize: targetSize,
            contentMode: .aspectFit,
            options: nil
        )
    }

    /// Stops caching for identifiers that are no longer needed.
    func stopCaching(identifiers: [String], targetSize: CGSize) {
        let assets = fetchAssets(for: identifiers)
        imageManager.stopCachingImages(
            for: assets,
            targetSize: targetSize,
            contentMode: .aspectFit,
            options: nil
        )
    }

    func stopCachingAll() {
        imageManager.stopCachingImages()
    }

    // MARK: - Private

    private func fetchAssets(for identifiers: [String]) -> [PHAsset] {
        guard !identifiers.isEmpty else { return [] }
        let result = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
        var assets: [PHAsset] = []
        assets.reserveCapacity(result.count)
        result.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        return assets
    }
}
