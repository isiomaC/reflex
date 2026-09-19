import SwiftUI

struct PhasePlaceholderView: View {
    let title: String
    let systemImage: String
    let phase: String
    let description: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            VStack(spacing: 8) {
                Text(phase)
                    .font(.headline)
                Text(description)
            }
        }
    }
}
