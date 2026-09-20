import Foundation
import Testing

@testable import TillReceipt

/// The OCR of three real Turkish supermarket receipts, with identifiers masked digit for digit.
private let fixtures: [String: [String]] = {
    guard let url = Bundle.module.url(forResource: "receipts", withExtension: "json"),
        let data = try? Data(contentsOf: url),
        let decoded = try? JSONDecoder().decode([String: [String]].self, from: data)
    else { fatalError("fixtures are missing") }
    return decoded
}()

private func lines(_ name: String) -> [String] {
    guard let lines = fixtures[name] else { fatalError("no fixture named \(name)") }
    return lines
}

@Suite("A real Migros receipt")
struct MigrosTests {
    let items = Receipt.parse(lines("migros"), locale: .turkish)

    @Test("keeps the basket and drops the shop, the columns and the payment")
    func basket() {
        #expect(
            items.map(\.name) == [
                "Migros Plastik Poset", "Tadim Syh Aycekirdek", "Migros Kiraz",
                "Migros Hellim Peyn", "Migros Cecil Peyniri", "Domates Salkim Pkt",
                "Biber Sivri", "Kayisi Igdir",
            ]
        )
    }

    @Test("gives each weighed item the detail line that rang up its price")
    func weighed() {
        func item(_ name: String) -> LineItem { items.first { $0.name == name }! }
        // 0.870 x 24,95 = 21.71, which is what the domates rang up, not the cheese above it.
        #expect(item("Domates Salkim Pkt").quantity == 0.87)
        #expect(item("Domates Salkim Pkt").unit == .kg)
        #expect(item("Biber Sivri").quantity == 0.4)
        #expect(item("Kayisi Igdir").quantity == 1.2)
        // The packaged cheese keeps its own single unit.
        #expect(item("Migros Cecil Peyniri").quantity == 1)
        #expect(item("Migros Cecil Peyniri").unit == .piece)
    }

    @Test("reads the price and VAT columns back onto their items")
    func columns() {
        #expect(items.map(\.price) == [0.25, 40, 69.95, 71.95, 91.95, 21.71, 21.98, 59.94])
        #expect(items.map(\.vatRate) == [20, 1, 1, 1, 1, 1, 1, 1])
    }

    @Test("separates food from what a kitchen does not stock")
    func household() {
        #expect(items[0].category == .household)
        #expect(
            items.filter { $0.category != .household }.map(\.category)
                == [.snacks, .produce, .dairy, .dairy, .produce, .produce, .produce]
        )
    }
}

@Suite("A real A101 receipt")
struct A101Tests {
    let items = Receipt.parse(lines("a101-market"), locale: .turkish)

    private func item(_ prefix: String) -> LineItem {
        items.first { $0.name.hasPrefix(prefix) }!
    }

    @Test("counts a Turkish pack suffix as pieces, not litres")
    func packSuffix() {
        #expect(item("Krdm").quantity == 25)
        #expect(item("Krdm").unit == .piece)
    }

    @Test("gives the multiplier line to the item whose price it matches")
    func multiplier() {
        // 2 x 6,50 = 13.00, the coffee's price. The kefir above it rang up 22.00 on its own.
        #expect(item("Keyfe").quantity == 2)
        #expect(item("Kefirix").quantity == 250)
        #expect(item("Kefirix").unit == .ml)
        #expect(item("Fenomen Pop").quantity == 3)
    }

    @Test("files the mouse, the tape and the stickers as household")
    func household() {
        let names = items.filter { $0.category == .household }.map(\.name)
        #expect(names.contains { $0.contains("Mouse") })
        #expect(names.contains { $0.contains("Bandi") })
    }
}

@Suite("A real A101 receipt photographed askew")
struct SkewedTests {
    @Test("counts a repeated product once per line and ignores its discount lines")
    func repeated() {
        let items = Receipt.parse(lines("a101-cerezya"), locale: .turkish)
        #expect(items.filter { $0.name.hasPrefix("Kaju") }.count == 5)
        #expect(items.allSatisfy { !$0.name.lowercased().hasPrefix("ind") })
    }
}

