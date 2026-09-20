extension ReceiptLocale {
    /// English-language receipts. Accents are handled by the Unicode decomposition in `Text`,
    /// so folding here is nothing more than lowercasing.
    public static let english = ReceiptLocale(
        code: "en",
        shopMarkers: #"\b(date|time|receipt\s*no|invoice\s*no|till|terminal|vat\s*reg|company\s*no)\b"#,
        totalMarkers: #"\b(sub-?total|total|amount\s*due|balance|cash|card|change|visa|mastercard|tender)\b|thank\s*you"#,
        addressMarkers: #"\b(street|road|avenue|lane|suite|floor|tel|phone|vat\s*reg)\b|www|http"#,
        discountMarkers: #"^\s*(disc(?:ount)?|promo|offer|saving)s?\s*[.:]|\b(discount|promotion|loyalty|voucher)\b"#,
        householdWords: #"\b(bag|napkin|tissue|towel|detergent|bleach|soap|shampoo|sponge|foil|cling ?film|battery|batterie|bulb|candle|pen|pencil|notebook|tape|sticker|toy|razor|deodorant|perfume|nappy|diaper)"#,
        categoryWords: [
            (.dairy, #"\b(milk|yogurt|yoghurt|cheese|butter|cream|kefir|egg)\b"#),
            (.meat, #"\b(chicken|beef|pork|lamb|turkey|ham|sausage|mince|bacon|steak|salami)\b"#),
            (.seafood, #"\b(salmon|tuna|fish|shrimp|prawn|cod|sardine|mussel|squid)\b"#),
            (.bakery, #"\b(bread|loaf|loave|bagel|bun|croissant|tortilla|pita|baguette)\b"#),
            (.grains, #"\b(rice|pasta|oat|flour|quinoa|couscou|noodle|spaghetti|cereal)\b"#),
            (.legumes, #"\b(lentil|bean|chickpea|pea)\b"#),
            (.produce, #"\b(apple|banana|tomato|onion|garlic|spinach|lettuce|carrot|potato|pepper|cucumber|lemon|orange|mushroom|avocado|berry|grape|salad|broccoli|courgette)\b"#),
            (.condiments, #"\b(oil|vinegar|ketchup|mustard|mayo|mayonnaise|sauce|salt|sugar|honey|spice|jam|olive)\b"#),
            (.beverages, #"\b(juice|water|tea|coffee|soda|cola|beer|wine|lemonade)\b"#),
            (.snacks, #"\b(chip|crisp|cracker|cookie|biscuit|chocolate|popcorn|nut|cashew|almond|pistachio|walnut|hazelnut|wafer)\b"#),
        ],
        countWords: #"(?:^|\s)(\d{1,3})\s?(?:x|pcs?|pieces?|pack)(?:\s|$)|(?:^|\s)x\s?(\d{1,3})(?:\s|$)"#,
        packSuffix: nil,
        detailBelongsTo: .previous,
        fold: { $0.lowercased() }
    )
}
