import SwiftUI

struct DeleteFeedbackOverlay: View {
    let sessionCount: Int
    let totalCount: Int

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 36))
                .foregroundStyle(.primary)

            Text("\(sessionCount) photos deleted")
                .font(.title3)
                .fontWeight(.semibold)

            Text("\(totalCount) cleaned up in total")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(32)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
}

/// Modifier that overlays the feedback with auto-dismiss after 2.5 seconds.
struct DeleteFeedbackModifier: ViewModifier {
    @Binding var feedback: DeleteFeedback?

    func body(content: Content) -> some View {
        content
            .overlay {
                if let feedback {
                    DeleteFeedbackOverlay(
                        sessionCount: feedback.sessionCount,
                        totalCount: feedback.totalCount
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: feedback != nil)
    }
}

struct DeleteFeedback: Equatable {
    let sessionCount: Int
    let totalCount: Int
}

extension View {
    func deleteFeedback(_ feedback: Binding<DeleteFeedback?>) -> some View {
        modifier(DeleteFeedbackModifier(feedback: feedback))
    }
}
