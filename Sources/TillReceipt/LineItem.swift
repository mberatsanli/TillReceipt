/// One product read off a receipt.
public struct LineItem: Equatable, Sendable {
    /// What a line item is measured in. Tills print little else.
    public enum Unit: String, Sendable {
        case piece, g, kg, ml, l
    }

    /// A coarse bucket for the product. `household` is everything a kitchen does not eat,
    /// and `other` is everything the locale's word lists did not recognise.
    public enum Category: String, Sendable, CaseIterable {
        case dairy, meat, seafood, bakery, grains, legumes
        case produce, condiments, beverages, snacks, household, other
    }

    /// How much of the item was read rather than assumed.
    public enum Confidence: String, Sendable {
        case high, medium, low
    }

    /// The OCR line this item was read from, unchanged.
    public let line: String
    public internal(set) var name: String
    public internal(set) var quantity: Double
    public internal(set) var unit: Unit
    public internal(set) var category: Category
    /// `high` when a weight or count was printed, `low` when the line carried no numbers at all.
    public internal(set) var confidence: Confidence
    /// The VAT percentage printed on the line or in the column beside it, when there was one.
    public internal(set) var vatRate: Int?
    /// The price printed on the line or in the column beside it, when there was one.
    public internal(set) var price: Double?
}
