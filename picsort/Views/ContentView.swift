import SwiftUI

struct ContentView: View {
    @State private var startDate: Date?
    @State private var selectedAlbum: PhoneAlbum?
    @State private var sortMode: SortMode = .copy
    @State private var focusDuration: TimeInterval?
    @State private var isOnThisDay = false
    @State private var showGalleries = false
    @State private var showDuplicateSweep = false

    var body: some View {
        NavigationStack {
            if showDuplicateSweep {
                DuplicateSweepView(onClose: {
                    showDuplicateSweep = false
                })
            } else if let startDate {
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
                    showGalleries: $showGalleries,
                    showDuplicateSweep: $showDuplicateSweep
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
