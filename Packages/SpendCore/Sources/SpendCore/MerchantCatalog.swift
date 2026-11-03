import Foundation

/// A known brand and the patterns that identify it inside a normalized match key.
public struct MerchantBrand: Sendable, Hashable {
    public let name: String
    public let category: SpendCategory
    /// Normalized (lowercase, no punctuation) word sequences. A pattern matches when it
    /// appears in the match key on word boundaries.
    public let patterns: [String]

    public init(_ name: String, _ category: SpendCategory, _ patterns: [String]) {
        self.name = name
        self.category = category
        self.patterns = patterns
    }
}

/// Built-in brand directory. Extend freely — order matters only when two
/// brands share a pattern (first match wins).
public enum MerchantCatalog {
    public static let brands: [MerchantBrand] = [
        // MARK: Groceries / supermarkets
        .init("Walmart", .groceries, ["walmart", "wal mart", "wm supercenter", "walmart supercenter"]),
        .init("Kroger", .groceries, ["kroger"]),
        .init("Whole Foods", .groceries, ["whole foods", "wholefds", "wfm"]),
        .init("Trader Joe's", .groceries, ["trader joe", "trader joes"]),
        .init("Costco", .groceries, ["costco", "costco whse"]),
        .init("Sam's Club", .groceries, ["sams club", "samsclub"]),
        .init("Safeway", .groceries, ["safeway"]),
        .init("Albertsons", .groceries, ["albertsons"]),
        .init("Publix", .groceries, ["publix"]),
        .init("Aldi", .groceries, ["aldi"]),
        .init("Lidl", .groceries, ["lidl"]),
        .init("H-E-B", .groceries, ["heb", "h e b"]),
        .init("Meijer", .groceries, ["meijer"]),
        .init("Wegmans", .groceries, ["wegmans"]),
        .init("Food Lion", .groceries, ["food lion"]),
        .init("Giant", .groceries, ["giant food", "giant eagle"]),
        .init("Stop & Shop", .groceries, ["stop shop", "stop and shop"]),
        .init("Sprouts", .groceries, ["sprouts"]),
        .init("Vons", .groceries, ["vons"]),
        .init("Ralphs", .groceries, ["ralphs"]),
        .init("Food 4 Less", .groceries, ["food 4 less", "food4less"]),
        .init("WinCo", .groceries, ["winco"]),
        .init("Smart & Final", .groceries, ["smart final"]),
        .init("Stater Bros", .groceries, ["stater bros"]),
        .init("Vallarta", .groceries, ["vallarta"]),
        .init("Northgate Market", .groceries, ["northgate"]),
        .init("Cardenas", .groceries, ["cardenas"]),
        .init("El Super", .groceries, ["el super"]),
        .init("Fiesta Mart", .groceries, ["fiesta mart"]),
        .init("Tesco", .groceries, ["tesco"]),
        .init("Sainsbury's", .groceries, ["sainsburys"]),
        .init("Instacart", .groceries, ["instacart"]),

        // MARK: Fast food
        .init("McDonald's", .fastFood, ["mcdonalds", "mcdonald"]),
        .init("Burger King", .fastFood, ["burger king"]),
        .init("Wendy's", .fastFood, ["wendys"]),
        .init("Taco Bell", .fastFood, ["taco bell"]),
        .init("Chick-fil-A", .fastFood, ["chick fil a", "chickfila", "chick fila"]),
        .init("Subway", .fastFood, ["subway"]),
        .init("KFC", .fastFood, ["kfc"]),
        .init("Popeyes", .fastFood, ["popeyes"]),
        .init("Chipotle", .fastFood, ["chipotle"]),
        .init("In-N-Out", .fastFood, ["in n out", "innout"]),
        .init("Five Guys", .fastFood, ["five guys"]),
        .init("Sonic", .fastFood, ["sonic drive"]),
        .init("Jack in the Box", .fastFood, ["jack in the box"]),
        .init("Arby's", .fastFood, ["arbys"]),
        .init("Domino's", .fastFood, ["dominos"]),
        .init("Pizza Hut", .fastFood, ["pizza hut"]),
        .init("Little Caesars", .fastFood, ["little caesars"]),
        .init("Panda Express", .fastFood, ["panda express"]),
        .init("Wingstop", .fastFood, ["wingstop"]),
        .init("Raising Cane's", .fastFood, ["raising canes"]),
        .init("Whataburger", .fastFood, ["whataburger"]),
        .init("Carl's Jr.", .fastFood, ["carls jr"]),
        .init("Del Taco", .fastFood, ["del taco"]),
        .init("El Pollo Loco", .fastFood, ["el pollo loco"]),
        .init("Shake Shack", .fastFood, ["shake shack"]),
        .init("Jersey Mike's", .fastFood, ["jersey mikes"]),
        .init("Jimmy John's", .fastFood, ["jimmy johns"]),
        .init("Dairy Queen", .fastFood, ["dairy queen"]),
        .init("Culver's", .fastFood, ["culvers"]),
        .init("Panera", .fastFood, ["panera"]),

        // MARK: Coffee
        .init("Starbucks", .coffee, ["starbucks"]),
        .init("Dunkin'", .coffee, ["dunkin"]),
        .init("Dutch Bros", .coffee, ["dutch bros"]),
        .init("Peet's Coffee", .coffee, ["peets"]),
        .init("Tim Hortons", .coffee, ["tim hortons"]),
        .init("Blue Bottle", .coffee, ["blue bottle"]),

        // MARK: Restaurants / delivery
        .init("DoorDash", .restaurants, ["doordash"]),
        .init("Uber Eats", .restaurants, ["uber eats", "ubereats"]),
        .init("Grubhub", .restaurants, ["grubhub"]),
        .init("Olive Garden", .restaurants, ["olive garden"]),
        .init("Applebee's", .restaurants, ["applebees"]),
        .init("Chili's", .restaurants, ["chilis"]),
        .init("IHOP", .restaurants, ["ihop"]),
        .init("Denny's", .restaurants, ["dennys"]),
        .init("Cheesecake Factory", .restaurants, ["cheesecake factory"]),

        // MARK: Gas
        .init("Shell", .gas, ["shell oil", "shell service", "shell"]),
        .init("Chevron", .gas, ["chevron"]),
        .init("Exxon", .gas, ["exxon", "exxonmobil"]),
        .init("Mobil", .gas, ["mobil"]),
        .init("BP", .gas, ["bp"]),
        .init("Arco", .gas, ["arco"]),
        .init("Valero", .gas, ["valero"]),
        .init("76", .gas, ["76"]),
        .init("Circle K", .gas, ["circle k"]),
        .init("Speedway", .gas, ["speedway"]),
        .init("Wawa", .gas, ["wawa"]),
        .init("QuikTrip", .gas, ["quiktrip", "qt"]),
        .init("Sheetz", .gas, ["sheetz"]),
        .init("Buc-ee's", .gas, ["bucees", "buc ees"]),

        // MARK: Transport
        .init("Uber", .transport, ["uber trip", "uber"]),
        .init("Lyft", .transport, ["lyft"]),
        .init("Tesla Supercharger", .transport, ["tesla supercharger"]),
        .init("Metro / Transit", .transport, ["mta", "bart", "clipper", "metro transit", "ventra"]),

        // MARK: Online shopping
        .init("Amazon", .onlineShopping, ["amazon", "amzn", "amzn mktp", "amazon mktplace"]),
        .init("eBay", .onlineShopping, ["ebay"]),
        .init("Etsy", .onlineShopping, ["etsy"]),
        .init("Shein", .onlineShopping, ["shein"]),
        .init("Temu", .onlineShopping, ["temu"]),

        // MARK: Shopping
        .init("Target", .shopping, ["target"]),
        .init("Best Buy", .shopping, ["best buy", "bestbuy"]),
        .init("Home Depot", .shopping, ["home depot"]),
        .init("Lowe's", .shopping, ["lowes"]),
        .init("IKEA", .shopping, ["ikea"]),
        .init("Apple Store", .shopping, ["apple store"]),
        .init("Nike", .shopping, ["nike"]),
        .init("TJ Maxx", .shopping, ["tj maxx", "tjmaxx"]),
        .init("Ross", .shopping, ["ross stores"]),
        .init("Marshalls", .shopping, ["marshalls"]),
        .init("Dollar Tree", .shopping, ["dollar tree"]),
        .init("Dollar General", .shopping, ["dollar general"]),
        .init("Macy's", .shopping, ["macys"]),

        // MARK: Subscriptions
        .init("Netflix", .subscriptions, ["netflix"]),
        .init("Spotify", .subscriptions, ["spotify"]),
        .init("Apple Services", .subscriptions, ["apple com bill", "apple com", "itunes"]),
        .init("Disney+", .subscriptions, ["disney plus", "disneyplus"]),
        .init("Hulu", .subscriptions, ["hulu"]),
        .init("YouTube Premium", .subscriptions, ["youtube premium", "google youtube"]),
        .init("Max", .subscriptions, ["hbo max", "max com"]),
        .init("Amazon Prime", .subscriptions, ["prime video", "amazon prime"]),
        .init("Xbox", .subscriptions, ["xbox"]),
        .init("PlayStation", .subscriptions, ["playstation"]),
        .init("ChatGPT / OpenAI", .subscriptions, ["openai"]),
        .init("Claude / Anthropic", .subscriptions, ["anthropic"]),

        // MARK: Entertainment
        .init("AMC Theatres", .entertainment, ["amc"]),
        .init("Regal", .entertainment, ["regal"]),
        .init("Ticketmaster", .entertainment, ["ticketmaster"]),
        .init("Steam", .entertainment, ["steam"]),

        // MARK: Health
        .init("CVS", .health, ["cvs"]),
        .init("Walgreens", .health, ["walgreens"]),
        .init("Rite Aid", .health, ["rite aid"]),

        // MARK: Utilities / telecom
        .init("Verizon", .utilities, ["verizon"]),
        .init("AT&T", .utilities, ["at t", "att"]),
        .init("T-Mobile", .utilities, ["t mobile", "tmobile"]),
        .init("Comcast Xfinity", .utilities, ["comcast", "xfinity"]),
        .init("Spectrum", .utilities, ["spectrum"]),

        // MARK: Travel
        .init("Delta", .travel, ["delta air"]),
        .init("United", .travel, ["united airlines"]),
        .init("American Airlines", .travel, ["american airlines", "american air"]),
        .init("Southwest", .travel, ["southwest"]),
        .init("Airbnb", .travel, ["airbnb"]),
        .init("Marriott", .travel, ["marriott"]),
        .init("Hilton", .travel, ["hilton"]),
        .init("Expedia", .travel, ["expedia"]),
    ]

