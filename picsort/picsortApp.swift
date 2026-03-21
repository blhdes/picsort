import SwiftUI
import SwiftData

@main
struct picsortApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Gallery.self, SortedPhoto.self, DismissedPhoto.self])
    }
}
