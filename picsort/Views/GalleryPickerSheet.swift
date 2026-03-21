import SwiftUI
import SwiftData

struct GalleryPickerSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Gallery.displayOrder) private var galleries: [Gallery]

    let onSelect: (Gallery) -> Void

    @State private var newGalleryName = ""
    @State private var isCreating = false
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        NavigationStack {
            List {
                // Existing galleries
                ForEach(galleries) { gallery in
                    Button {
                        onSelect(gallery)
                        dismiss()
                    } label: {
                        Label(gallery.name, systemImage: gallery.iconName)
                            .foregroundStyle(Color(hex: gallery.colorHex) ?? .primary)
                    }
                }

                // Inline creation
                if isCreating {
                    HStack {
                        TextField("Gallery name", text: $newGalleryName)
                            .focused($isFieldFocused)
                            .onSubmit { createGallery() }

                        Button("Add") { createGallery() }
                            .disabled(newGalleryName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } else {
                    Button {
                        isCreating = true
                        isFieldFocused = true
                    } label: {
                        Label("New Gallery", systemImage: "plus.circle")
                    }
                }
            }
            .navigationTitle("Sort into...")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func createGallery() {
        let name = newGalleryName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        let gallery = Gallery(name: name, displayOrder: galleries.count)
        modelContext.insert(gallery)
        try? modelContext.save()

        newGalleryName = ""
        isCreating = false

        onSelect(gallery)
        dismiss()
    }
}

// MARK: - Color from Hex

extension Color {
    init?(hex: String) {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hexString.hasPrefix("#") {
            hexString.removeFirst()
        }

        guard hexString.count == 6,
              let hexNumber = UInt64(hexString, radix: 16) else {
            return nil
        }

        let r = Double((hexNumber & 0xFF0000) >> 16) / 255
        let g = Double((hexNumber & 0x00FF00) >> 8) / 255
        let b = Double(hexNumber & 0x0000FF) / 255

        self.init(red: r, green: g, blue: b)
    }
}
