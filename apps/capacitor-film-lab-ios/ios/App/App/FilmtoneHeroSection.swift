import SwiftUI

struct FilmtoneHeroSection: View {
    @ObservedObject var store: FilmtoneEditorStore
    @Binding var fullscreenLutEditorPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if store.source != nil {
                VStack(alignment: .leading, spacing: 8) {
                    Text(store.activePresetLabel)
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    if store.hasAnyAdjustments {
                        Text(store.adjustmentSummaryText)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.66))
                            .lineLimit(2)
                    }
                }
            }

            FilmtonePreviewView(
                source: store.source,
                displayURI: store.selectedPreviewURI,
                videoPreview: store.videoPreviewState,
                emptyMessage: previewEmptyMessage,
                emptyEyebrow: store.strings.previewEmptyEyebrow,
                emptyHint: store.strings.previewEmptyHint,
                loadingMessage: store.strings.previewRendering,
                originalLabel: store.strings.compareLabel,
                gradedLabel: store.strings.previewGradedLabel,
                expandLabel: store.strings.previewExpandLabel,
                isRendering: store.preview.isRendering,
                metaLabel: store.previewMetaLabel,
                isStillComparing: store.isCompareHeld,
                onStillCompareHeld: store.setCompareHeld,
                onOpenFullscreen: {
                    fullscreenLutEditorPresented = true
                }
            ) { mode in
                Task { await store.setVideoCompareMode(mode) }
            }
        }
    }

    private var previewEmptyMessage: String {
        if store.source == nil {
            return store.strings.sourceEmpty
        }
        if let error = store.previewError {
            return error
        }
        return store.strings.previewRendering
    }
}
