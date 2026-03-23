import Foundation
import Photos

@Observable
final class InsightsViewModel {
    private(set) var totalLibraryCount: Int = 0
    private(set) var longestStreak: Int = 0
    private(set) var currentStreak: Int = 0

    private let photoService: PhotoLibraryService

    init(photoService: PhotoLibraryService = .shared) {
        self.photoService = photoService
    }

    /// Fetches the total number of photos in the user's library via PhotoKit.
    func loadLibraryCount() {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(
            format: "mediaType == %d",
            PHAssetMediaType.image.rawValue
        )
        totalLibraryCount = PHAsset.fetchAssets(with: options).count
    }

    /// Calculates longest and current sorting streaks from SortedPhoto dates.
    /// Groups by calendar day and finds consecutive-day runs.
    func calculateStreaks(from sortedDates: [Date]) {
        let calendar = Calendar.current
        let uniqueDays = Set(sortedDates.map { calendar.startOfDay(for: $0) })
        let sorted = uniqueDays.sorted()

        guard !sorted.isEmpty else {
            longestStreak = 0
            currentStreak = 0
            return
        }

        // Longest streak
        var maxRun = 1
        var run = 1
        for i in 1..<sorted.count {
            let gap = calendar.dateComponents([.day], from: sorted[i - 1], to: sorted[i]).day ?? 0
            if gap == 1 {
                run += 1
                maxRun = max(maxRun, run)
            } else {
                run = 1
            }
        }
        longestStreak = maxRun

        // Current streak — count backward from today
        let today = calendar.startOfDay(for: .now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        guard let lastDay = sorted.last, lastDay == today || lastDay == yesterday else {
            currentStreak = 0
            return
        }

        var streak = 1
        for i in stride(from: sorted.count - 2, through: 0, by: -1) {
            let gap = calendar.dateComponents([.day], from: sorted[i], to: sorted[i + 1]).day ?? 0
            if gap == 1 {
                streak += 1
            } else {
                break
            }
        }
        currentStreak = streak
    }
}