@Suite("Turkish letters")
struct TurkishTests {
    @Test("folds the alphabet before matching, so accents cannot hide a word")
    func folding() {
        #expect(Receipt.categorise("Balık", locale: .turkish) == .seafood)
        #expect(Receipt.categorise("Süt", locale: .turkish) == .dairy)
        #expect(Receipt.categorise("Şeker", locale: .turkish) == .condiments)
        #expect(Receipt.categorise("Soğan", locale: .turkish) == .produce)
        #expect(Receipt.categorise("ÇEREZYACEVİZİÇİ", locale: .turkish) == .snacks)
    }

    @Test("drops the combining dot that İ leaves behind when lowercased")
    func combiningDot() {
        #expect(Receipt.parseLine("STİKER ETİKET", locale: .turkish)?.name == "Stiker Etiket")
    }
}

@Suite("An English receipt")
struct EnglishTests {
    @Test("reads the basket with the detail line under its product")
    func basket() {
        let items = Receipt.parse(
            [
                "THE CORNER SHOP", "12 Market Street", "Date: 04/02/2026",
                "Semi-skimmed milk 1L", "1.05",
                "Cheddar cheese 250g", "3.40",
                "Tomatoes", "0.6 kg x 2.50", "1.50",
                "Shopping bag", "0.20",
                "TOTAL", "6.15", "CASH", "10.00",
            ],
            locale: .english
        )

        #expect(items.map(\.name) == ["Semi-skimmed Milk", "Cheddar Cheese", "Tomatoes", "Shopping Bag"])
        #expect(items.map(\.quantity) == [1, 250, 0.6, 1])
        #expect(items.map(\.unit) == [.l, .g, .kg, .piece])
        #expect(items.map(\.category) == [.dairy, .dairy, .produce, .household])
        #expect(items.map(\.price) == [1.05, 3.4, 1.5, 0.2])
    }
}

@Suite("Combined locales")
struct CombinedTests {
    let both = ReceiptLocale.combined("tr-en", [.turkish, .english])

    @Test("reads either language without being told which")
    func eitherLanguage() {
        #expect(Receipt.categorise("Balık", locale: both) == .seafood)
        #expect(Receipt.categorise("Salmon", locale: both) == .seafood)
        #expect(Receipt.categorise("Süt", locale: both) == .dairy)
        #expect(Receipt.categorise("Milk", locale: both) == .dairy)
    }

    @Test("keeps the Turkish pack suffix and both sets of totals")
    func merged() {
        #expect(
            Receipt.parse(lines("migros"), locale: both).map(\.name)
                == Receipt.parse(lines("migros"), locale: .turkish).map(\.name)
        )
        #expect(Receipt.parse(["Bread 1.20", "SUBTOTAL 1.20", "CASH 5.00"], locale: both).map(\.name) == ["Bread"])
    }
}

@Suite("A real Biedronka paragon")
struct BiedronkaTests {
    let items = Receipt.parse(lines("biedronka-wroclaw"), locale: .polish)

    @Test("keeps the basket between the fiscal header and the sales breakdown")
    func basket() {
        #expect(items.map(\.name) == ["Chlebpszen-zyt", "Ser Ż Swiat", "Poledu Cos"])
    }

    @Test("reads the VAT letter the till prints against the price, as in 1,99C")
    func vatLetters() {
        #expect(items.map(\.vat) == [.code("C"), .code("C"), .code("C")])
        // Nothing invents a percentage: a paragon lists what C means only in its footer.
        #expect(items.allSatisfy { $0.vatRate == nil })
    }

    @Test("takes the quantity and price from the line printed above each product")
    func details() {
        #expect(items.map(\.price) == [1.99, 3.29, 4.99])
        #expect(items[0].quantity == 550)
        #expect(items[0].unit == .g)
        #expect(items[0].category == .bakery)
        #expect(items[1].category == .dairy)
    }

    @Test("leaves the discount and the discounted subtotal out of the basket")
    func discounts() {
        // "Rabat" prints -2,00 and then 2,99, which is not any item's price.
        #expect(items.allSatisfy { $0.price != 2.99 })
    }
}

