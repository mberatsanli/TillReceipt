# Changelog

All notable changes to this project are documented here, following
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.1]

### Added

- `.brands`, a locale of the packets a till prints instead of naming the food, to combine with a
  real one. A Turkish receipt full of `PRINGLES` and `COCA COLA` went from 3 of 15 recognised to
  13 of 15.
- Fixtures for two real Biedronka paragons, and tests for both.

### Fixed

- A VAT letter printed against the price, as Biedronka's `1,99C`, was not read at all.
- A detail line above its product is the Polish arrangement too; `.polish` said otherwise.
- `OPUST` and `Rabat` lines print their own amounts, which were being taken as an item's price.
- A `\b` at the end of an alternation never fires where the next letter is a word character, so
  `SPRZEDAŻ OPODATKOWANA` never closed a Polish basket and `KREDI KARTI` never closed a Turkish
  one. Abbreviations ending in a full stop — `ul.`, `mah.` — never matched either.
- Combining locales renumbers a pattern's capture groups, so a count written in the second
  locale's words was silently ignored.
- Singularising turned `Pringles` into `Pringle`, hiding any brand ending in an s.

## [0.1.0]

First release.

### Added

- `Receipt.parse(_:locale:wholeDocument:)` reads a receipt as a document: it trims the shop and
  the payment block away, takes the price and VAT columns back to their items, and gives a
  weighed or repeated item the detail line whose arithmetic matches its price.
- `Receipt.parseLine(_:locale:)`, `Receipt.basket(_:locale:)` and `Receipt.categorise(_:locale:)`
  for the individual steps.
- `ReceiptLocale`, describing a country's tills as data, with `.turkish`, `.english` and
  `.polish`, and `.combined(_:_:)` to read several languages at once.
- `Vat`, which keeps a percentage or a letter code as the till printed it.
