import CoreMedia
import Foundation

/// CMFormatDescription extension dictionary を CFString 定数と String literal key の
/// 両方で lookup し、SDK / OS による定数欠損や命名差を吸収する helper.
/// Apple の CFString 定数は ABI 互換のために `String(describing:)` で CF の identifier に展開できる
/// はずだが、一部 (MasteringDisplayColorVolume / ContentLightLevelInfo) は SDK バージョンで
/// 定数そのものが欠ける可能性があるため、必ず String key フォールバックを持たせる.
enum FormatExtensionReader {
    /// First tries the CFString key (if provided), then the String literal key.
    static func string(
        in extensions: [CFString: Any],
        cfKey: CFString? = nil,
        stringKey: String
    ) -> String? {
        if let cfKey, let value = extensions[cfKey] {
            if let normalized = coerceToString(value) {
                return normalized
            }
        }
        let anyKey = stringKey as CFString
        if let value = extensions[anyKey] {
            if let normalized = coerceToString(value) {
                return normalized
            }
        }
        // Some extension dictionaries bridge as [String: Any] with plain string keys.
        // `extensions[anyKey]` above covers most cases via CFString bridging, but we also
        // defensively walk the dictionary once for the String key to catch NSDictionary
        // representations that don't bridge as expected.
        for (key, value) in extensions {
            if (key as String) == stringKey {
                if let normalized = coerceToString(value) {
                    return normalized
                }
            }
        }
        return nil
    }

    /// Reports whether the extension dictionary contains an entry for the key
    /// (payload is not inspected).
    static func hasKey(
        in extensions: [CFString: Any],
        cfKey: CFString? = nil,
        stringKey: String
    ) -> Bool {
        if let cfKey, extensions[cfKey] != nil {
            return true
        }
        if extensions[stringKey as CFString] != nil {
            return true
        }
        for (key, _) in extensions {
            if (key as String) == stringKey {
                return true
            }
        }
        return false
    }

    // MARK: - Internal

    private static func coerceToString(_ value: Any) -> String? {
        if let direct = value as? String {
            return trimmed(direct)
        }
        if CFGetTypeID(value as CFTypeRef) == CFStringGetTypeID() {
            return trimmed(value as! CFString as String)
        }
        // Some extensions carry NSString via Obj-C bridge; fall back to description.
        let described = String(describing: value)
        return trimmed(described)
    }

    private static func trimmed(_ raw: String) -> String? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