@Suite("A real Biedronka paragon, crumpled")
struct CrumpledBiedronkaTests {
    let items = Receipt.parse(lines("biedronka-jaslo"), locale: .polish)

    @Test("multiplies each product by the count on the line above it")
    func counts() {
        #expect(items.map(\.name) == ["Króuka Kakaowa", "Kroukapremium", "Mieszpiernpren", "Plernikidomino"])
        // 2 x 300 g, a line the OCR lost, 2 x 200 g, 4 x 175 g.
        #expect(items.map(\.quantity) == [600, 300, 400, 700])
        #expect(items.map(\.price) == [19.98, nil, 25.98, 35.96])
        #expect(items.map(\.vat) == [.code("A"), nil, .code("C"), .code("C")])
    }

    @Test("drops every OPUST line and the totals it prints")
    func discounts() {
        // Four OPUST lines, their negative amounts, the discounted subtotals, and OPUSTY ŁĄCZNIE.
        #expect(items.count == 4)
        #expect(items.allSatisfy { !$0.name.lowercased().contains("opust") })
        #expect(items.allSatisfy { $0.price.map { $0 > 0 } ?? true })
    }

    @Test("categorises what the OCR read clearly and leaves the rest alone")
    func categories() {
        // "Króuka" and "Plerniki" are misreadings of Krówka and Pierniki; the dictionary is
        // not stretched to cover them.
        #expect(items.map(\.category) == [.snacks, .other, .snacks, .other])
    }
}

@Suite("Word boundaries at the end of an alternation")
struct BoundaryTests {
    @Test("a marker that is the start of a longer word still closes the basket")
    func trailingBoundary() {
        // `\b` after "opodatk" never fires, because the next letter is a word character.
        #expect(
            Receipt.basket(["Chleb 1,99", "SPRZEDAŻ OPODATKOWANA C", "SUMA PLN"], locale: .polish) == ["Chleb 1,99"]
        )
        // Turkish has the same shape in "KREDI KARTI".
        #expect(Receipt.basket(["Ekmek 5,00", "KREDI KARTI", "*22.00"], locale: .turkish) == ["Ekmek 5,00"])
    }

    @Test("an abbreviation ending in a full stop is still an address")
    func abbreviations() {
        #expect(Receipt.basket(["ul. Grabarska 2", "Chleb"], locale: .polish) == ["Chleb"])
        #expect(Receipt.basket(["Zafer Mah. 3", "Ekmek"], locale: .turkish) == ["Ekmek"])
    }
}

@Suite("Brands")
struct BrandTests {
    let turkish = ReceiptLocale.combined("tr", [.turkish, .brands])

    @Test("reads the packet when the receipt never names the food")
    func brands() {
        #expect(Receipt.categorise("PRINGLES ORIGINAL", locale: turkish) == .snacks)
        #expect(Receipt.categorise("COCA COLA 1L", locale: turkish) == .beverages)
        #expect(Receipt.categorise("ACTIVIA SADE", locale: turkish) == .dairy)
        #expect(Receipt.categorise("ÜLKER ÇİKOLATA", locale: turkish) == .snacks)
        // A Polish receipt carries the same packets.
        #expect(Receipt.categorise("OREO 176G", locale: .combined("pl", [.polish, .brands])) == .snacks)
    }

    @Test("finds a brand that singularising would otherwise mangle")
    func plurals() {
        // "Pringles" reduces to "pringle" and "Lays" to "lay", so the plain spelling is tried too.
        #expect(Receipt.categorise("LAYS SUPERPACK", locale: turkish) == .snacks)
        #expect(Receipt.categorise("SNICKERS 50G", locale: turkish) == .snacks)
        // The food words still work through the singular form.
        #expect(Receipt.categorise("Tomatoes", locale: .english) == .produce)
    }

    @Test("a till's own abbreviation is beyond any word list")
    func abbreviations() {
        // "Keyfe hazır Türk kahvesi" with the vowels dropped exists in no catalogue.
        #expect(Receipt.categorise("KEYFE HZR TRK KHVE S", locale: turkish) == .other)
    }
}
