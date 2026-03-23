import SwiftUI
import Photos

struct DatePickerView: View {
    @Binding var selectedDate: Date?
    @Binding var selectedAlbum: PhoneAlbum?
    @Binding var sortMode: SortMode
    @Binding var focusDuration: TimeInterval?

    @State private var pickerDate = Date()
    private let photoService = PhotoLibraryService.shared
    @State private var earliestDate: Date?
    @State private var latestDate: Date?
    @State private var albums: [PhoneAlbum] = []
    @State private var unsortedCount: Int = 0
    @State private var showAlbumPicker = false
    @State private var showInsights = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("Pick a starting date")
                .font(.title2)
                .fontWeight(.semibold)

            if let earliestDate, let latestDate {
                DatePicker(
                    "From",
                    selection: $pickerDate,
                    in: earliestDate...latestDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding(.horizontal)

                // Album filter
                albumFilterButton

                // Move vs. copy — only when sorting from a real album
                if let album = selectedAlbum, !album.isUnsorted {
                    sortModePicker
                }

                VStack(spacing: 12) {
                    Button("Start Sorting") {
                        selectedDate = pickerDate
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button("From the very first photo") {
                        selectedDate = earliestDate
                    }
                    .font(.subheadline)
                }

                // Focus Session
                VStack(spacing: 10) {
                    Text("Focus Session")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        ForEach([2, 5, 10], id: \.self) { minutes in
                            Button("\(minutes) min") {
                                focusDuration = TimeInterval(minutes * 60)
                                selectedDate = pickerDate
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                        }
                    }
                }
            } else {
                ProgressView("Loading your library...")
            }

            Spacer()
        }
        .padding()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showInsights = true
                } label: {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                }
            }
        }
        .sheet(isPresented: $showInsights) {
            InsightsView()
        }
        .sheet(isPresented: $showAlbumPicker) {
            NavigationStack {
                AlbumPickerView(albums: albums, unsortedCount: unsortedCount) { album in
                    selectedAlbum = album
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") { showAlbumPicker = false }
                    }
                }
            }
        }
        .task {
            let status = await photoService.requestAuthorization()
            guard status == .authorized || status == .limited else { return }

            if let range = photoService.photoDateRange() {
                earliestDate = range.earliest
                latestDate = range.latest
                pickerDate = range.latest
            }

            albums = photoService.fetchAlbums()
            unsortedCount = photoService.unsortedPhotoCount()
        }
    }

    // MARK: - Sort Mode Picker

    private var sortModePicker: some View {
        VStack(spacing: 6) {
            Picker("Sort mode", selection: $sortMode) {
                Text("Keep in album").tag(SortMode.copy)
                Text("Move out").tag(SortMode.move)
            }
            .pickerStyle(.segmented)

            Text(sortMode == .copy
                 ? "Sorted photos stay in the source album too."
                 : "Sorted photos are removed from the source album.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
    }

    // MARK: - Album Filter Button

    private var albumFilterButton: some View {
        Button {
            showAlbumPicker = true
        } label: {
            HStack {
                Image(systemName: "rectangle.stack")
                if let selectedAlbum {
                    Text(selectedAlbum.name)
                    Spacer()
                    Button {
                        self.selectedAlbum = nil
                        self.sortMode = .copy
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("All Photos")
                    Spacer()
                    Text("Filter by album")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }
}
