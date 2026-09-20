extension ReceiptLocale {
    /// One locale that reads receipts in any of several languages, for shops on a border, tourist
    /// tills, or an app whose OCR is set to more than one language.
    ///
    /// The first locale wins where a setting cannot be merged: the pack suffix, and which side a
    /// detail line sits on.
    public static func combined(_ code: String, _ locales: [ReceiptLocale]) -> ReceiptLocale {
        guard let first = locales.first else {
            preconditionFailure("combined needs at least one locale")
        }

        var categories: [(LineItem.Category, [Pattern])] = []
        for locale in locales {
            for (category, pattern) in locale.categoryWords {
                if let index = categories.firstIndex(where: { $0.0 == category }) {
                    categories[index].1.append(pattern)
                } else {
                    categories.append((category, [pattern]))
                }
            }
        }

        return ReceiptLocale(
            code: code,
            shopMarkers: either(locales.map(\.shopMarkers)),
            totalMarkers: either(locales.map(\.totalMarkers)),
            addressMarkers: either(locales.map(\.addressMarkers)),
            discountMarkers: either(locales.map(\.discountMarkers)),
            householdWords: either(locales.map(\.householdWords)),
            categoryWords: categories.map { ($0.0, either($0.1)) },
            countWords: either(locales.map(\.countWords)),
            packSuffix: locales.compactMap(\.packSuffix).first,
            vat: first.vat,
            detailBelongsTo: first.detailBelongsTo,
            fold: { value in
                locales.reduce(value) { folded, locale in locale.fold(folded) }
            }
        )
    }

    private static func either(_ patterns: [Pattern]) -> Pattern {
        Pattern(patterns.map { "(?:\($0.source))" }.joined(separator: "|"))
    }
}
