import SwiftUI

struct ContentView: View {
    @State private var startDate: Date?
    @State private var selectedAlbum: PhoneAlbum?
    @State private var sortMode: SortMode = .copy
    @State private var showGalleries = false

    var body: some View {
        NavigationStack {
            if let startDate {
                SwipeView(
                    startDate: startDate,
                    albumIdentifier: selectedAlbum?.collectionIdentifier,
                    sortMode: sortMode
                )
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            self.startDate = nil
                        } label: {
                            Image(systemName: "calendar")
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
                .sheet(isPresented: $showGalleries) {
                    NavigationStack {
                        GalleriesView()
                    }
                }
            } else {
                DatePickerView(
                    selectedDate: $startDate,
                    selectedAlbum: $selectedAlbum,
                    sortMode: $sortMode
                )
            }
        }
    }
}
