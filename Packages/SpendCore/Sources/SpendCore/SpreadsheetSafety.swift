import Foundation

/// Defends against CSV / spreadsheet formula injection (CWE-1236).
/// A merchant named `=HYPERLINK("http://evil", "x")` must never execute
/// when the user opens an export in Excel, Numbers or Google Sheets.
public enum SpreadsheetSafety {
    static let dangerousLeadingCharacters: Set<Character> = ["=", "+", "-", "@", "\t", "\r", "|"]

    public static func neutralize(_ value: String) -> String {
        guard let first = value.first, dangerousLeadingCharacters.contains(first) else { return value }
        return "'" + value
    }

    /// RFC 4180 CSV field encoding plus formula neutralization.
    public static func csvField(_ value: String) -> String {
        let safe = neutralize(value)
        if safe.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) {
            return "\"" + safe.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return safe
    }
}
