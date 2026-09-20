# Changelog

All notable changes to this project are documented here, following
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
