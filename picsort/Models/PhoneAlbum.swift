import Photos

/// Represents an album from the user's phone photo library.
/// Not persisted — fetched fresh from PhotoKit each time.
struct PhoneAlbum: Identifiable, Hashable {
    let id: String
    let name: String
    let photoCount: Int
    let startDate: Date?
    let endDate: Date?

    /// The underlying PhotoKit collection identifier, used to fetch photos from this album.
    let collectionIdentifier: String

    init(collection: PHAssetCollection) {
        self.id = collection.localIdentifier
        self.collectionIdentifier = collection.localIdentifier
        self.name = collection.localizedTitle ?? "Untitled"
        self.startDate = collection.startDate
        self.endDate = collection.endDate

        // estimatedAssetCount can return NSNotFound for smart albums,
        // so we do a real count in that case.
        let estimated = collection.estimatedAssetCount
        if estimated != NSNotFound {
            self.photoCount = estimated
        } else {
            let options = PHFetchOptions()
            options.predicate = NSPredicate(
                format: "mediaType == %d",
                PHAssetMediaType.image.rawValue
            )
            self.photoCount = PHAsset.fetchAssets(in: collection, options: options).count
        }
    }
}

enum AlbumSortOption: String, CaseIterable {
    case name = "Name"
    case photoCount = "Photo Count"
    case dateCreated = "Date Created"
}
