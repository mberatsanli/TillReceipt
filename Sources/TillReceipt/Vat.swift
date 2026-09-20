/// The VAT a till printed against a product.
///
/// Not every country prints a percentage. A Polish paragon marks each line with a letter and
/// lists what the letters mean in its footer, so the mark is kept as it was printed rather than
/// resolved to a number the receipt never showed on that line.
public enum Vat: Sendable, Hashable, Codable {
    /// A percentage, as Turkish and most western European tills print it. `20` means 20%.
    case rate(Int)
    /// A letter standing for a rate the footer lists, such as Polish `A` or `B`.
    case code(String)

    /// The percentage, when the receipt printed one.
    public var rate: Int? {
        if case .rate(let value) = self { return value }
        return nil
    }
}

/// How a till marks VAT on a product line.
public enum VatNotation: Sendable {
    /// A percentage beside the price, such as Turkish `%1` or `%20.`.
    case percentage
    /// A single trailing letter, such as Polish `A` through `G`.
    ///
    /// The associated value is the body of a character class, so `"A-G"` and `"ABCDEG"` both work.
    case letters(String)
    /// Nothing printed against each line.
    case none

    /// Matches the mark where it sits on a product line.
    var inline: Pattern? {
        switch self {
        case .percentage: Pattern(#"%\s?(\d{1,2})(?:[.,]\d+)?"#)
        // Anchored to the end and kept clear of words, so a name is never mistaken for a rate.
        case .letters(let letters): Pattern(#"(?<![\p{L}\d])([\#(letters)])\s*$"#, caseInsensitive: false)
        case .none: nil
        }
    }

    /// Matches the mark where OCR has broken it onto a line of its own.
    ///
    /// Only a percentage is distinctive enough to stand alone; a lone letter is more likely noise.
    var column: Pattern? {
        switch self {
        case .percentage: Pattern(#"^[\s*]*%\s?(\d{1,2})(?:[.,]\d+)?\s*[.,]?$"#)
        case .letters, .none: nil
        }
    }

    /// Takes the mark off a line and hands back both, so the rest of the parser never has to
    /// step around it. A Polish till prints the letter last, after the price and after the
    /// numbers of a detail line, where it would otherwise read as a word.
    func split(_ line: String) -> (text: String, vat: Vat?) {
        guard let inline, let match = inline.firstMatch(in: line), let mark = match[1] else {
            return (line, nil)
        }
        return (inline.removingMatches(in: line), read(mark))
    }

    func read(_ captured: String) -> Vat? {
        switch self {
        case .percentage: Int(captured).map(Vat.rate)
        case .letters: .code(captured.uppercased())
        case .none: nil
        }
    }
}
