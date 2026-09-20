extension ReceiptLocale {
    private static let turkishFolds: [Character: Character] = [
        "ı": "i", "İ": "i", "ş": "s", "Ş": "s", "ğ": "g", "Ğ": "g",
        "ü": "u", "Ü": "u", "ö": "o", "Ö": "o", "ç": "c", "Ç": "c",
    ]

    /// Turkish receipts, as printed by a yeni nesil ÖKC till.
    ///
    /// Two traps shape this locale. `ı` and `İ` have no Unicode decomposition, so stripping
    /// combining marks leaves them standing and they split a word in two — "balık" becomes "bal"
    /// and "k", and "bal" is honey. And `\b` is defined on ASCII word characters, so it never
    /// fires next to `ş`, `ğ` or `İ`. Everything here is matched against folded text, and because
    /// Turkish glues its suffixes on, the keywords carry no trailing boundary: "poşet" must also
    /// catch "poşeti" and "poşetler".
    public static let turkish = ReceiptLocale(
        code: "tr",
        shopMarkers: #"\b(tarih|saat|fi[şs]\s*no|belge\s*no|ettn|z\s*no|ek[üu]\s*no|sicil)\b|v\.?\s?d\.?[:\/]"#,
        totalMarkers:
            #"\b(ara\s*toplam|top\s*kdv|topkdv|toplam|mal\s*\/?\s*hizmet|[öo]denecek|matrah|ortak\s*pos|nakit|kredi\s*kart|banka\s*kart)\b"#,
        addressMarkers:
            #"\b(mahalle|mah\.|cadde|cad\.|sokak|sok\.|bulvar|bulv|mersis|vergi|kasiyer|magaza|no:\s?\d)\b|v\.?\s?d\.?[:\/]|www|http"#,
        discountMarkers: #"^\s*[iİ]nd(?:irim)?\s*[.:]|indirim|kampanya|promosyon|hediye"#,
        householdWords:
            #"\b(mouse|klavye|kablo|sarj|ampul|bant|band|etiket|stiker|kalem|defter|silgi|zarf|poset|torba|sepet|koli|deterjan|camasir|bulasik|sampuan|sabun|pecete|havlu|mendil|islak|temizlik|yumusatici|corap|terlik|firca|macun|tiras|folyo|strec|kurdan|cakmak|sigara|oyuncak|parfum|deodorant)|\b(pil|mum|ped|bez|bezi)\b"#,
        categoryWords: [
            (.dairy, #"(sut|yogurt|peyn|tereyag|yumurta|kasar|hellim|kefir|ayran|krema|labne|cokelek)"#),
            (.meat, #"(tavuk|dana|kuzu|sucuk|kofte|sosis|salam|pastirma|kiyma|kanat|bonfile|hindi|jambon)"#),
            (.seafood, #"(balik|somon|karides|hamsi|levrek|cipura|midye|uskumru|ton balig)"#),
            (.bakery, #"(ekmek|simit|pogaca|borek|lavas|bazlama|galeta|kruvasan)"#),
            (.grains, #"(pirinc|makarna|bulgur|sehriye|yulaf|irmik|eriste|nisasta|kuskus)|\b(un|misir)\b"#),
            (.legumes, #"(mercimek|fasulye|nohut|bezelye|barbunya|bakla)"#),
            (
                .produce,
                #"(domate|sogan|ispanak|patate|biber|salatalik|elma|muz|mantar|havuc|kabak|patlican|marul|maydanoz|limon|portakal|uzum|cilek|karpuz|kavun|seftali|armut|kiraz|kayisi|erik|avokado|brokoli|karnabahar|pirasa|roka|dereotu|sarimsak|salkim|meyve|sebze)"#
            ),
            (
                .condiments,
                #"(zeytinyag|sirke|salca|seker|hardal|mayonez|ketcap|baharat|zeytin|recel|tahin|pekmez|nutella)|\b(tuz|bal|sos|yag)\b"#
            ),
            (.beverages, #"(kahve|gazoz|limonata|maden suyu|meyve suyu|nektar|ayran)|\b(su|cay|kola|soda)\b"#),
            (
                .snacks,
                #"(cips|biskuvi|bisk|cikolata|kraker|gofret|kuruyemis|cerez|kaju|badem|fistik|ceviz|findik|leblebi|aycekirdek|kurabiye|lokum|helva|sakiz|draje|dondurma)"#
            ),
        ],
        countWords: #"(?:^|\s)(\d{1,3})\s?(?:adet|tane|x)(?:\s|$)|(?:^|\s)x\s?(\d{1,3})(?:\s|$)"#,
        // "4LÜ", "25Lİ", "6'LI" count a pack. The lookahead replaces a `\b` that `İ` would defeat.
        packSuffix: #"(\d{1,3})\s*['’]?\s*[Ll][iıuüİIUÜ](?!\p{L})"#,
        detailBelongsTo: .next,
        fold: { value in
            String(value.map { turkishFolds[$0] ?? $0 }).lowercased()
        }
    )
}
