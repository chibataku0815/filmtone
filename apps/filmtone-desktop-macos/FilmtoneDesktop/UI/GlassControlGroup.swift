import AppKit
import SwiftUI

// M5-H.1: the prior `Phase 0` placeholder banner was retired from the
// right rail. This view stays as a small brand pill (AppIcon mark + the
// "Filmtone" wordmark inside an Apple Liquid Glass capsule) for any
// future chrome surface that needs a brand affordance. It is currently
// unwired in `RootWindowView`; importing it does not paint anything.
struct GlassControlGroup: View {
    var body: some View {
        HStack(spacing: 8) {
            if let icon = NSApp.applicationIconImage {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 16, height: 16)
            }
            Text("Filmtone")
                .font(.callout.weight(.medium))
                .tracking(0.5)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .glassEffect(.clear, in: Capsule())
    }
}

#Preview {
    GlassControlGroup()
        .padding(40)
        .background(Color.gray.opacity(0.4))
}