    /// Generic words that hint at a category when no brand matched.
    public static let keywordHints: [(keyword: String, category: SpendCategory)] = [
        ("supermarket", .groceries), ("grocery", .groceries), ("groceries", .groceries),
        ("market", .groceries), ("mercado", .groceries), ("carniceria", .groceries),
        ("foods", .groceries), ("produce", .groceries),
        ("burger", .fastFood), ("taco", .fastFood), ("taqueria", .fastFood),
        ("pizza", .fastFood), ("wings", .fastFood), ("drive thru", .fastFood),
        ("coffee", .coffee), ("cafe", .coffee), ("espresso", .coffee), ("boba", .coffee),
        ("restaurant", .restaurants), ("grill", .restaurants), ("kitchen", .restaurants),
        ("bistro", .restaurants), ("sushi", .restaurants), ("bar", .restaurants),
        ("gas", .gas), ("fuel", .gas), ("petrol", .gas),
        ("parking", .transport), ("taxi", .transport), ("transit", .transport), ("toll", .transport),
        ("pharmacy", .health), ("clinic", .health), ("dental", .health), ("medical", .health),
        ("salon", .personalCare), ("barber", .personalCare), ("spa", .personalCare), ("nails", .personalCare),
        ("cinema", .entertainment), ("theatre", .entertainment), ("theater", .entertainment),
        ("hotel", .travel), ("airline", .travel), ("airlines", .travel),
        ("electric", .utilities), ("water", .utilities), ("wireless", .utilities),
    ]
}
