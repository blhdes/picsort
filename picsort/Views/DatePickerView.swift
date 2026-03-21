import SwiftUI

struct DatePickerView: View {
    @Binding var selectedDate: Date?
    @State private var pickerDate = Date()

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Text("Pick a starting date")
                .font(.title2)
                .fontWeight(.semibold)

            DatePicker(
                "From",
                selection: $pickerDate,
                in: ...Date.now,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .padding(.horizontal)

            Button("Start Sorting") {
                selectedDate = pickerDate
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer()
        }
        .padding()
    }
}
