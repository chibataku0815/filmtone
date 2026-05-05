import CoreMedia
import Foundation

// Phase 2 C1: verbatim lift from
// `apps/capacitor-film-lab-ios/ios/App/App/FormatExtensionReader.swift`.
// Reads CMFormatDescription extension dictionary by both CFString constant
// and String literal key — necessary because some extensions
// (MasteringDisplayColorVolume, ContentLightLevelInfo) lack stable CFString
// constants across SDK versions.
enum FormatExtensionReader {
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
        for (key, value) in extensions {
            if (key as String) == stringKey {
                if let normalized = coerceToString(value) {
                    return normalized
                }
            }
        }
        return nil
    }

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

    private static func coerceToString(_ value: Any) -> String? {
        if let direct = value as? String {
            return trimmed(direct)
        }
        if CFGetTypeID(value as CFTypeRef) == CFStringGetTypeID() {
            return trimmed(value as! CFString as String)
        }
        let described = String(describing: value)
        return trimmed(described)
    }

    private static func trimmed(_ raw: String) -> String? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
