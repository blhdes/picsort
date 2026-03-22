import SwiftUI
import Photos

struct DatePickerView: View {
    @Binding var selectedDate: Date?
    @Binding var selectedAlbum: PhoneAlbum?

    @State private var pickerDate = Date()
    @State private var photoService = PhotoLibraryService()
    @State private var earliestDate: Date?
    @State private var latestDate: Date?
    @State private var albums: [PhoneAlbum] = []
    @State private var showAlbumPicker = false

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
            } else {
                ProgressView("Loading your library...")
            }

            Spacer()
        }
        .padding()
        .sheet(isPresented: $showAlbumPicker) {
            NavigationStack {
                AlbumPickerView(albums: albums) { album in
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
        }
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
