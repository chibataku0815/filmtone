import Foundation

/// CoreMedia が返す色 metadata identifier (例: "SMPTE_ST_2084_PQ") を
/// Desktop / ffprobe 側の語彙 (例: "smpte2084") に正規化する.
///
/// Desktop `classifySourceColorForExport` は ffprobe 語彙を前提にしているため、
/// 定数を直接渡すと HDR 判定が外れる (`SMPTE_ST_2084_PQ` は classifier の
/// PQ branch (`smpte2084`) に一致しない).
///
/// 未知 token は lowercase のまま返す. classifier はそれを明示的な enum 値に
/// 一致させないので `unknown` 分岐に落ちる = safe fallback.
enum SourceColorMetadataNormalizer {
    static func normalizeTransfer(_ raw: String?) -> String? {
        guard let token = normalizedToken(raw) else { return nil }
        switch token {
        case "itu_r_709_2", "itur_709_2", "bt709", "itu-r_bt709":
            return "bt709"
        case "smpte_240m_1995", "smpte240m":
            return "smpte240m"
        case "srgb", "iec_srgb", "iec_61966_2_1":
            return "iec61966-2-1"
        case "itu_r_2020", "itur_2020", "bt2020", "itu-r_bt2020",
             "itu_r_2020_10", "itu_r_2020_12":
            // ffprobe distinguishes bt2020-10 / bt2020-12, but the classifier does not.
            // Emit a value that passes through the "not PQ/HLG" branch without matching bt709.
            return "bt2020-10"
        case "smpte_st_428_1", "smpte428":
            return "smpte428"
        case "smpte_st_2084_pq", "smpte2084", "pq":
            return "smpte2084"
        case "itu_r_2100_hlg", "arib_std_b67", "arib-std-b67", "hlg":
            return "arib-std-b67"
        case "linear":
            return "linear"
        case "usegamma", "gamma22", "gamma28":
            // CoreMedia "UseGamma" is opaque without the gamma value dictionary.
            // Treat as unknown so the classifier does not confuse it with SDR bt709.
            return nil
        default:
            return token
        }
    }

    static func normalizePrimaries(_ raw: String?) -> String? {
        guard let token = normalizedToken(raw) else { return nil }
        switch token {
        case "itu_r_709_2", "itur_709_2", "bt709", "itu-r_bt709":
            return "bt709"
        case "ebu_3213", "bt470bg":
            return "bt470bg"
        case "smpte_c", "smpte170m":
            return "smpte170m"
        case "dci_p3", "smpte431":
            return "smpte431"
        case "p3_d65", "smpte432", "display_p3":
            return "smpte432"
        case "itu_r_2020", "itur_2020", "bt2020":
            return "bt2020"
        case "p22":
            return "p22"
        default:
            return token
        }
    }

    static func normalizeMatrix(_ raw: String?) -> String? {
        guard let token = normalizedToken(raw) else { return nil }
        switch token {
        case "itu_r_709_2", "itur_709_2", "bt709":
            return "bt709"
        case "itu_r_601_4", "smpte170m":
            return "smpte170m"
        case "smpte_240m_1995", "smpte240m":
            return "smpte240m"
        case "itu_r_2020", "bt2020", "bt2020nc":
            return "bt2020nc"
        case "bt2020c":
            return "bt2020c"
        default:
            return token
        }
    }

    static func normalizeLogTransferFunction(_ raw: String?) -> SourceLogTransferFunctionDTO? {
        guard let token = normalizedToken(raw) else { return nil }
        switch token {
        case "apple-log", "apple_log", "applelog",
             "applelogprofile", "com.apple.coremedia.applelog",
             "com.apple.quicktime.applelog":
            return .appleLog
        case "apple-log2", "apple-log-2", "apple_log2", "apple_log_2", "applelog2",
             "com.apple.coremedia.applelog2", "com.apple.quicktime.applelog2":
            return .appleLog2
        default:
            if token.contains("apple") && token.contains("log2") {
                return .appleLog2
            }
            if token.contains("apple") && token.contains("log") {
                return .appleLog
            }
            return nil
        }
    }

    // MARK: - Internal

    /// Return a lower-cased, whitespace-trimmed, CoreMedia-prefixed-tolerant token.
    /// Accepts both the short identifier ("SMPTE_ST_2084_PQ") and the fully-qualified
    /// constant name ("kCMFormatDescriptionTransferFunction_SMPTE_ST_2084_PQ").
    private static func normalizedToken(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        var token = trimmed.lowercased()
        // Strip CoreMedia constant prefixes.
        let prefixes = [
            "kcmformatdescriptiontransferfunction_",
            "kcmformatdescriptionlogtransferfunction_",
            "kcvimagebufferlogtransferfunction_",
            "kcmformatdescriptioncolorprimaries_",
            "kcmformatdescriptionycbcrmatrix_",
        ]
        for prefix in prefixes where token.hasPrefix(prefix) {
            token = String(token.dropFirst(prefix.count))
            break
        }
        return token
    }
}
