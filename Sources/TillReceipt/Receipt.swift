import Foundation

/// Reads the OCR text of a till receipt into line items.
public enum Receipt {
    // Tills print money, weights and counts much the same way wherever they are.
    // These are the symbols and codes a European till is likely to put beside a number.
    private static let moneyWords: Pattern = #"\b(tl|try|eur|usd|gbp|pln|czk|huf|ron|bgn|sek|nok|dkk|chf|zł|kr)\b"#
    private static let money =
        #"(?:[€$£₺₴₽]|zł|kr|tl|try|eur|usd|gbp|pln|czk|huf|ron|bgn|sek|nok|dkk|chf)"#
    private static let trailingPrice = Pattern(
        #"(?:\#(money)\s?\d+(?:[.,]\d{2})?|\d+(?:[.,]\d{2})\s?\#(money)?)\s*[a-z*]?$"#
    )
    private static let weight: Pattern = #"(\d+(?:[.,]\d+)?)\s*(kg|g|gr|ml|l|lt|litre|liter)\b"#

    // OCR reads a receipt in columns, so the price often arrives on a line of its own.
    private static let priceColumn = Pattern(
        #"^[\s*]*\#(money)?\s?(\d{1,6}[.,]\d{2})\s?\#(money)?\s*\*?$"#
    )

    // A weighed item prints its weight on a line of its own: "0.870 KG x 24,95 TL/KG", and a
    // repeated one its count: "2 X 6,50" or Polish "1 szt * 4,99   4,99". The last group is the
    // line total where the till prints it.
    private static let weighedDetail: Pattern =
        #"(\d+(?:[.,]\d+)?)\s*(kg|g|gr|ml|l|lt)\s*[x×*]\s*(\d+(?:[.,]\d+)?)(?:\s+(\d+[.,]\d{2}))?"#
    private static let countedDetail: Pattern =
        #"(\d{1,3})\s*(?:\p{L}{1,4}\.?\s*)?[x×*]\s*(\d+(?:[.,]\d+)?)(?:\s+(\d+[.,]\d{2}))?"#
    private static let unitWords: Pattern = #"\b(kg|g|gr|ml|l|lt|litre|liter)\b"#
    /// A standalone multiplication sign, which is punctuation however much it looks like a word.
    private static let multiplier: Pattern = #"(?<!\p{L})[x×](?!\p{L})"#

    private static let separator: Pattern = #"^[\s\-=_.*#·]*$"#
    private static let anyLetter: Pattern = #"\p{L}"#
    private static let twoLetters: Pattern = #"\p{L}{2,}"#
    private static let punctuation: Pattern = #"[^\p{L}\p{N}\s'&-]"#
    private static let looseNumber: Pattern = #"\b\d+\b"#
    private static let runOfSpaces: Pattern = #"\s+"#

    // MARK: - Public

    /// Reads a whole receipt rather than each line on its own.
    ///
    /// A till prints the shop above the basket and the payment below it, breaks the price and VAT
    /// columns onto lines of their own, gives a weighed or repeated item a detail line of its own,
    /// and repeats a product to show its discount. None of that is visible one line at a time.
    ///
    /// Which product a detail line belongs to is settled by arithmetic rather than by convention:
    /// `0.870 KG x 24,95 TL/KG` comes to 21.71, so it belongs to whichever neighbour rang up
    /// 21.71. Turkish tills print that line above its product and others below, and the sum tells
    /// them apart without the caller having to know. `detailBelongsTo` only breaks a tie.
    ///
    /// - Parameter wholeDocument: keep the shop and the payment block instead of trimming to the
    ///   basket, for when the reading order is too scrambled for the top and bottom to be found.
    public static func parse(
        _ lines: [String],
        locale: ReceiptLocale,
        wholeDocument: Bool = false
    ) -> [LineItem] {
        var items: [LineItem] = []
        // Neither a column nor a detail line can be resolved where it is found: a folded receipt
        // photographs into a mixed reading order, so the item it belongs to may still be ahead.
        var columns: [(column: Column, above: Int)] = []
        var details: [(detail: Detail, above: Int)] = []
        var discounting = false

        for raw in wholeDocument ? lines : basket(lines, locale: locale) {
            // The VAT mark comes off before anything is classified: on a Polish paragon it sits
            // at the end of a detail line, where it would otherwise read as a word.
            let (line, vat) = locale.vat.split(raw)
            // Read from the untouched line first, where a lone VAT mark is the whole column, then
            // from the stripped one, where a Polish till glued its letter onto the price.
            if let column = readColumn(raw, locale: locale) ?? readColumn(line, locale: locale) {
                // A discount prints its own amounts. Counting them would give the item above the
                // discounted subtotal as its price.
                if !discounting { columns.append((column, items.count - 1)) }
            } else if var detail = readDetail(line, locale: locale) {
                detail.vat = vat
                details.append((detail, items.count - 1))
                discounting = false
            } else if locale.discountMarkers.matches(raw) {
                discounting = true
            } else if let item = parseLine(raw, locale: locale) {
                items.append(item)
                discounting = false
            }
        }

        // A till prints one price per item, so a loose price goes to whichever neighbour wants one.
        for (column, above) in columns {
            let wanted = above >= 0 && !column.isSet(on: items[above]) ? above : above + 1
            guard items.indices.contains(wanted), !column.isSet(on: items[wanted]) else { continue }
            column.apply(to: &items[wanted])
        }

        for (detail, above) in details {
            guard let owner = owner(of: detail, above: above, in: items, locale: locale) else { continue }
            apply(detail, to: &items[owner])
        }
        return items
    }

