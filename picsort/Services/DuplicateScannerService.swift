import Vision
import Photos
import UIKit

/// Finds visually similar photos near a reference photo using Vision framework fingerprinting.
final class DuplicateScannerService {

    private let photoService = PhotoLibraryService.shared

    /// Fingerprint a single photo and find similar photos nearby in time.
    /// Returns identifiers of matching photos, sorted by similarity (closest first).
    func findDuplicates(
        of assetIdentifier: String,
        timeWindow: TimeInterval = 3600,
        distanceThreshold: Float = 0.5,
        excluding: Set<String>
    ) async -> [String] {
        // 1. Get the reference asset and its creation date
        guard let referenceAsset = PHAsset.fetchAssets(
            withLocalIdentifiers: [assetIdentifier], options: nil
        ).firstObject,
              let referenceDate = referenceAsset.creationDate else {
            return []
        }

        // 2. Generate fingerprint for the reference photo
        guard let referenceFingerprint = await generateFingerprint(for: assetIdentifier) else {
            return []
        }

        // 3. Fetch nearby photos within the time window
        let neighborIDs = fetchNearbyIdentifiers(
            around: referenceDate,
            timeWindow: timeWindow,
            excluding: excluding.union([assetIdentifier])
        )

        guard !neighborIDs.isEmpty else { return [] }

        // 4. Compare each neighbor to the reference
        var matches: [(identifier: String, distance: Float)] = []

        for neighborID in neighborIDs {
            guard let neighborFingerprint = await generateFingerprint(for: neighborID) else {
                continue
            }

            var distance: Float = 0
            do {
                try referenceFingerprint.computeDistance(&distance, to: neighborFingerprint)
            } catch {
                continue
            }

            if distance < distanceThreshold {
                matches.append((identifier: neighborID, distance: distance))
            }
        }

        // 5. Sort by similarity (closest first)
        matches.sort { $0.distance < $1.distance }
        return matches.map(\.identifier)
    }

    // MARK: - Private

    /// Generates a Vision feature print for a photo asset.
    private func generateFingerprint(for assetIdentifier: String) async -> VNFeaturePrintObservation? {
        // Load a small thumbnail — fingerprinting doesn't need full resolution
        let targetSize = CGSize(width: 300, height: 300)
        guard let image = await photoService.loadImage(for: assetIdentifier, targetSize: targetSize),
              let cgImage = image.cgImage else {
            return nil
        }

        let request = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])
            return request.results?.first as? VNFeaturePrintObservation
        } catch {
            print("picsort: Failed to generate fingerprint: \(error)")
            return nil
        }
    }

    /// Fetches photo identifiers within ±timeWindow of a given date.
    private func fetchNearbyIdentifiers(
        around date: Date,
        timeWindow: TimeInterval,
        excluding: Set<String>
    ) -> [String] {
        let startDate = date.addingTimeInterval(-timeWindow)
        let endDate = date.addingTimeInterval(timeWindow)

        let options = PHFetchOptions()
        options.predicate = NSPredicate(
            format: "creationDate >= %@ AND creationDate <= %@ AND mediaType == %d",
            startDate as NSDate,
            endDate as NSDate,
            PHAssetMediaType.image.rawValue
        )
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]

        let result = PHAsset.fetchAssets(with: options)

        var identifiers: [String] = []
        result.enumerateObjects { asset, _, _ in
            if !excluding.contains(asset.localIdentifier) {
                identifiers.append(asset.localIdentifier)
            }
        }

        return identifiers
    }
}
