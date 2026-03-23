import Photos
import UIKit

@Observable
final class PhotoLibraryService {

    /// Shared instance — avoids creating multiple PHCachingImageManagers.
    static let shared = PhotoLibraryService()

    var authorizationStatus: PHAuthorizationStatus = .notDetermined

    private let imageManager = PHCachingImageManager()

    // MARK: - Authorization

    @MainActor
    func requestAuthorization() async -> PHAuthorizationStatus {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        authorizationStatus = status
        return status
    }

    // MARK: - Date Range

    /// Returns the creation dates of the earliest and latest photos in the library.
    func photoDateRange() -> (earliest: Date, latest: Date)? {
        let imageType = PHAssetMediaType.image.rawValue

        let earliestOptions = PHFetchOptions()
        earliestOptions.predicate = NSPredicate(format: "mediaType == %d", imageType)
        earliestOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        earliestOptions.fetchLimit = 1

        let latestOptions = PHFetchOptions()
        latestOptions.predicate = NSPredicate(format: "mediaType == %d", imageType)
        latestOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        latestOptions.fetchLimit = 1

        let earliest = PHAsset.fetchAssets(with: earliestOptions).firstObject?.creationDate
        let latest = PHAsset.fetchAssets(with: latestOptions).firstObject?.creationDate

        guard let earliest, let latest else { return nil }
        return (earliest, latest)
    }

    // MARK: - Favorite Toggle