    /// Reads one line on its own terms, with no knowledge of the lines around it.
    ///
    /// Returns `nil` for separators, totals and anything with no word in it.
    public static func parseLine(_ raw: String, locale: ReceiptLocale) -> LineItem? {
        let line = runOfSpaces.removingMatches(in: raw).trimmingCharacters(in: .whitespaces)
        guard line.count >= 2, line.count <= 200, !separator.matches(line) else { return nil }
        guard anyLetter.matches(line), !locale.totalMarkers.matches(line) else { return nil }

        var (text, vat) = locale.vat.split(line)
        let price = trailingPrice.firstMatch(in: text).flatMap { priceValue(in: $0.text) }
        text = trailingPrice.removingMatches(in: text, with: "").trimmingCharacters(in: .whitespaces)

        var quantity = 1.0
        var unit = LineItem.Unit.piece
        var confidence = LineItem.Confidence.medium

        // "25Lİ" counts a pack, so it is read before `weight` claims the L for litres.
        let pack = locale.packSuffix?.firstMatch(in: text)
        if let pack, let count = pack[1].flatMap({ Double($0) }) {
            quantity = count
            confidence = .high
            text.replaceSubrange(pack.range, with: " ")
        }
        let weighed = pack == nil ? weight.firstMatch(in: text) : nil
        if let weighed, let amount = weighed[1].flatMap(Text.number), let token = weighed[2] {
            quantity = amount
            unit = self.unit(of: token)
            confidence = .high
            text.replaceSubrange(weighed.range, with: " ")
        }
        let counted = pack == nil ? locale.countWords.firstMatch(in: text) : nil
        if let counted {
            let pieces = counted.firstCapture.flatMap { Double($0) } ?? 0
            if pieces > 0 { quantity = unit == .piece ? pieces : Text.rounded(quantity * pieces) }
            text.replaceSubrange(counted.range, with: " ")
        }

        let cleaned = runOfSpaces.removingMatches(
            in: looseNumber.removingMatches(in: punctuation.removingMatches(in: text))
        ).trimmingCharacters(in: .whitespaces)
        let name = String(Text.titleCase(cleaned).prefix(120))
        guard name.count >= 2, twoLetters.matches(name), quantity > 0, quantity <= 999_999_999.999 else {
            return nil
        }
        if pack == nil, weighed == nil, counted == nil, !line.contains(where: \.isNumber) {
            confidence = .low
        }

        return LineItem(
            line: line,
            name: name,
            quantity: quantity,
            unit: unit,
            category: categorise(name, locale: locale),
            confidence: confidence,
            vat: vat,
            price: price
        )
    }

    /// The lines between the shop's own details and the payment block: the basket itself.
    public static func basket(_ lines: [String], locale: ReceiptLocale) -> [String] {
        let closing = lines.firstIndex { locale.totalMarkers.matches($0) }
        let head = closing.map { $0 > 0 ? Array(lines[..<$0]) : lines } ?? lines
        var opening = 0
        for (index, line) in head.enumerated() where locale.shopMarkers.matches(line) {
            opening = index + 1
        }
        return head[opening...].filter { !locale.addressMarkers.matches($0) }
    }

    /// Guesses a category from words in the name, falling back to `household` and then `other`.
    public static func categorise(_ name: String, locale: ReceiptLocale) -> LineItem.Category {
        let singular = Text.tokens(name, fold: locale.fold).joined(separator: " ")
        // Singularising lets "Tomatoes" find "tomato", but it also turns "Pringles" into
        // "Pringle", so a keyword is looked for in the plain spelling as well.
        let plain = locale.fold(name)
        for (category, pattern) in locale.categoryWords
        where pattern.matches(singular) || pattern.matches(plain) {
            return category
        }
        return locale.householdWords.matches(singular) || locale.householdWords.matches(plain)
            ? .household : .other
    }

