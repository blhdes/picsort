import SwiftUI

struct AlbumPickerView: View {
    let albums: [PhoneAlbum]
    let unsortedCount: Int
    let onSelect: (PhoneAlbum) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var sortOption: AlbumSortOption = .name
    @State private var sortAscending = true

    var body: some View {
        List {
            // "Unsorted Photos" — pinned at the top
            if searchText.isEmpty, unsortedCount > 0 {
                Section {
                    Button {
                        onSelect(.unsorted(photoCount: unsortedCount))
                        dismiss()
                    } label: {
                        HStack(spacing: 14) {
                            Circle()
                                .fill(.tertiary)
                                .frame(width: 10, height: 10)

                            VStack(alignment: .leading, spacing: 3) {
                                Text("Unsorted Photos")
                                    .fontWeight(.medium)
                                    .foregroundStyle(.primary)

                                Text("\(unsortedCount) photos not in any album")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }

                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            // Regular albums
            Section {
                ForEach(filteredAlbums) { album in
                    Button {
                        onSelect(album)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(album.name)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)

                            HStack(spacing: 4) {
                                Text("\(album.photoCount) photos")

                                if let startDate = album.startDate {
                                    Text("·")
                                    Text(startDate.formatted(.dateTime.month(.abbreviated).year()))
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .listStyle(.plain)
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
