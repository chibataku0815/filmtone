import SwiftUI

// M5-C.4: shared label+value tile used inside the Export Inspector
// metric grid. Two-line layout (caption-weight label / body value)
// over the dark-tinted Liquid Glass posture established by
// QuickAdjustControls / LookLibraryControls. Locked at the rail's 220pt
// width via .frame(maxWidth: .infinity) so a 2-column LazyVGrid lays out
// cleanly without overflow.

struct MetricRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.5))
                .lineLimit(1)
            Text(value)
                .font(.callout.monospacedDigit())
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
