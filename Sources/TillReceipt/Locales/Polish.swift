extension ReceiptLocale {
    private static let polishFolds: [Character: Character] = [
        "ą": "a", "Ą": "a", "ć": "c", "Ć": "c", "ę": "e", "Ę": "e", "ł": "l", "Ł": "l",
        "ń": "n", "Ń": "n", "ó": "o", "Ó": "o", "ś": "s", "Ś": "s",
        "ź": "z", "Ź": "z", "ż": "z", "Ż": "z",
    ]

    /// Polish receipts, as printed on a paragon fiskalny.
    ///
    /// Two things set them apart. VAT is a letter — `A` through `G` — with the rates it stands
    /// for listed in the footer, so the mark is kept as printed rather than invented. And `ł` has
    /// no Unicode decomposition, exactly like Turkish `ı`, so the alphabet is folded here too.
    ///
    /// Written from the documented layout rather than from photographed receipts. Treat the word
    /// lists as a starting point and widen them against real tills.
    public static let polish = ReceiptLocale(
        code: "pl",
        shopMarkers: #"\b(paragon\s*fiskalny|nip|data|godz|nr\s*wydr|kasa|kasjer|regon)\b"#,
        totalMarkers:
            #"\bsprzeda[zż]\s*opodatk|\bdo\s*zap[lł]aty|\bp[lł]atno[sś]|\b(ptu|suma|razem|reszta|got[oó]wka|karta)\b|^\s*sp\s*:"#,
        addressMarkers: #"\b(ul|al|os|pl)\.|\b(ulica|aleja|osiedle|plac|nip|regon|tel)\b|\d{2}-\d{3}|www|http"#,
        discountMarkers: #"\b(rabat|promocja|obni[zż]ka|opust|kupon|upust)"#,
        householdWords:
            #"\b(reklamowka|torba|worek|papier|recznik|chusteczk|plyn|proszek|mydlo|szampon|gabka|folia|bateri|zarowk|swiec|dlugopis|zeszyt|tasma|zabawk|pieluch|dezodorant|perfum|nawilzan)"#,
        categoryWords: [
            (.dairy, #"(mleko|serek|\bser\b|jogurt|smietan|maslo|twarog|kefir|jajk|\bjaja\b|maslank|mascarpone)"#),
            (
                .meat,
                #"(kurczak|wolowin|wieprzowin|schab|szynk|kielbas|boczek|mielon|indyk|parowk|kabanos|pasztet|poledwic|karkow|lopatk|wedlin|filet|\bdrob)"#
            ),
            (.seafood, #"(\bryba\b|ryby|losos|tunczyk|sledz|krewetk|dorsz|makrel|panga)"#),
            (.bakery, #"(chleb|bulk|bagietk|rogal|pieczywo|tost|chalk|precel)"#),
            (.grains, #"(\bryz\b|makaron|\bmaka\b|platki|kasza|otreb|owsian|musli|spaghetti)"#),
            (.legumes, #"(fasol|soczewic|ciecierzyc|\bgroch\b|bob\b)"#),
            (
                .produce,
                #"(pomidor|ogorek|cebul|czosnek|ziemniak|marchew|jablk|banan|cytryn|papryk|salat|pieczark|kapust|brokul|truskawk|winogron|gruszk|sliwk|brzoskwin|arbuz|warzyw|owoc|szpinak|burak|por\b)"#
            ),
            (
                .condiments,
                #"(olej|oliwa|\bocet\b|keczup|musztard|majonez|\bsos\b|\bsol\b|cukier|\bmiod\b|przypraw|dzem|nutella)"#
            ),
            (.beverages, #"(\bwoda\b|\bsok\b|herbat|kawa\b|napoj|piwo|wino|\bcola\b|lemoniad|nektar)"#),
            (
                .snacks,
                #"(chips|ciastk|czekolad|krakers|orzech|migdal|wafel|batonik|zelk|paluszk|popcorn|lody|cukierk|kakao|piern|krowk|galaretk|sezamk|michalk|chalwa|\bciasto\b)"#
            ),
        ],
        countWords: #"(?:^|\s)(\d{1,3})\s?(?:szt|op|x|\*)\.?(?:\s|$)|(?:^|\s)x\s?(\d{1,3})(?:\s|$)"#,
        vat: .letters("A-G"),
        detailBelongsTo: .next,
        fold: { value in
            String(value.map { polishFolds[$0] ?? $0 }).lowercased()
        }
    )
}
