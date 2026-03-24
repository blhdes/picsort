import SwiftUI

struct ContentView: View {
    @State private var startDate: Date?
    @State private var selectedAlbum: PhoneAlbum?
    @State private var sortMode: SortMode = .copy
    @State private var focusDuration: TimeInterval?
    @State private var isOnThisDay = false
    @State private var showGalleries = false

    var body: some View {
        NavigationStack {
            if let startDate {
                SwipeView(
                    startDate: startDate,
                    albumIdentifier: selectedAlbum?.collectionIdentifier,
                    sortMode: sortMode,
                    focusDuration: focusDuration,
                    isOnThisDay: isOnThisDay,
                    onBack: {
                        self.startDate = nil
                        self.focusDuration = nil
                        self.isOnThisDay = false
                    },
                    onShowGalleries: {
                        showGalleries = true
                    },
                    onSessionEnd: {
                        self.startDate = nil
                        self.focusDuration = nil
                        self.isOnThisDay = false
                    }
                )
                .navigationBarHidden(true)
            } else {
                DatePickerView(
                    selectedDate: $startDate,
                    selectedAlbum: $selectedAlbum,
                    sortMode: $sortMode,
                    focusDuration: $focusDuration,
                    isOnThisDay: $isOnThisDay,
                    showGalleries: $showGalleries
                )
            }
        }
        .sheet(isPresented: $showGalleries) {
            NavigationStack {
                GalleriesView()
            }
        }
    }
}
