/// Everything that differs between one country's tills and another's.
///
/// The parser owns the shape of a receipt — a shop on top, a basket, a payment block — and a
/// locale owns its words. Adding a country means filling this in; no parser code changes.
public struct ReceiptLocale: Sendable {
    /// Where a detail line sits relative to the product it describes, used only when the
    /// arithmetic cannot decide. Turkish tills print it above the product; most others below.
    public enum DetailPosition: Sendable {
        case next, previous
    }

    /// BCP 47 language tag, for callers that keep several around.
    public let code: String
    /// The shop's own details. The last match marks where the basket starts.
    public let shopMarkers: Pattern
    /// The payment block. The first match marks where the basket ends.
    public let totalMarkers: Pattern
    /// Address and registry lines, which land mid-basket when the photo is skewed.
    public let addressMarkers: Pattern
    /// Lines that repeat the product above them to show a discount.
    public let discountMarkers: Pattern
    /// Things a kitchen does not stock. Only trusted when no food word matched the same name.
    public let householdWords: Pattern
    /// Food keywords per category, tried in order, matched against folded and singular tokens.
    public let categoryWords: [(LineItem.Category, Pattern)]
    /// Words that count pieces, such as "pcs" or Turkish "adet".
    public let countWords: Pattern
    /// A count written as a suffix on its number, such as Turkish "4LÜ". `nil` where none exists.
    public let packSuffix: Pattern?
    /// How the till marks VAT against a line: a percentage, a letter code, or not at all.
    public let vat: VatNotation
    public let detailBelongsTo: DetailPosition
    /// Folds the alphabet to ASCII so one keyword list serves accented and plain spellings.
    public let fold: @Sendable (String) -> String

    public init(
        code: String,
        shopMarkers: Pattern,
        totalMarkers: Pattern,
        addressMarkers: Pattern,
        discountMarkers: Pattern,
        householdWords: Pattern,
        categoryWords: [(LineItem.Category, Pattern)],
        countWords: Pattern,
        packSuffix: Pattern? = nil,
        vat: VatNotation = .percentage,
        detailBelongsTo: DetailPosition = .previous,
        fold: @escaping @Sendable (String) -> String = { $0.lowercased() }
    ) {
        self.code = code
        self.shopMarkers = shopMarkers
        self.totalMarkers = totalMarkers
        self.addressMarkers = addressMarkers
        self.discountMarkers = discountMarkers
        self.householdWords = householdWords
        self.categoryWords = categoryWords
        self.countWords = countWords
        self.packSuffix = packSuffix
        self.vat = vat
        self.detailBelongsTo = detailBelongsTo
        self.fold = fold
    }
}
