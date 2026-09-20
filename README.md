# TillReceipt

Turns the OCR text of a till receipt into structured line items.

No model, no network, no dependencies — Foundation and nothing else. You bring the OCR, and this
reads the receipt out of it.

Runs on iOS, macOS, tvOS, watchOS, visionOS and Linux.

```swift
.package(url: "https://github.com/mberatsanli/TillReceipt", from: "0.1.0")
```

```swift
import TillReceipt

let items = Receipt.parse(linesFromVision, locale: .turkish)
```

```swift
LineItem(line: "MIGROS KIRAZ 500 G",     name: "Migros Kiraz",         quantity: 500,  unit: .g,     category: .produce,   price: 69.95, vat: .rate(1))
LineItem(line: "DOMATES SALKIM PKT",     name: "Domates Salkim Pkt",   quantity: 0.87, unit: .kg,    category: .produce,   price: 21.71, vat: .rate(1))
LineItem(line: "MIGROS PLASTIK POSET",   name: "Migros Plastik Poset", quantity: 1,    unit: .piece, category: .household, price: 0.25,  vat: .rate(20))
```

Reading a photographed receipt end to end:

```swift
import TillReceipt
import Vision

let request = VNRecognizeTextRequest()
request.recognitionLevel = .accurate
request.recognitionLanguages = ["tr-TR", "en-US"]
try VNImageRequestHandler(cgImage: image).perform([request])

let lines = (request.results ?? [])
    .sorted { $0.boundingBox.maxY > $1.boundingBox.maxY }
    .compactMap { $0.topCandidates(1).first?.string }

let items = Receipt.parse(lines, locale: .turkish)
```

## Why not one regex per line

A receipt is a document, not a list of strings, and almost everything that matters is invisible
one line at a time.

**The shop is on top and the payment is underneath.** Read line by line, a supermarket's street
address becomes four groceries. `Receipt.parse` finds the last line that belongs to the shop and
the first that belongs to the payment, and keeps what is between them.

**OCR reads in columns.** The product, its VAT mark and its price come back as separate lines, in
an order that depends on how the paper was lying — a folded receipt photographs into a reading
order that flips halfway down. A till prints one price per item, so a loose price is given to
whichever neighbour does not have one yet.

**Weighed and repeated items get a line of their own.** Which product `0.870 KG x 24,95 TL/KG`
belongs to is settled by arithmetic, not by convention: it comes to 21.71, so it belongs to
whichever neighbour rang up 21.71. Turkish tills print that line above its product and most
others print it below, and the sum tells them apart without the caller having to know.

**A detail line names no product.** Every word on it is a unit or a word for counting, which is
what separates `1 szt * 4,99` and `0.870 KG x 24,95 TL/KG` from a product — in any language.

**A discount repeats the product it discounts.** Counting both would double the basket.

## Locales

A locale is data, not code. `.turkish`, `.english` and `.polish` ship with the package, along
with `.brands` — the packets a till prints instead of naming the food. `.combined` reads several
at once:

```swift
Receipt.parse(lines, locale: .combined("tr", [.turkish, .brands]))
Receipt.parse(lines, locale: .combined("tr-en", [.turkish, .english, .brands]))
```

A receipt rarely says crisps; it says `PRINGLES`. `.brands` carries no markers of its own, so it
is only useful combined with a real locale.

### Adding a country

Fill in a `ReceiptLocale`. Nothing in the parser changes.

```swift
extension ReceiptLocale {
    public static let czech = ReceiptLocale(
        code: "cs",
        shopMarkers: #"\b(datum|čas|dič|ičo|účtenka)\b"#,      // last match opens the basket
        totalMarkers: #"\b(celkem|mezisoučet|hotovost|karta)\b"#,  // first match closes it
        addressMarkers: #"\b(ulice|náměstí|tel)\b|www"#,       // dropped wherever they land
        discountMarkers: #"\b(sleva|akce)\b"#,                 // repeat the product above them
        householdWords: #"\b(taska|ubrousk|sampon|baterie)"#,  // matched against folded text
        categoryWords: [
            (.dairy, #"(mleko|syr|jogurt|maslo)"#),
            (.bakery, #"(chleb|rohlik|pecivo)"#),
            // …one row per category, tried in order
        ],
        countWords: #"(?:^|\s)(\d{1,3})\s?(?:ks|x)(?:\s|$)"#,
        vat: .percentage,
        detailBelongsTo: .previous,
        fold: { $0.folding(options: .diacriticInsensitive, locale: nil).lowercased() }
    )
}
```

