import SwiftUI
import Photos

struct DatePickerView: View {
    @Binding var selectedDate: Date?
    @Binding var selectedAlbum: PhoneAlbum?
    @Binding var sortMode: SortMode
    @Binding var focusDuration: TimeInterval?
    @Binding var isOnThisDay: Bool
    @Binding var showGalleries: Bool
    @Binding var showDuplicateSweep: Bool

    @State private var pickerDate = Date()
    private let photoService = PhotoLibraryService.shared
    @State private var earliestDate: Date?
    @State private var latestDate: Date?
    @State private var albums: [PhoneAlbum] = []
    @State private var unsortedCount: Int = 0
    @State private var showAlbumPicker = false
    @State private var showFullCalendar = false

    var body: some View {
        VStack(spacing: 28) {
            HStack(spacing: 8) {
                Text("Pick a starting date")
                    .font(.title2)
                    .fontWeight(.semibold)
                Button {
                    showFullCalendar = true
                } label: {
                    Image(systemName: "calendar")
                        .font(.title3)
                }
            }

            if let earliestDate, let latestDate {
                // Wheel date picker
                DatePicker(
                    "Date",
                    selection: $pickerDate,
                    in: earliestDate...latestDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.wheel)
                .labelsHidden()

                // Album filter
                albumFilterButton

                // Move vs. copy — only when sorting from a real album
                if let album = selectedAlbum, !album.isUnsorted {
                    sortModePicker
                }

                VStack(spacing: 18) {
                    HStack(spacing: 12) {
                        timerMenu

                        Button {
                            selectedDate = pickerDate
                        } label: {
                            Text(startButtonLabel)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                    .padding(.horizontal)

                    Button("From the very first photo") {
                        selectedDate = earliestDate
                    }
                    .font(.subheadline)

                    Button {
                        isOnThisDay = true
                        selectedDate = .now
                    } label: {
                        Label("On This Day", systemImage: "clock.arrow.circlepath")
                            .font(.subheadline)
                    }

                    Button {
                        showDuplicateSweep = true
                    } label: {
                        Label("Duplicate Sweep", systemImage: "square.on.square")
                            .font(.subheadline)
                    }
                }
            } else {
                Spacer()
                ProgressView("Loading your library...")
                Spacer()
            }
        }
        .padding(.horizontal)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showGalleries = true
                } label: {
                    Image(systemName: "rectangle.stack")
                }
            }
        }
        .sheet(isPresented: $showFullCalendar) {
            calendarSheet
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

    // MARK: - Focus Timer Menu

    private var startButtonLabel: String {
        guard let focusDuration else { return "Start Sorting" }
        let minutes = Int(focusDuration) / 60
        return "Sort for \(minutes) min"
    }

    private var timerMenu: some View {
        Menu {
            ForEach([2, 5, 10], id: \.self) { minutes in
                Button {
                    focusDuration = TimeInterval(minutes * 60)
                } label: {
                    HStack {
                        Text("\(minutes) min")
                        if focusDuration == TimeInterval(minutes * 60) {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }

            if focusDuration != nil {
                Divider()
                Button("No Timer", role: .destructive) {
                    focusDuration = nil
                }
            }
        } label: {
            Image(systemName: focusDuration != nil ? "timer.circle.fill" : "timer")
                .font(.title2)
                .foregroundStyle(focusDuration != nil ? Color.accentColor : .secondary)
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

    // MARK: - Full Calendar Sheet

    private var calendarSheet: some View {
        NavigationStack {
            VStack {
                if let earliestDate, let latestDate {
                    DatePicker(
                        "Date",
                        selection: $pickerDate,
                        in: earliestDate...latestDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .padding()
                }
                Spacer()
            }
            .navigationTitle("Pick a Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showFullCalendar = false }
                        .fontWeight(.semibold)
                }
            }
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