    // MARK: - Columns

    /// A price or a VAT rate that OCR broke out into a line of its own.
    private enum Column {
        case price(Double)
        case vat(Vat)

        func isSet(on item: LineItem) -> Bool {
            switch self {
            case .price: item.price != nil
            case .vat: item.vat != nil
            }
        }

        func apply(to item: inout LineItem) {
            switch self {
            case .price(let value): item.price = value
            case .vat(let value): item.vat = value
            }
        }
    }

    private static func readColumn(_ line: String, locale: ReceiptLocale) -> Column? {
        if let match = priceColumn.firstMatch(in: line), let value = match[1].flatMap(Text.number) {
            return .price(value)
        }
        if let column = locale.vat.column, let match = column.firstMatch(in: line),
            let mark = match[1], let value = locale.vat.read(mark)
        {
            return .vat(value)
        }
        return nil
    }

    // MARK: - Detail lines

    /// A weight or a count printed on a line of its own, waiting to be matched to its product.
    private struct Detail {
        let quantity: Double
        let unit: LineItem.Unit?
        /// What the line comes to, so the arithmetic can say which product it belongs to.
        let total: Double?
        /// The line total where the till printed one, rather than one worked out from the parts.
        let printed: Double?
        /// The VAT mark, when the till put it on the detail line instead of the product line.
        var vat: Vat?
    }

    /// A detail line describes a product without naming one: every word on it is a unit or a
    /// word for counting. That holds whatever the language, which "2 X 6,50" alone would not.
    private static func namesAProduct(_ line: String, locale: ReceiptLocale) -> Bool {
        var rest = locale.fold(line)
        rest = locale.countWords.removingMatches(in: rest, with: " ")
        rest = unitWords.removingMatches(in: rest, with: " ")
        rest = moneyWords.removingMatches(in: rest, with: " ")
        rest = multiplier.removingMatches(in: rest, with: " ")
        return rest.contains(where: \.isLetter)
    }

    private static func readDetail(_ line: String, locale: ReceiptLocale) -> Detail? {
        guard !namesAProduct(line, locale: locale) else { return nil }
        if let match = weighedDetail.firstMatch(in: line),
            let amount = match[1].flatMap(Text.number), let token = match[2],
            let each = match[3].flatMap(Text.number)
        {
            return Detail(
                quantity: amount,
                unit: unit(of: token),
                total: Text.rounded(amount * each),
                printed: match[4].flatMap(Text.number)
            )
        }
        if let match = countedDetail.firstMatch(in: line),
            let pieces = match[1].flatMap({ Double($0) }), let each = match[2].flatMap(Text.number)
        {
            return Detail(
                quantity: pieces,
                unit: nil,
                total: Text.rounded(pieces * each),
                printed: match[3].flatMap(Text.number)
            )
        }
        return nil
    }

    private static func owner(
        of detail: Detail,
        above: Int,
        in items: [LineItem],
        locale: ReceiptLocale
    ) -> Int? {
        let previous = items.indices.contains(above) ? above : nil
        let next = items.indices.contains(above + 1) ? above + 1 : nil
        if let previous, agrees(items[previous].price, detail.total) { return previous }
        if let next, agrees(items[next].price, detail.total) { return next }
        return locale.detailBelongsTo == .previous ? previous ?? next : next ?? previous
    }

    /// Printed totals are rounded to the cent, so the arithmetic only has to agree to within one.
    private static func agrees(_ price: Double?, _ total: Double?) -> Bool {
        guard let price, let total else { return false }
        return abs(price - total) <= 0.02
    }

    private static func apply(_ detail: Detail, to item: inout LineItem) {
        if let unit = detail.unit {
            item.quantity = detail.quantity
            item.unit = unit
        } else {
            item.quantity =
                item.unit == .piece
                ? detail.quantity
                : Text.rounded(item.quantity * detail.quantity)
        }
        if item.price == nil { item.price = detail.printed }
        if item.vat == nil { item.vat = detail.vat }
        item.confidence = .high
    }

    // MARK: - Reading

    private static func unit(of token: String) -> LineItem.Unit {
        switch token.lowercased() {
        case "kg": .kg
        case "g", "gr": .g
        case "ml": .ml
        default: .l
        }
    }

    private static func priceValue(in text: String) -> Double? {
        Text.number(text.filter { $0.isNumber || $0 == "." || $0 == "," })
    }
}