Only the first eight are required; `packSuffix`, `vat`, `detailBelongsTo` and `fold` all have
defaults. Four things are worth getting right:

**`fold`** turns the alphabet into ASCII before any keyword is matched, and the keyword lists are
written folded. Unicode decomposition gets you most of the way, but it leaves some letters
standing — Turkish `ı` and `İ`, Polish `ł` — and those then split a word in two. Where your
alphabet has one, map it by hand as `.turkish` and `.polish` do.

**`\b` is ASCII.** It never fires next to `ş`, `ğ` or `ł`, so `/\bşeker\b/` cannot match
anything, ever. Since patterns run against folded text this is usually moot, but it is why the
folded keywords in agglutinative languages carry no trailing boundary: Turkish `poşet` has to
catch `poşeti` and `poşetler` too.

**`vat`** says how the till marks tax. `.percentage` for `%20` beside the price, `.letters("A-G")`
for a Polish paragon, `.none` where nothing is printed per line. A letter is kept as
`Vat.code("A")` rather than resolved to a rate the line never carried.

**`detailBelongsTo`** only breaks a tie. The arithmetic decides whenever the prices are legible,
so set it to whichever side your tills favour and move on.

### A note on Turkish and Polish

`ı`, `İ` and `ł` have no Unicode decomposition, so stripping combining marks leaves them
standing and they split a word in two. `balık` becomes `bal` and `k`, and `bal` is honey — which
is how fish ends up filed under condiments. Folding first is the whole fix.

And `'STİKER'.lowercased()` is `'sti̇ker'` — `İ` lowercases to `i` plus a combining dot above,
which then survives into the name. `Text.titleCase` drops it.

## API

### `Receipt.parse(_:locale:wholeDocument:) -> [LineItem]`

The whole thing. `wholeDocument: true` skips the trim to the basket, for when the reading order
is too scrambled for the top and bottom to be found.

### `Receipt.parseLine(_:locale:) -> LineItem?`

One line, on its own terms. `nil` for separators, totals and anything without a word in it.

### `Receipt.basket(_:locale:) -> [String]`

Just the trim: the lines between the shop's details and the payment block.

### `Receipt.categorise(_:locale:) -> LineItem.Category`

Just the category guess.

### `LineItem`

| property | type | |
| --- | --- | --- |
| `line` | `String` | the OCR line it was read from, unchanged |
| `name` | `String` | |
| `quantity` | `Double` | |
| `unit` | `.piece` `.g` `.kg` `.ml` `.l` | |
| `category` | see below | `.household` for what a kitchen does not eat |
| `price` | `Double?` | |
| `vat` | `Vat?` | `.rate(20)` or `.code("A")`; `vatRate` gives the percentage when there is one |
| `confidence` | `.high` `.medium` `.low` | `.high` when a weight or count was printed, `.low` when the line carried no numbers at all |

Categories: `dairy`, `meat`, `seafood`, `bakery`, `grains`, `legumes`, `produce`, `condiments`,
`beverages`, `snacks`, `household`, `other`.

`LineItem` is `Codable`, `Hashable` and `Sendable`.

## What it does not do

**OCR.** Give it lines of text. `VNRecognizeTextRequest` does this on device for free and beats
Tesseract badly on thermal paper.

**Normalise product names.** `BISK. EKSTR. 184G.` stays `Bisk Ekstr`. Tills truncate to around 24
characters and drop vowels, and turning that back into a real product name needs a catalogue,
which is a different problem.

**Cope with a badly photographed receipt.** Text order is all this sees. When a photo is skewed
enough that background text bleeds in, some of it becomes line items. The fix is geometry — the
products sit in one left-aligned column and stray text does not — which means taking bounding
boxes rather than strings. That is the plan for the next version, and on iOS the boxes are
already there for the taking.

## Tests

The fixtures are the OCR of five real supermarket receipts — three Turkish, two Biedronka
paragons — with the document, tax and card numbers masked digit for digit. One of each is
deliberately a bad photograph: a folded receipt whose columns swap reading order halfway down,
and a crumpled one the OCR partly loses.

```bash
swift test
```

## License

MIT
