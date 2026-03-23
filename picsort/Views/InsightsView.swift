import SwiftUI
import SwiftData

struct InsightsView: View {
    @Query private var sortedPhotos: [SortedPhoto]
    @Query private var dismissedPhotos: [DismissedPhoto]
    @Query(sort: \Gallery.displayOrder) private var galleries: [Gallery]

    @AppStorage("totalDeletedPhotos") private var totalDeletedPhotos = 0

    @State private var viewModel = InsightsViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    insightSection("Your Progress") {
                        insightRow("Photos sorted", value: "\(sortedPhotos.count)")
                        insightRow("Photos deleted", value: "\(totalDeletedPhotos)")
                        insightRow("Library remaining", value: "\(remainingCount)")
                    }

                    insightSection("Consistency") {
                        insightRow("Current streak", value: streakText(viewModel.currentStreak))
                        insightRow("Longest streak", value: streakText(viewModel.longestStreak))
                    }

                    insightSection("Galleries") {
                        insightRow("Most active this week", value: mostActiveGalleryText)
                        insightRow("Total galleries", value: "\(galleries.count)")
                    }
                }
                .padding(.horizontal)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .task {
                viewModel.loadLibraryCount()
                viewModel.calculateStreaks(from: sortedPhotos.map(\.sortedAt))
            }
            .onChange(of: sortedPhotos.count) {
                viewModel.calculateStreaks(from: sortedPhotos.map(\.sortedAt))
            }
        }
    }

    // MARK: - Computed Stats

    private var remainingCount: Int {
        max(viewModel.totalLibraryCount - sortedPhotos.count, 0)
    }

    private var mostActiveGalleryText: String {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: .now)!
        let recentPhotos = sortedPhotos.filter { $0.sortedAt > cutoff }

        var counts: [UUID: (name: String, count: Int)] = [:]
        for photo in recentPhotos {
            guard let gallery = photo.gallery else { continue }
            let existing = counts[gallery.id]
            counts[gallery.id] = (gallery.name, (existing?.count ?? 0) + 1)
        }

        guard let top = counts.values.max(by: { $0.count < $1.count }) else {
            return "—"
        }
        return "\(top.name) (\(top.count))"
    }

    // MARK: - Helpers

    private func streakText(_ days: Int) -> String {
        days == 0 ? "—" : "\(days) \(days == 1 ? "day" : "days")"
    }

    // MARK: - Section Layout

    private func insightSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.bottom, 10)

            VStack(spacing: 0) {
                content()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private func insightRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .monospacedDigit()
        }
        .font(.body)
        .padding(.vertical, 6)
    }
}
