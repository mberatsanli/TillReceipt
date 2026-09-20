extension ReceiptLocale {
    /// Never matches, for the parts of a locale that carry no words of their own.
    private static let never: Pattern = #"(?!)"#

    /// Brands a till prints instead of naming the food: "PRINGLES", "OREO", "COCA COLA".
    ///
    /// A receipt rarely says biscuit or crisps; it says what is on the packet, and the packet is
    /// often the same in every country. This carries no markers, so it is only useful combined
    /// with a real locale:
    ///
    /// ```swift
    /// Receipt.parse(lines, locale: .combined("tr", [.turkish, .brands]))
    /// ```
    public static let brands = ReceiptLocale(
        code: "brands",
        shopMarkers: never,
        totalMarkers: never,
        addressMarkers: never,
        discountMarkers: never,
        householdWords: #"(ariel|persil|domestos|cif|fairy|finish|colgate|nivea|gillette|duracell|pampers)"#,
        categoryWords: [
            (
                .dairy,
                #"(danone|activia|actimel|philadelphia|pinar|sutas|icim|yayla|mlekovita|laciate|piatnica|zott|hochland|kiri|milka drink)"#
            ),
            (.meat, #"(namet|pinar et|maret|sokolow|morliny|tarczynski|berlinki|krakus)"#),
            (.bakery, #"(uno|eti burcak|wasa|schar|oskroba)"#),
            (.grains, #"(barilla|lubella|knorr|maggi|yayla makarna|filiz|reis|melissa)"#),
            (.condiments, #"(nutella|heinz|hellmann|calve|tat|tamek|kuhne|winiary|develey|komagene)"#),
            (
                .beverages,
                #"(coca[\s-]?cola|pepsi|fanta|sprite|lipton|nescafe|jacobs|tchibo|dogadan|caykur|beypazari|erikli|tymbark|kubus|zywiec|nestea|red bull|sirma|damla)"#
            ),
            (
                .snacks,
                #"(pringles|oreo|snickers|mars|bounty|twix|kitkat|milka|ulker|eti\b|lays|ruffles|doritos|cheetos|haribo|toblerone|ferrero|raffaello|wedel|wawel|goplana|delicje|princessa|grzeski|prince polo|3bit|lubisie|tago|jutrzenka|bahlsen|leibniz|lotus)"#
            ),
        ],
        countWords: never,
        fold: { $0.lowercased() }
    )
}
