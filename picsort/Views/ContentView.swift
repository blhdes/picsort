import SwiftUI

struct ContentView: View {
    @State private var startDate: Date?
    @State private var selectedAlbum: PhoneAlbum?
    @State private var sortMode: SortMode = .copy
    @State private var focusDuration: TimeInterval?
    @State private var showGalleries = false
    @State private var showInsights = false

    var body: some View {
        NavigationStack {
            if let startDate {
                SwipeView(
                    startDate: startDate,
                    albumIdentifier: selectedAlbum?.collectionIdentifier,
                    sortMode: sortMode,
                    focusDuration: focusDuration,
                    onSessionEnd: {
                        self.startDate = nil
                        self.focusDuration = nil
                    }
                )
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            self.startDate = nil
                            self.focusDuration = nil
                        } label: {
                            Image(systemName: "calendar")
                        }
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showInsights = true
                        } label: {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                        }
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showGalleries = true
                        } label: {
                            Image(systemName: "rectangle.stack")
                        }
                    }
                }
                .sheet(isPresented: $showInsights) {
                    InsightsView()
                }
                .sheet(isPresented: $showGalleries) {
                    NavigationStack {
                        GalleriesView()
                    }
                }
            } else {
                DatePickerView(
                    selectedDate: $startDate,
                    selectedAlbum: $selectedAlbum,
                    sortMode: $sortMode,
                    focusDuration: $focusDuration
                )
            }
        }
    }
}
