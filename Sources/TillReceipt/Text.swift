import Foundation

enum Text {
    /// `İ` lowercases to `i` followed by a combining dot above, which then survives into the name
    /// and prints as "Sti̇ker". Dropping the mark is the whole fix.
    static func titleCase(_ value: String) -> String {
        value.lowercased()
            .replacingOccurrences(of: "\u{0307}", with: "")
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    /// Splits a name into plain ASCII words.
    ///
    /// The locale folds its own alphabet first, because Unicode decomposition alone leaves `ı`
    /// and `İ` standing and they then split a word in two.
    static func tokens(_ value: String, fold: (String) -> String) -> [String] {
        let stripped = fold(value).decomposedStringWithCompatibilityMapping.unicodeScalars
            .filter { !(0x0300...0x036F).contains($0.value) }
        return String(String.UnicodeScalarView(stripped))
            .split(whereSeparator: { !$0.isASCII || !($0.isLetter || $0.isNumber) })
            .map { singular(String($0)) }
    }

    private static func singular(_ token: String) -> String {
        if token.hasSuffix("ies"), token.count > 4 { return token.dropLast(3) + "y" }
        if token.hasSuffix("oes"), token.count > 4 { return String(token.dropLast(2)) }
        if token.count > 4, ["ses", "xes", "zes", "ches", "shes"].contains(where: token.hasSuffix) {
            return String(token.dropLast(2))
        }
        if token.hasSuffix("s"), token.count > 3, !token.hasSuffix("ss") { return String(token.dropLast()) }
        return token
    }

    /// Reads a printed number whichever way the till writes its decimal mark.
    static func number(_ raw: String) -> Double? {
        Double(raw.replacingOccurrences(of: ",", with: "."))
    }

    static func rounded(_ value: Double) -> Double {
        (value * 1000).rounded() / 1000
    }
}
