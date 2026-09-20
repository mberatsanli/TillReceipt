# TillReceipt

Turns the OCR text of a till receipt into structured line items.

No model, no network, no dependencies — Foundation and nothing else. You bring the OCR, and this
reads the receipt out of it.

```swift
.package(url: "https://github.com/<you>/TillReceipt", from: "0.1.0")
```

```swift
import TillReceipt

let items = Receipt.parse(linesFromVision, locale: .turkish)
```

```swift
LineItem(line: "MIGROS KIRAZ 500 G",   name: "Migros Kiraz",       quantity: 500,  unit: .g,     category: .produce,   price: 69.95, vatRate: 1,  confidence: .high)
LineItem(line: "DOMATES SALKIM PKT",   name: "Domates Salkim Pkt", quantity: 0.87, unit: .kg,    category: .produce,   price: 21.71, vatRate: 1,  confidence: .high)
LineItem(line: "MIGROS PLASTIK POSET", name: "Migros Plastik Poset", quantity: 1,  unit: .piece, category: .household, price: 0.25,  vatRate: 20, confidence: .low)
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
address becomes four groceries. `parseReceipt` finds the last line that belongs to the shop and
the first that belongs to the payment, and keeps what is between them.

**OCR reads in columns.** The product, its VAT rate and its price come back as three separate
lines, in an order that depends on how the paper was lying. A till prints one price per item, so
a loose price is given to whichever neighbour does not have one yet.

**Weighed and repeated items get a line of their own.** Which product `0.870 KG x 24,95 TL/KG`
belongs to is settled by arithmetic, not by convention: it comes to 21.71, so it belongs to
whichever neighbour rang up 21.71. Turkish tills print that line above its product and most
others print it below, and the sum tells them apart without the caller having to know.

**A discount repeats the product it discounts.** Counting both would double the basket.

## Locales

A locale is data, not code: the words that mark a shop, a payment, an address, a discount and a
food, plus how to fold the alphabet to ASCII. `.turkish` and `.english` ship with the package,
and `.combined` reads either at once.

```swift
Receipt.parse(lines, locale: .combined("tr-en", [.turkish, .english]))
```

Writing one for another country means filling in a `ReceiptLocale`. Pull requests welcome.

### A note on Turkish

Two things break naive Turkish text handling, and both are handled here:

`ı` and `İ` have no Unicode decomposition, so stripping combining marks leaves them standing and
they split a word in two. `balık` becomes `bal` and `k`, and `bal` is honey — which is how fish
ends up filed under condiments. Every pattern is matched against folded text instead.

`\b` is defined on ASCII word characters, so it never fires next to `ş`, `ğ` or `İ`. A pattern
like `/\bşeker\b/` cannot match anything, ever. And `'STİKER'.toLowerCase()` is `'sti̇ker'` — `İ`
lowercases to `i` plus a combining dot above, which then survives into the name.

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
| `vatRate` | `Int?` | percentage |
| `confidence` | `.high` `.medium` `.low` | `.high` when a weight or count was printed, `.low` when the line carried no numbers at all |

Categories: `dairy`, `meat`, `seafood`, `bakery`, `grains`, `legumes`, `produce`, `condiments`,
`beverages`, `snacks`, `household`, `other`.

## What it does not do

**OCR.** Give it lines of text. `VNRecognizeTextRequest` does this on device for free and beats
Tesseract badly on thermal paper.

**Normalise product names.** `BISK. EKSTR. 184G.` stays `Bisk Ekstr`. Tills truncate to around 24
characters and drop vowels, and turning that back into a real product name needs a catalogue,
which is a different problem.

**Cope with a badly photographed receipt.** Text order is all this sees. When a photo is skewed
enough that background text bleeds in, some of it becomes line items. The fix is geometry — the
products sit in one left-aligned column and stray text does not — which means taking bounding
boxes rather than strings. That is the plan for the next version, and on iOS the boxes are already there for the taking.

## Tests

The fixtures are the OCR of three real Turkish supermarket receipts, with the document, tax and
card numbers masked digit for digit.

```bash
swift test
```

## License

MIT
