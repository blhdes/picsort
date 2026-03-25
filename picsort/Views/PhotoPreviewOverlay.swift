import SwiftUI

struct PhotoPreviewItem: Identifiable {
    let id: String
}

struct PhotoPreviewOverlay: View {
    let identifier: String
    let photoService: PhotoLibraryService
    let onDismiss: () -> Void

    @State private var loader: PhotoImageLoader

    init(identifier: String, photoService: PhotoLibraryService, onDismiss: @escaping () -> Void) {
        self.identifier = identifier
        self.photoService = photoService
        self.onDismiss = onDismiss
        let screen = UIScreen.main.bounds.size
        self._loader = State(initialValue: PhotoImageLoader(
            service: photoService,
            assetIdentifier: identifier,
            targetSize: CGSize(width: screen.width * 2, height: screen.height * 2)
        ))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let image = loader.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .overlay(alignment: .topTrailing) {
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.body)
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .padding(.trailing, 16)
            .padding(.top, 8)
        }
        .task { await loader.load() }
    }
}
