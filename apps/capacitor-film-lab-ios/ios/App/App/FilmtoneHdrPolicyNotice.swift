import SwiftUI

/// SwiftUI callout that surfaces the active HDR preparation policy just below
/// the top source banner.
///
/// Visibility predicate mirrors Desktop `HdrPolicyNotice.tsx`:
///   * `strategy != .none`, OR
///   * `reason == "wide-gamut-transfer-unknown"` (treated as visible even when
///     strategy happens to be `.deferVisibleWarning`; also covers `.none` edge
///     cases where the Deriver returns wide-gamut info without a strategy).
///
/// The notice is intentionally:
///   * non-dismissable — state is owned by the active source probe.
///   * free of any "install ffmpeg" CTA — that concern belongs to Desktop.
///   * written with hedged wording — actual Core Image tone-map is gated by
///     pixel-buffer attachments, not by formatDescription policy alone, so we
///     do NOT promise that a tone-map will always happen.
struct FilmtoneHdrPolicyNotice: View {
    let policy: HdrPreparationPolicyDTO?
    let strings: FilmtoneStrings

    init(
        policy: HdrPreparationPolicyDTO?,
        strings: FilmtoneStrings = FilmtoneStringsCatalog.current
    ) {
        self.policy = policy
        self.strings = strings
    }

    var body: some View {
        if let policy, Self.shouldSurface(policy) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.filmtoneAmber)

                    Text(strings.hdrNoticeTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.filmtoneAmber.opacity(0.95))
                        .accessibilityIdentifier("filmtone.hdr.notice.title")
                }

                if let body = Self.bodyText(for: policy, strings: strings) {
                    Text(body)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.82))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("filmtone.hdr.notice.body")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: filmtoneSurfaceCornerRadius, style: .continuous)
                    .fill(Color.filmtoneAmber.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: filmtoneSurfaceCornerRadius, style: .continuous)
                    .stroke(Color.filmtoneAmber.opacity(0.22), lineWidth: 1)
            )
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 2)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("filmtone.hdr.notice")
        }
    }

    /// Pure predicate for unit testing / snapshot fixtures.
    static func shouldSurface(_ policy: HdrPreparationPolicyDTO?) -> Bool {
        guard let policy else { return false }
        if policy.strategy != .none { return true }
        if policy.reason == "wide-gamut-transfer-unknown" { return true }
        return false
    }

    /// Localized body copy for the notice.
    ///
    /// Returns `nil` for non-none strategies with an unfamiliar reason, in
    /// which case only the title is shown. We intentionally avoid confident
    /// tone-map promises — the wording is hedged ("may be converted",
    /// "could be compressed").
    static func bodyText(
        for policy: HdrPreparationPolicyDTO,
        strings: FilmtoneStrings
    ) -> String? {
        switch policy.reason {
        case "source-is-hdr-pq":
            return strings.hdrNoticeBodyPq
        case "source-is-hdr-hlg":
            return strings.hdrNoticeBodyHlg
        case "wide-gamut-transfer-unknown":
            return strings.hdrNoticeBodyWideGamutUnknown
        default:
            return nil
        }
    }
}
