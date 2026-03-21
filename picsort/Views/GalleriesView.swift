import SwiftUI
import SwiftData

struct GalleriesView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: GalleryViewModel?

    @State private var newGalleryName = ""
    @State private var showCreateAlert = false

    var body: some View {
        Group {
            if let viewModel {
                if viewModel.galleries.isEmpty {
                    ContentUnavailableView(
                        "No Galleries",
                        systemImage: "rectangle.stack",
                        description: Text("Galleries you create will appear here.")
                    )
                } else {
                    List {
                        ForEach(viewModel.galleries) { gallery in
                            NavigationLink(value: gallery) {
                                galleryRow(gallery)
                            }
                        }
                        .onMove { source, destination in
                            viewModel.moveGallery(from: source, to: destination)
                        }
                        .onDelete { offsets in
                            for index in offsets {
                                viewModel.deleteGallery(viewModel.galleries[index])
                            }
                        }
                    }
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Galleries")
        .navigationDestination(for: Gallery.self) { gallery in
            GalleryDetailView(gallery: gallery)
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if viewModel?.galleries.isEmpty == false {
                    EditButton()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showCreateAlert = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .alert("New Gallery", isPresented: $showCreateAlert) {
            TextField("Name", text: $newGalleryName)
            Button("Create") {
                let name = newGalleryName.trimmingCharacters(in: .whitespaces)
                if !name.isEmpty {
                    viewModel?.createGallery(name: name)
                }
                newGalleryName = ""
            }
            Button("Cancel", role: .cancel) {
                newGalleryName = ""
            }
        }
        .task {
            if viewModel == nil {
                viewModel = GalleryViewModel(modelContext: modelContext)
            }
        }
    }

    // MARK: - Row

    @ViewBuilder
    private func galleryRow(_ gallery: Gallery) -> some View {
        HStack {
            Image(systemName: gallery.iconName)
                .foregroundStyle(Color(hex: gallery.colorHex) ?? .blue)
                .frame(width: 28)

            Text(gallery.name)

            Spacer()

            Text("\(gallery.sortedPhotos.count)")
                .foregroundStyle(.secondary)
                .font(.subheadline)
        }
    }
}