    /// Toggles the favorite state of a photo. Returns the new state (true = now favorited).
    func toggleFavorite(identifier: String) async -> Bool {
        guard let asset = PHAsset.fetchAssets(
            withLocalIdentifiers: [identifier], options: nil
        ).firstObject else { return false }

        let newValue = !asset.isFavorite
        do {
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetChangeRequest(for: asset)
                request.isFavorite = newValue
            }
            return newValue
        } catch {
            print("picsort: Failed to toggle favorite: \(error)")
            return asset.isFavorite
        }
    }

    // MARK: - Album Write Operations

    /// Creates a new album in the iPhone Photos library. Returns its localIdentifier.
    /// If an album with the same name already exists, returns that one instead.
    func createAlbum(name: String) async -> String? {
        // Check if album already exists
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title == %@", name)
        let existing = PHAssetCollection.fetchAssetCollections(
            with: .album, subtype: .any, options: fetchOptions
        )
        if let existingAlbum = existing.firstObject {
            return existingAlbum.localIdentifier
        }

        // Create new album
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: name)
            }
            // Fetch the newly created album
            let result = PHAssetCollection.fetchAssetCollections(
                with: .album, subtype: .any, options: fetchOptions
            )
            return result.firstObject?.localIdentifier
        } catch {
            print("picsort: Failed to create album '\(name)': \(error)")
            return nil
        }
    }

    /// Adds a photo to an iPhone Photos album.
    func addPhoto(assetIdentifier: String, toAlbum albumIdentifier: String) async {
        guard let asset = PHAsset.fetchAssets(
            withLocalIdentifiers: [assetIdentifier], options: nil
        ).firstObject,
              let album = PHAssetCollection.fetchAssetCollections(
            withLocalIdentifiers: [albumIdentifier], options: nil
        ).firstObject else { return }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                guard let request = PHAssetCollectionChangeRequest(for: album) else { return }
                request.addAssets([asset] as NSFastEnumeration)
            }
        } catch {
            print("picsort: Failed to add photo to album: \(error)")
        }
    }

    /// Permanently deletes photos from the iPhone library. iOS shows one confirmation dialog.
    /// Returns the number of photos actually deleted.
    func deletePhotos(identifiers: [String]) async -> Int {
        guard !identifiers.isEmpty else { return 0 }

        let assets = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
        guard assets.count > 0 else { return 0 }

        let count = assets.count
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(assets as NSFastEnumeration)
            }
            return count
        } catch {
            print("picsort: Failed to delete photos: \(error)")
            return 0
        }
    }

    /// Removes a photo from an iPhone Photos album (does NOT delete the photo itself).
    func removePhoto(assetIdentifier: String, fromAlbum albumIdentifier: String) async {
        guard let asset = PHAsset.fetchAssets(
            withLocalIdentifiers: [assetIdentifier], options: nil
        ).firstObject,
              let album = PHAssetCollection.fetchAssetCollections(
            withLocalIdentifiers: [albumIdentifier], options: nil
        ).firstObject else { return }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                guard let request = PHAssetCollectionChangeRequest(for: album) else { return }
                request.removeAssets([asset] as NSFastEnumeration)
            }
        } catch {
            print("picsort: Failed to remove photo from album: \(error)")
        }
    }

    /// Deletes an iPhone Photos album (does NOT delete the photos inside it).
    func deleteAlbum(identifier: String) async {
        guard let album = PHAssetCollection.fetchAssetCollections(
            withLocalIdentifiers: [identifier], options: nil
        ).firstObject else { return }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetCollectionChangeRequest.deleteAssetCollections(
                    [album] as NSFastEnumeration
                )
            }
        } catch {
            print("picsort: Failed to delete album: \(error)")
        }
    }

    // MARK: - Album Fetching

    /// Fetches all user-created and smart albums that contain at least one photo.
    func fetchAlbums() -> [PhoneAlbum] {
        var albums: [PhoneAlbum] = []

        let userAlbums = PHAssetCollection.fetchAssetCollections(
            with: .album, subtype: .any, options: nil
        )
        userAlbums.enumerateObjects { collection, _, _ in
            let album = PhoneAlbum(collection: collection)
            if album.photoCount > 0 {
                albums.append(album)
            }
        }

        let smartAlbums = PHAssetCollection.fetchAssetCollections(
            with: .smartAlbum, subtype: .any, options: nil
        )
        smartAlbums.enumerateObjects { collection, _, _ in
            let album = PhoneAlbum(collection: collection)
            if album.photoCount > 0 {
                albums.append(album)
            }
        }

        return albums
    }

    // MARK: - Metadata

    /// Returns the creation date for a single photo asset.
    func fetchCreationDate(for identifier: String) -> Date? {
        let result = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        return result.firstObject?.creationDate
    }

    // MARK: - Fetching

    /// Returns asset identifiers for photos taken on or after `startDate`,
    /// sorted by creation date ascending, excluding identifiers in `excludedIDs`.
    /// If `albumIdentifier` is provided, only fetches photos from that album.
    /// The special sentinel `PhoneAlbum.unsortedIdentifier` fetches only unsorted photos.
    func fetchAssetIdentifiers(
        from startDate: Date,
        excluding excludedIDs: Set<String>,
        inAlbum albumIdentifier: String? = nil
    ) -> [String] {
        // Handle the "Unsorted Photos" virtual album
        if albumIdentifier == PhoneAlbum.unsortedIdentifier {
            return fetchUnsortedAssetIdentifiers(from: startDate, excluding: excludedIDs)
        }

        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(
            format: "creationDate >= %@ AND mediaType == %d",
            startDate as NSDate,
            PHAssetMediaType.image.rawValue
        )
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]

        let result: PHFetchResult<PHAsset>

        if let albumIdentifier,
           let collection = PHAssetCollection.fetchAssetCollections(
               withLocalIdentifiers: [albumIdentifier], options: nil
           ).firstObject {
            result = PHAsset.fetchAssets(in: collection, options: fetchOptions)
        } else {
            result = PHAsset.fetchAssets(with: fetchOptions)
        }

        var identifiers: [String] = []
        identifiers.reserveCapacity(result.count)

        result.enumerateObjects { asset, _, _ in
            if !excludedIDs.contains(asset.localIdentifier) {
                identifiers.append(asset.localIdentifier)
            }
        }

        return identifiers
    }

    /// Returns asset identifiers for photos taken on today's month+day in past years.
    /// Sorted oldest first. Excludes current year and identifiers in `excludedIDs`.
    func fetchOnThisDayIdentifiers(
        excluding excludedIDs: Set<String>,
        inAlbum albumIdentifier: String? = nil
    ) -> [String] {
        let calendar = Calendar.current
        let today = calendar.dateComponents([.month, .day], from: .now)
        let currentYear = calendar.component(.year, from: .now)

        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(
            format: "mediaType == %d",
            PHAssetMediaType.image.rawValue
        )
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]

        let result: PHFetchResult<PHAsset>

        if let albumIdentifier,
           albumIdentifier != PhoneAlbum.unsortedIdentifier,
           let collection = PHAssetCollection.fetchAssetCollections(
               withLocalIdentifiers: [albumIdentifier], options: nil
           ).firstObject {
            result = PHAsset.fetchAssets(in: collection, options: fetchOptions)
        } else {
            result = PHAsset.fetchAssets(with: fetchOptions)
        }

        var identifiers: [String] = []

        result.enumerateObjects { asset, _, _ in
            guard let date = asset.creationDate else { return }
            let components = calendar.dateComponents([.month, .day, .year], from: date)
            guard components.month == today.month,
                  components.day == today.day,
                  components.year != currentYear else { return }
            if !excludedIDs.contains(asset.localIdentifier) {
                identifiers.append(asset.localIdentifier)
            }
        }

        return identifiers
    }

    /// Returns the count of photos not in any user-created album.
    func unsortedPhotoCount() -> Int {
        let albummedIDs = identifiersInAllUserAlbums()

        let options = PHFetchOptions()
        options.predicate = NSPredicate(
            format: "mediaType == %d",
            PHAssetMediaType.image.rawValue
        )
        let allAssets = PHAsset.fetchAssets(with: options)

        var count = 0
        allAssets.enumerateObjects { asset, _, _ in
            if !albummedIDs.contains(asset.localIdentifier) {
                count += 1
            }
        }
        return count
    }

    // MARK: - Unsorted Fetching

    /// Returns identifiers for photos not in any user-created album,
    /// filtered by start date and exclusion set.
    private func fetchUnsortedAssetIdentifiers(
        from startDate: Date,
        excluding excludedIDs: Set<String>
    ) -> [String] {
        let albummedIDs = identifiersInAllUserAlbums()

        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(
            format: "creationDate >= %@ AND mediaType == %d",
            startDate as NSDate,
            PHAssetMediaType.image.rawValue
        )
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]

        let allAssets = PHAsset.fetchAssets(with: fetchOptions)

        var identifiers: [String] = []
        allAssets.enumerateObjects { asset, _, _ in
            let id = asset.localIdentifier
            if !albummedIDs.contains(id) && !excludedIDs.contains(id) {
                identifiers.append(id)
            }
        }
        return identifiers
    }

    /// Collects all asset identifiers that belong to at least one user-created album.
    private func identifiersInAllUserAlbums() -> Set<String> {
        var albummedIDs = Set<String>()

        let userAlbums = PHAssetCollection.fetchAssetCollections(
            with: .album, subtype: .any, options: nil
        )
        userAlbums.enumerateObjects { collection, _, _ in
            let assets = PHAsset.fetchAssets(in: collection, options: nil)
            assets.enumerateObjects { asset, _, _ in
                albummedIDs.insert(asset.localIdentifier)
            }
        }

        return albummedIDs
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
        imageManager.stopCachingImagesForAllAssets()
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
