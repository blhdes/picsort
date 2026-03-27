import SwiftUI
import SwiftData

@main
struct CullaApp: App {
    /// Random neon accent picked fresh each launch.
    private let sessionAccent = Color(hex: Color.neonHexes.randomElement()!)

    var body: some Scene {
        WindowGroup {
            SplashGate()
                .tint(sessionAccent)
        }
        .modelContainer(for: [Gallery.self, SortedPhoto.self, DismissedPhoto.self])
    }
}

/// Shows the app icon until the content is ready, then fades in.
private struct SplashGate: View {
    @State private var isReady = false

    var body: some View {
        ZStack {
            ContentView(isReady: $isReady)
                .opacity(isReady ? 1 : 0)

            if !isReady {
                splashView
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.4), value: isReady)
    }

    private var splashView: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image("LaunchIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 18))

                Text("culla")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(.primary)
            }
        }
    }
}
