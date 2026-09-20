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
            ])
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
                == [.snacks, .produce, .dairy, .dairy, .produce, .produce, .produce])
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
            ], locale: .english)

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
                == Receipt.parse(lines("migros"), locale: .turkish).map(\.name))
        #expect(Receipt.parse(["Bread 1.20", "SUBTOTAL 1.20", "CASH 5.00"], locale: both).map(\.name) == ["Bread"])
    }
}
