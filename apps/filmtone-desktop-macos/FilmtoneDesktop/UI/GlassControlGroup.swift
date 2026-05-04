import SwiftUI

struct GlassControlGroup: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "play.fill")
            Text("Phase 0")
                .font(.callout.weight(.medium))
            Image(systemName: "circle.dashed")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .glassEffect(.clear, in: Capsule())
    }
}

#Preview {
    GlassControlGroup()
        .padding(40)
        .background(Color.gray.opacity(0.4))
}
