import SwiftUI

struct AlbumPickerView: View {
    let albums: [PhoneAlbum]
    let onSelect: (PhoneAlbum) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var sortOption: AlbumSortOption = .name
    @State private var sortAscending = true

    var body: some View {
        List(filteredAlbums) { album in
            Button {
                onSelect(album)
                dismiss()
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(album.name)
                            .foregroundStyle(.primary)

                        HStack(spacing: 12) {
                            Label("\(album.photoCount)", systemImage: "photo")

                            if let startDate = album.startDate {
                                Label(
                                    startDate.formatted(.dateTime.month(.abbreviated).year()),
                                    systemImage: "calendar"
                                )
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search albums")
        .navigationTitle("Albums")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                sortMenu
            }
        }
    }

    // MARK: - Sort Menu

    private var sortMenu: some View {
        Menu {
            ForEach(AlbumSortOption.allCases, id: \.self) { option in
                Button {
                    if sortOption == option {
                        sortAscending.toggle()
                    } else {
                        sortOption = option
                        sortAscending = true
                    }
                } label: {
                    HStack {
                        Text(option.rawValue)
                        if sortOption == option {
                            Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
        }
    }

    // MARK: - Filtering & Sorting

    private var filteredAlbums: [PhoneAlbum] {
        var result = albums

        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
        }

        result.sort { a, b in
            let comparison: Bool
            switch sortOption {
            case .name:
                comparison = a.name.localizedCompare(b.name) == .orderedAscending
            case .photoCount:
                comparison = a.photoCount < b.photoCount
            case .dateCreated:
                comparison = (a.startDate ?? .distantPast) < (b.startDate ?? .distantPast)
            }
            return sortAscending ? comparison : !comparison
        }

        return result
    }
}
