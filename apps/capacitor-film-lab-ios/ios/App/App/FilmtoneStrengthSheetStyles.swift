import SwiftUI

extension View {
    func sectionDivider() -> some View {
        padding(.top, 18)
            .overlay(
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1),
                alignment: .top
            )
            .padding(.top, 8)
    }
}
