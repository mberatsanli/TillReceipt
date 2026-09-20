import Foundation

/// A regular expression written as a literal, so a locale can be described as data.
///
/// Word boundaries stay ASCII on purpose. Every pattern is matched against text the locale has
/// already folded to ASCII, where `\b` means what it looks like; switching on Unicode boundaries
/// would quietly change what a folded keyword matches.
public struct Pattern: ExpressibleByStringLiteral, @unchecked Sendable {
    /// The groups of one match, numbered as in the pattern. Group 0 is the whole match.
    struct Match {
        let range: Range<String.Index>
        private let groups: [String?]

        init(range: Range<String.Index>, groups: [String?]) {
            self.range = range
            self.groups = groups
        }

        subscript(group: Int) -> String? {
            group < groups.count ? groups[group] : nil
        }

        var text: String { groups[0] ?? "" }
    }

    private let regex: NSRegularExpression

    /// The literal must be a valid pattern. An invalid one is a mistake in the source, not input.
    public init(stringLiteral pattern: String) {
        self.init(pattern)
    }

    public init(_ pattern: String, caseInsensitive: Bool = true) {
        let options: NSRegularExpression.Options = caseInsensitive ? [.caseInsensitive] : []
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            preconditionFailure("not a valid pattern: \(pattern)")
        }
        self.regex = regex
    }

    public var source: String { regex.pattern }

    func matches(_ text: String) -> Bool {
        firstMatch(in: text) != nil
    }

    func firstMatch(in text: String) -> Match? {
        guard let result = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
            let range = Range(result.range, in: text)
        else { return nil }
        let groups = (0..<result.numberOfRanges).map { index in
            Range(result.range(at: index), in: text).map { String(text[$0]) }
        }
        return Match(range: range, groups: groups)
    }

    /// Replaces every match with `replacement`, used to strip a price or a VAT rate out of a line.
    func removingMatches(in text: String, with replacement: String = " ") -> String {
        regex.stringByReplacingMatches(
            in: text,
            range: NSRange(text.startIndex..., in: text),
            withTemplate: replacement
        )
    }
}
