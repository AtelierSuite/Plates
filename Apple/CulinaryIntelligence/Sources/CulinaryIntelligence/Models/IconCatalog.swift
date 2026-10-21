import Foundation

/// The two halves the ingredient catalog is picked in: what is bought for the week, and what
/// sits on the shelf between recipes. Each half has a picker of its own.
public nonisolated enum IngredientShelf: String, CaseIterable, Identifiable, Sendable {
    case fresh, pantry

    public var id: String { rawValue }

    /// The browsing groups on this shelf, in the order the picker shows them.
    public var categories: [IngredientCategory] {
        switch self {
        case .fresh: [.vegetables, .fruits, .meat, .seafood, .dairy, .grains]
        case .pantry: [.seasonings, .sauces, .baking, .preserved]
        }
    }
}

/// The groups the ingredient catalog is browsed in. Every ingredient icon sits in exactly one,
/// and the flat list `IconCatalog.ingredients` is built from them.
public nonisolated enum IngredientCategory: String, CaseIterable, Identifiable, Sendable {
    case vegetables, fruits, meat, seafood, dairy, grains, seasonings, sauces, baking, preserved

    public var id: String { rawValue }

    /// The shelf this group is picked from.
    public var shelf: IngredientShelf {
        IngredientShelf.allCases.first { $0.categories.contains(self) } ?? .fresh
    }

    /// The ingredient assets in this group. The picker shows them alphabetically by the name the
    /// reader sees.
    public var icons: [String] {
        switch self {
        case .vegetables:
            [
                "artichoke",
                "arugula",
                "asparagus",
                "bamboo-shoots",
                "bean-sprouts",
                "beetroot",
                "bell-pepper",
                "bitter-melon",
                "bok-choy",
                "broccoli",
                "brussels-sprouts",
                "burdock",
                "butternut-squash",
                "cabbage",
                "carrot",
                "cassava",
                "cauliflower",
                "celeriac",
                "celery",
                "cherry-tomato",
                "chili",
                "chives",
                "corn",
                "cucumber",
                "daikon",
                "edamame",
                "eggplant",
                "enoki",
                "fava-beans",
                "fennel",
                "gai-lan",
                "garlic",
                "ginger",
                "green-beans",
                "jalapeno",
                "kabocha",
                "kaiware",
                "kale",
                "kimchi",
                "king-oyster",
                "komatsuna",
                "leek",
                "lettuce",
                "lotus-root",
                "maitake",
                "mitsuba",
                "mizuna",
                "mushroom",
                "myoga",
                "nameko",
                "nanohana",
                "napa-cabbage",
                "nira",
                "okra",
                "onion",
                "parsnip",
                "pea-shoots",
                "peas",
                "perilla-leaves",
                "poblano",
                "potato",
                "pumpkin",
                "radicchio",
                "radish",
                "red-onion",
                "shallot",
                "shiitake",
                "shimeji",
                "shishito",
                "shiso",
                "shungiku",
                "snow-peas",
                "spinach",
                "spring-onion",
                "sweet-potato",
                "swiss-chard",
                "taro",
                "tomatillo",
                "tomato",
                "turnip",
                "water-chestnut",
                "watercress",
                "yam",
                "zucchini",
            ]
        case .fruits:
            [
                "apple",
                "apricot",
                "avocado",
                "banana",
                "blackberry",
                "blueberry",
                "cherry",
                "coconut",
                "cranberry",
                "dates",
                "dragon-fruit",
                "fig",
                "grape",
                "grapefruit",
                "guava",
                "jackfruit",
                "kiwi",
                "kumquat",
                "lemon",
                "lime",
                "lychee",
                "mandarin",
                "mango",
                "melon",
                "nashi-pear",
                "orange",
                "papaya",
                "passion-fruit",
                "peach",
                "pear",
                "persimmon",
                "pineapple",
                "plantain",
                "plum",
                "pomegranate",
                "raspberry",
                "rhubarb",
                "strawberry",
                "sudachi",
                "watermelon",
                "yuzu",
            ]
        case .meat:
            [
                "bacon",
                "beef",
                "chicken",
                "chicken-thigh",
                "chicken-wings",
                "chorizo",
                "corned-beef",
                "duck",
                "guanciale",
                "ham",
                "lamb",
                "lap-cheong",
                "liver",
                "luncheon-meat",
                "minced-meat",
                "pancetta",
                "pork",
                "pork-belly",
                "prosciutto",
                "salami",
                "sausage",
                "spare-ribs",
                "steak",
                "turkey",
                "veal",
            ]
        case .seafood:
            [
                "abalone",
                "anchovies",
                "ayu",
                "bonito",
                "bonito-fillet",
                "chikuwa",
                "clams",
                "cod",
                "cod-fillet",
                "crab",
                "crab-sticks",
                "dried-scallops",
                "dried-shrimp",
                "eel",
                "fish",
                "flounder",
                "flounder-fillet",
                "grilled-eel",
                "herring",
                "hokke",
                "horse-mackerel",
                "lobster",
                "mackerel",
                "mackerel-fillet",
                "mentaiko",
                "mussels",
                "octopus",
                "oyster",
                "salmon",
                "salmon-fillet",
                "salmon-roe",
                "sardines",
                "saury",
                "scallops",
                "sea-bass",
                "sea-bass-fillet",
                "sea-bream",
                "sea-bream-fillet",
                "sea-urchin",
                "seafood",
                "shirasu",
                "shishamo",
                "shrimp",
                "smoked-salmon",
                "squid",
                "swordfish",
                "swordfish-steak",
                "trout",
                "trout-fillet",
                "tuna",
                "tuna-steak",
                "yellowtail",
                "yellowtail-fillet",
            ]
        case .dairy:
            [
                "blue-cheese",
                "brie",
                "burrata",
                "butter",
                "buttermilk",
                "cheddar",
                "cheese",
                "condensed-milk",
                "cottage-cheese",
                "cream",
                "cream-cheese",
                "creme-fraiche",
                "egg",
                "evaporated-milk",
                "feta",
                "ghee",
                "goat-cheese",
                "gouda",
                "gruyere",
                "halloumi",
                "kefir",
                "mascarpone",
                "milk",
                "mozzarella",
                "paneer",
                "parmesan",
                "pecorino",
                "queso-fresco",
                "ricotta",
                "sour-cream",
                "yogurt",
            ]
        case .grains:
            [
                "arborio-rice",
                "baguette",
                "barley",
                "bread",
                "breadcrumbs",
                "bulgur",
                "buns",
                "couscous",
                "egg-noodles",
                "fettuccine",
                "fusilli",
                "glutinous-rice",
                "gnocchi",
                "gyoza-wrappers",
                "harusame",
                "lasagna",
                "macaroni",
                "mochi",
                "naan",
                "noodles",
                "oats",
                "orzo",
                "panko",
                "pasta",
                "penne",
                "pita",
                "polenta",
                "quinoa",
                "ramen",
                "ravioli",
                "rice",
                "rice-noodles",
                "rice-paper",
                "rigatoni",
                "soba",
                "somen",
                "spaghetti",
                "tortilla",
                "tteok",
                "udon",
                "wonton-wrappers",
            ]
        case .seasonings:
            [
                "allspice",
                "asafoetida",
                "basil",
                "bay-leaf",
                "caraway",
                "cardamom",
                "cayenne",
                "chili-flakes",
                "chili-powder",
                "cinnamon",
                "cloves",
                "coriander",
                "cumin",
                "curry-leaves",
                "curry-powder",
                "dill",
                "fennel-seeds",
                "fenugreek",
                "five-spice",
                "furikake",
                "galangal",
                "garam-masala",
                "garlic-powder",
                "gochugaru",
                "horseradish",
                "juniper",
                "kaffir-lime-leaves",
                "lemongrass",
                "mint",
                "msg",
                "mustard-seeds",
                "nutmeg",
                "onion-powder",
                "oregano",
                "paprika",
                "parsley",
                "pepper",
                "rosemary",
                "saffron",
                "sage",
                "salt",
                "sansho",
                "sesame-seeds",
                "shichimi",
                "sichuan-peppercorns",
                "smoked-paprika",
                "star-anise",
                "sumac",
                "tarragon",
                "thai-basil",
                "thyme",
                "turmeric",
                "wasabi",
                "yuzu-kosho",
                "zaatar",
            ]
        case .sauces:
            [
                // Italian
                "alfredo-sauce",
                "arrabbiata-sauce",
                "balsamic-vinegar",
                "bolognese-sauce",
                "carbonara-sauce",
                "marinara-sauce",
                "olive-oil",
                "pesto",
                "puttanesca-sauce",
                "red-wine",
                "vodka-sauce",
                "white-wine",
                // Chinese
                "black-vinegar",
                "char-siu-sauce",
                "chili-oil",
                "dark-soy-sauce",
                "doubanjiang",
                "douchi",
                "hoisin",
                "oyster-sauce",
                "plum-sauce",
                "sesame-oil",
                "shacha-sauce",
                "shaoxing-wine",
                "tianmianjiang",
                "xo-sauce",
                // Japanese
                "dashi",
                "mentaiko-pasta-sauce",
                "mentsuyu",
                "mirin",
                "miso",
                "okonomiyaki-sauce",
                "ponzu",
                "rice-vinegar",
                "sake",
                "sesame-dressing",
                "shio-koji",
                "shiro-dashi",
                "soy-sauce",
                "tarako-pasta-sauce",
                "teriyaki-sauce",
                "tonkatsu-sauce",
                "yakiniku-sauce",
                "yakisoba-sauce",
                // Korean
                "doenjang",
                "gochujang",
                // Southeast Asian
                "coconut-oil",
                "fish-sauce",
                "kecap-manis",
                "sambal",
                "shrimp-paste",
                "sriracha",
                "sweet-chili-sauce",
                "tamarind",
                "thai-curry-paste",
                // Everything else
                "apple-cider-vinegar",
                "bbq-sauce",
                "beer",
                "brandy",
                "chipotle-in-adobo",
                "harissa",
                "honey",
                "hot-sauce",
                "ketchup",
                "maple-syrup",
                "mayonnaise",
                "mustard",
                "oil",
                "pomegranate-molasses",
                "rum",
                "salsa",
                "soy-milk",
                "tahini",
                "vinegar",
                "water",
                "worcestershire",
            ]
        case .baking:
            [
                "agar",
                "almond-flour",
                "anko",
                "baking-powder",
                "baking-soda",
                "bread-flour",
                "brown-sugar",
                "cake-flour",
                "chocolate",
                "cocoa-powder",
                "coconut-flakes",
                "cornmeal",
                "cornstarch",
                "filo-pastry",
                "flour",
                "gelatin",
                "golden-syrup",
                "icing-sugar",
                "jam",
                "kinako",
                "masa-harina",
                "molasses",
                "palm-sugar",
                "peanut-butter",
                "puff-pastry",
                "raisins",
                "rice-flour",
                "shiratamako",
                "shortcrust-pastry",
                "sugar",
                "vanilla",
                "yeast",
            ]
        case .preserved:
            [
                "aburaage",
                "almonds",
                "aonori",
                "atsuage",
                "azuki",
                "beans",
                "black-beans",
                "bouillon",
                "canned-tomatoes",
                "canned-tuna",
                "capers",
                "cashews",
                "chia-seeds",
                "chickpeas",
                "coconut-milk",
                "curry-roux",
                "dried-shiitake",
                "ganmodoki",
                "hazelnuts",
                "hijiki",
                "kamaboko",
                "katsuobushi",
                "kidney-beans",
                "kikurage",
                "kiriboshi-daikon",
                "kombu",
                "konnyaku",
                "koya-dofu",
                "lentils",
                "matcha",
                "menma",
                "natto",
                "nori",
                "nuts",
                "okara",
                "olives",
                "passata",
                "peanuts",
                "pecans",
                "pickled-ginger",
                "pickles",
                "pine-nuts",
                "pistachios",
                "pumpkin-seeds",
                "rakkyo",
                "sake-kasu",
                "sauerkraut",
                "shirataki",
                "soybeans",
                "sun-dried-tomatoes",
                "sunflower-seeds",
                "takuan",
                "tenkasu",
                "tofu",
                "tomato-paste",
                "umeboshi",
                "wakame",
                "walnuts",
                "wheat-gluten",
                "white-beans",
                "yuba",
                "zha-cai",
            ]
        }
    }
}

/// The groups the tool catalog is browsed in. Every tool icon sits in exactly one, and the
/// flat list `IconCatalog.tools` is built from them.
public nonisolated enum ToolCategory: String, CaseIterable, Identifiable, Sendable {
    case utensils, stovetop, other

    public var id: String { rawValue }

    /// The tool assets in this group. The picker shows them alphabetically by the name the
    /// reader sees.
    public var icons: [String] {
        switch self {
        case .utensils:
            [
                "bench-scraper",
                "bowl",
                "brush",
                "butter-knife",
                "can-opener",
                "chopsticks",
                "colander",
                "cookie-cutter",
                "cutting-board",
                "fork",
                "funnel",
                "garlic-press",
                "grater",
                "kitchen-scale",
                "kitchen-twine",
                "knife",
                "ladle",
                "makisu",
                "mandoline",
                "masher",
                "measuring-cup",
                "measuring-spoons",
                "meat-mallet",
                "mortar-pestle",
                "otoshibuta",
                "peeler",
                "piping-bag",
                "pizza-cutter",
                "plate",
                "potato-ricer",
                "rolling-pin",
                "salad-spinner",
                "scissors",
                "shamoji",
                "sieve",
                "skewer",
                "skimmer",
                "slotted-spoon",
                "spatula",
                "spider",
                "spoon",
                "tongs",
                "whisk",
                "wooden-spoon",
            ]
        case .stovetop:
            [
                "air-fryer",
                "blender",
                "cast-iron-skillet",
                "deep-fryer",
                "donabe",
                "dutch-oven",
                "fish-grill",
                "food-processor",
                "grill",
                "hand-mixer",
                "immersion-blender",
                "kettle",
                "lid",
                "microwave",
                "oven",
                "pan",
                "pot",
                "pressure-cooker",
                "rice-cooker",
                "saucepan",
                "slow-cooker",
                "stand-mixer",
                "steamer",
                "takoyaki-pan",
                "tamagoyaki-pan",
                "toaster",
                "wok",
            ]
        case .other:
            [
                "baking-sheet",
                "cake-tin",
                "foil",
                "loaf-tin",
                "muffin-tin",
                "oven-mitt",
                "paper-towel",
                "parchment-paper",
                "pie-dish",
                "plastic-wrap",
                "roasting-pan",
                "storage-container",
                "thermometer",
                "timer",
                "wire-rack",
                "zip-bag",
            ]
        }
    }
}

/// The SVG icon sets shipped in the asset catalog, mirroring the folders in the recipe site's `img` directory.
public nonisolated enum IconCatalog {
    /// Asset names for every icon in `img/ingredients`, gathered from the browsing groups.
    public static let ingredients: [String] = IngredientCategory.allCases.flatMap(\.icons).sorted()

    /// Asset names for every icon in `img/tools`, gathered from the browsing groups.
    public static let tools: [String] = ToolCategory.allCases.flatMap(\.icons).sorted()

    /// Other words cooks use for an ingredient, mapped onto the asset that covers it.
    /// Looked up through `normalized`, so plurals and spacing do not need their own entries.
    private static let aliases: [String: String] = [
        "acv": "apple-cider-vinegar",
        "aduki beans": "azuki",
        "adzuki": "azuki",
        "adzuki beans": "azuki",
        "agar agar": "agar",
        "agar flakes": "agar",
        "agar powder": "agar",
        "agedama": "tenkasu",
        "ahi": "tuna-steak",
        "aji": "horse-mackerel",
        "ajinomoto": "msg",
        "alfredo": "alfredo-sauce",
        "amberjack": "yellowtail",
        "ancho": "poblano",
        "ancho chile": "poblano",
        "angel hair": "spaghetti",
        "anise seed": "fennel-seeds",
        "aniseed": "fennel-seeds",
        "anzu": "apricot",
        "apple vinegar": "apple-cider-vinegar",
        "arctic char": "trout",
        "arrabbiata": "arrabbiata-sauce",
        "arrabiata sauce": "arrabbiata-sauce",
        "asian pear": "nashi-pear",
        "atka mackerel": "hokke",
        "atsu age": "atsuage",
        "aubergine": "eggplant",
        "awabi": "abalone",
        "azuki paste": "anko",
        "baby back ribs": "spare-ribs",
        "baby sardines": "shirasu",
        "bacalao": "cod-fillet",
        "baguettes": "baguette",
        "bai makrut": "kaffir-lime-leaves",
        "banh trang": "rice-paper",
        "barbecue": "bbq-sauce",
        "barbeque sauce": "bbq-sauce",
        "barramundi": "sea-bass",
        "bbq tare": "yakiniku-sauce",
        "bean curd skin": "yuba",
        "bean paste": "anko",
        "bean thread noodles": "harusame",
        "beef broth": "bouillon",
        "beef liver": "liver",
        "beef steak": "steak",
        "beet": "beetroot",
        "belacan": "shrimp-paste",
        "belgian endive": "radicchio",
        "beni shoga": "pickled-ginger",
        "bicarbonate of soda": "baking-soda",
        "bitter gourd": "bitter-melon",
        "black bean sauce": "douchi",
        "black bean paste": "douchi",
        "black fungus": "kikurage",
        "blackberries": "blackberry",
        "bolognese": "bolognese-sauce",
        "bonito flakes": "katsuobushi",
        "bonito tataki": "bonito-fillet",
        "boysenberries": "blackberry",
        "branzino": "sea-bass",
        "branzino fillet": "sea-bass-fillet",
        "bread rolls": "buns",
        "brioche bun": "buns",
        "broad beans": "fava-beans",
        "broad bean paste": "doubanjiang",
        "broth": "bouillon",
        "brown butter": "ghee",
        "brown mustard seeds": "mustard-seeds",
        "bucatini": "spaghetti",
        "bulghur": "bulgur",
        "bulgogi sauce": "yakiniku-sauce",
        "burger buns": "buns",
        "buri": "yellowtail",
        "buri fillet": "yellowtail-fillet",
        "burrata cheese": "burrata",
        "buta bara": "pork-belly",
        "butter beans": "white-beans",
        "butternut": "butternut-squash",
        "butternut pumpkin": "butternut-squash",
        "calamansi": "sudachi",
        "calamondin": "sudachi",
        "calf liver": "liver",
        "camembert": "brie",
        "canned ham": "luncheon-meat",
        "cannellini": "white-beans",
        "cannellini beans": "white-beans",
        "capelin": "shishamo",
        "capellini": "spaghetti",
        "capsicum": "bell-pepper",
        "caraway seeds": "caraway",
        "carbonara": "carbonara-sauce",
        "cashew nuts": "cashews",
        "cayenne pepper": "cayenne",
        "celery root": "celeriac",
        "cellophane noodles": "harusame",
        "chaat masala": "garam-masala",
        "chard": "swiss-chard",
        "cherry tomatoes": "cherry-tomato",
        "chevre": "goat-cheese",
        "chicken broth": "bouillon",
        "chicken liver": "liver",
        "chicken stock": "bouillon",
        "chicken thighs": "chicken-thigh",
        "chicken wing": "chicken-wings",
        "chicory": "radicchio",
        "chili paste": "sambal",
        "chili bean paste": "doubanjiang",
        "chilli": "chili",
        "chilli paste": "sambal",
        "chilli bean paste": "doubanjiang",
        "chilli powder": "chili-powder",
        "chinese black beans": "douchi",
        "chinese black vinegar": "black-vinegar",
        "chinese broccoli": "gai-lan",
        "chinese cabbage": "napa-cabbage",
        "chinese chives": "nira",
        "chinese egg noodles": "egg-noodles",
        "chinese kale": "gai-lan",
        "chinese leek": "nira",
        "chinese rice wine": "shaoxing-wine",
        "chinese sausage": "lap-cheong",
        "chinese water chestnut": "water-chestnut",
        "chinkiang vinegar": "black-vinegar",
        "chipotle": "chipotle-in-adobo",
        "chipotle peppers": "chipotle-in-adobo",
        "chipotles in adobo": "chipotle-in-adobo",
        "chirimen jako": "shirasu",
        "chow mein noodles": "egg-noodles",
        "chrysanthemum greens": "shungiku",
        "chrysanthemum leaves": "shungiku",
        "chukamen": "egg-noodles",
        "chèvre": "goat-cheese",
        "cider vinegar": "apple-cider-vinegar",
        "cilantro": "coriander",
        "citronella": "lemongrass",
        "clarified butter": "ghee",
        "clementine": "mandarin",
        "clotted cream": "creme-fraiche",
        "cloud ear": "kikurage",
        "coconut chips": "coconut-flakes",
        "coconut shreds": "coconut-flakes",
        "coconut sugar": "palm-sugar",
        "cod loin": "cod-fillet",
        "cod roe": "mentaiko",
        "cod steak": "cod-fillet",
        "cognac": "brandy",
        "comte": "gruyere",
        "comté": "gruyere",
        "conchiglie": "pasta",
        "confectioners sugar": "icing-sugar",
        "conpoy": "dried-scallops",
        "corn flour": "cornstarch",
        "corn meal": "cornmeal",
        "corn syrup": "golden-syrup",
        "corned beef hash": "corned-beef",
        "cornichons": "pickles",
        "courgette": "zucchini",
        "crabsticks": "crab-sticks",
        "cracked wheat": "bulgur",
        "craisins": "cranberry",
        "cranberries": "cranberry",
        "crawfish": "lobster",
        "crayfish": "lobster",
        "croissant dough": "puff-pastry",
        "crown daisy": "shungiku",
        "crushed red pepper": "chili-flakes",
        "crushed red pepper flakes": "chili-flakes",
        "cultured buttermilk": "buttermilk",
        "cumquat": "kumquat",
        "currants": "raisins",
        "curry leaf": "curry-leaves",
        "curry spice mix": "garam-masala",
        "daikon sprouts": "kaiware",
        "daizu": "soybeans",
        "dangmyeon": "harusame",
        "danish blue": "blue-cheese",
        "danmuji": "takuan",
        "dark beer": "beer",
        "dark rum": "rum",
        "deep fried tofu": "atsuage",
        "desiccated coconut": "coconut-flakes",
        "devil's tongue": "konnyaku",
        "dill pickles": "pickles",
        "dinner rolls": "buns",
        "dorade": "sea-bream",
        "dou miao": "pea-shoots",
        "double cream": "cream",
        "doumiao": "pea-shoots",
        "dragonfruit": "dragon-fruit",
        "dried apricots": "apricot",
        "dried cranberries": "cranberry",
        "dried fruit": "raisins",
        "dried onion": "onion-powder",
        "dried pasta": "pasta",
        "dried prawns": "dried-shrimp",
        "dried radish strips": "kiriboshi-daikon",
        "dried scallop": "dried-scallops",
        "dried shredded daikon": "kiriboshi-daikon",
        "dried tofu": "koya-dofu",
        "drumettes": "chicken-wings",
        "dumpling skins": "gyoza-wrappers",
        "dumpling wrappers": "gyoza-wrappers",
        "edam": "gouda",
        "eddoe": "taro",
        "egg roll wrappers": "wonton-wrappers",
        "egoma": "perilla-leaves",
        "emmental": "gruyere",
        "endive": "radicchio",
        "eringi": "king-oyster",
        "estragon": "tarragon",
        "farfalle": "pasta",
        "fava": "fava-beans",
        "fermented bamboo shoots": "menma",
        "fermented black bean paste": "douchi",
        "filberts": "hazelnuts",
        "filo": "filo-pastry",
        "fish cake": "kamaboko",
        "fish cake tube": "chikuwa",
        "fish roe": "salmon-roe",
        "flaked almonds": "almonds",
        "flatfish": "flounder",
        "fluke": "flounder",
        "freeze dried tofu": "koya-dofu",
        "french bread": "baguette",
        "french tarragon": "tarragon",
        "fresh coconut": "coconut",
        "fresh egg noodles": "egg-noodles",
        "fresh fig": "fig",
        "fresh goat cheese": "goat-cheese",
        "fresh shiitake": "shiitake",
        "fried tofu": "aburaage",
        "fu": "wheat-gluten",
        "fuzhu": "yuba",
        "galbi sauce": "yakiniku-sauce",
        "ganmo": "ganmodoki",
        "gapow": "thai-basil",
        "garaetteok": "tteok",
        "gari": "pickled-ginger",
        "garland chrysanthemum": "shungiku",
        "garlic granules": "garlic-powder",
        "garlic salt": "garlic-powder",
        "gherkins": "pickles",
        "glutinous rice flour": "shiratamako",
        "goat's cheese": "goat-cheese",
        "gobo": "burdock",
        "golden raisins": "raisins",
        "goma dare": "sesame-dressing",
        "goma dressing": "sesame-dressing",
        "gorgonzola": "blue-cheese",
        "goya": "bitter-melon",
        "granulated garlic": "garlic-powder",
        "grape tomato": "cherry-tomato",
        "grape tomatoes": "cherry-tomato",
        "gravlax": "smoked-salmon",
        "great northern beans": "white-beans",
        "green banana": "plantain",
        "green curry paste": "thai-curry-paste",
        "green onion": "spring-onion",
        "green papaya": "papaya",
        "grilling cheese": "halloumi",
        "grits": "cornmeal",
        "ground beef": "minced-meat",
        "ground cayenne": "cayenne",
        "ground pork": "minced-meat",
        "ground turkey": "turkey",
        "groundnuts": "peanuts",
        "guayaba": "guava",
        "gyoza skins": "gyoza-wrappers",
        "hakurikiko": "cake-flour",
        "hakusai": "napa-cabbage",
        "halibut": "flounder",
        "halibut fillet": "flounder-fillet",
        "halibut steak": "flounder-fillet",
        "haloumi": "halloumi",
        "hamachi": "yellowtail",
        "hamachi sashimi": "yellowtail-fillet",
        "hamburger buns": "buns",
        "haricot beans": "white-beans",
        "hazelnut": "hazelnuts",
        "heavy cream": "cream",
        "hen of the woods": "maitake",
        "high gluten flour": "bread-flour",
        "hing": "asafoetida",
        "hirame": "flounder",
        "hiyamugi": "somen",
        "holy basil": "thai-basil",
        "honewort": "mitsuba",
        "horapa": "thai-basil",
        "hoshi ebi": "dried-shrimp",
        "hotate": "scallops",
        "hua jiao": "sichuan-peppercorns",
        "huajiao": "sichuan-peppercorns",
        "ikura": "salmon-roe",
        "imitation crab": "crab-sticks",
        "indian cheese": "paneer",
        "indonesian sweet soy sauce": "kecap-manis",
        "inverted sugar syrup": "golden-syrup",
        "ise ebi": "lobster",
        "iwashi": "sardines",
        "jack mackerel": "horse-mackerel",
        "jaggery": "palm-sugar",
        "jalapeno pepper": "jalapeno",
        "jalapeño pepper": "jalapeno",
        "japanese amberjack": "yellowtail",
        "japanese bbq sauce": "yakiniku-sauce",
        "japanese ginger": "myoga",
        "japanese mustard greens": "mizuna",
        "japanese mustard spinach": "komatsuna",
        "japanese parsley": "mitsuba",
        "japanese pear": "nashi-pear",
        "japanese pumpkin": "kabocha",
        "jarlsberg": "gruyere",
        "jiaozi wrappers": "gyoza-wrappers",
        "joshinko": "rice-flour",
        "kabayaki": "grilled-eel",
        "kabocha squash": "kabocha",
        "kabosu": "sudachi",
        "kaffir lime leaf": "kaffir-lime-leaves",
        "kai lan": "gai-lan",
        "kailan": "gai-lan",
        "kaiware daikon": "kaiware",
        "kajiki": "swordfish",
        "kani": "crab",
        "kanikama": "crab-sticks",
        "kanten": "agar",
        "kapi": "shrimp-paste",
        "kaprao": "thai-basil",
        "karei": "flounder",
        "karela": "bitter-melon",
        "katakuriko": "cornstarch",
        "katsuo": "bonito",
        "katsuo tataki": "bonito-fillet",
        "ketjap manis": "kecap-manis",
        "kinkan": "kumquat",
        "kipper": "herring",
        "kiriboshi": "kiriboshi-daikon",
        "kkaennip": "perilla-leaves",
        "komeko": "rice-flour",
        "konjac": "konnyaku",
        "konnyaku block": "konnyaku",
        "korean bean paste": "doenjang",
        "korean chili flakes": "gochugaru",
        "korean chili powder": "gochugaru",
        "korean chilli powder": "gochugaru",
        "korean pear": "nashi-pear",
        "korean red pepper flakes": "gochugaru",
        "korean rice cakes": "tteok",
        "korean soybean paste": "doenjang",
        "koshian": "anko",
        "koya tofu": "koya-dofu",
        "koyadofu": "koya-dofu",
        "kurumabu": "wheat-gluten",
        "kyorikiko": "bread-flour",
        "lager": "beer",
        "langoustine": "lobster",
        "lap cheung": "lap-cheong",
        "lap chong": "lap-cheong",
        "lap xuong": "lap-cheong",
        "lemon grass": "lemongrass",
        "lichee": "lychee",
        "light corn syrup": "golden-syrup",
        "light treacle": "golden-syrup",
        "lilikoi": "passion-fruit",
        "lime leaves": "kaffir-lime-leaves",
        "linguine": "spaghetti",
        "litchi": "lychee",
        "lo mein": "egg-noodles",
        "long pasta": "pasta",
        "longan": "lychee",
        "low gluten flour": "cake-flour",
        "lox": "smoked-salmon",
        "mackerel pike": "saury",
        "madai": "sea-bream",
        "maguro": "tuna",
        "maguro sashimi": "tuna-steak",
        "makrut lime": "kaffir-lime-leaves",
        "mandarin orange": "mandarin",
        "mange tout": "snow-peas",
        "manioc": "cassava",
        "maracuja": "passion-fruit",
        "marcona almonds": "almonds",
        "marinara": "marinara-sauce",
        "masa": "masa-harina",
        "masala": "garam-masala",
        "masu": "trout",
        "meat sauce": "bolognese-sauce",
        "medjool": "dates",
        "medjool dates": "dates",
        "mekajiki": "swordfish",
        "mentaiko sauce": "mentaiko-pasta-sauce",
        "mentaiko spaghetti sauce": "mentaiko-pasta-sauce",
        "methi": "fenugreek",
        "mikan": "mandarin",
        "mizuame": "golden-syrup",
        "mochi rice": "glutinous-rice",
        "mochigome": "glutinous-rice",
        "mochiko": "shiratamako",
        "monosodium glutamate": "msg",
        "mung bean noodles": "harusame",
        "mustard spinach": "komatsuna",
        "myoga ginger": "myoga",
        "naan bread": "naan",
        "nagaimo": "yam",
        "nam jim kai": "sweet-chili-sauce",
        "nangka": "jackfruit",
        "nashi": "nashi-pear",
        "navy beans": "white-beans",
        "negi": "spring-onion",
        "nishin": "herring",
        "okonomi sauce": "okonomiyaki-sauce",
        "onion granules": "onion-powder",
        "onion salt": "onion-powder",
        "orecchiette": "pasta",
        "otafuku sauce": "okonomiyaki-sauce",
        "pacific saury": "saury",
        "pak choi": "bok-choy",
        "panir": "paneer",
        "pappardelle": "fettuccine",
        "parmigiano": "parmesan",
        "passionfruit": "passion-fruit",
        "pasta sauce": "marinara-sauce",
        "pasta shells": "pasta",
        "pastry": "puff-pastry",
        "pastry flour": "cake-flour",
        "paua": "abalone",
        "pawpaw": "papaya",
        "pea shoot": "pea-shoots",
        "pea sprouts": "pea-shoots",
        "pea tendrils": "pea-shoots",
        "pea tips": "pea-shoots",
        "pepitas": "pumpkin-seeds",
        "perilla": "perilla-leaves",
        "petit tomato": "cherry-tomato",
        "phyllo": "filo-pastry",
        "pickled cucumbers": "pickles",
        "pickled daikon": "takuan",
        "pickled herring": "herring",
        "pickled mustard greens": "zha-cai",
        "pickled shallots": "rakkyo",
        "pico de gallo": "salsa",
        "pie crust": "shortcrust-pastry",
        "pie dough": "shortcrust-pastry",
        "pilchards": "sardines",
        "pimenton": "smoked-paprika",
        "pimentón": "smoked-paprika",
        "pink grapefruit": "grapefruit",
        "pink sauce": "vodka-sauce",
        "pistachio nuts": "pistachios",
        "pitahaya": "dragon-fruit",
        "pitaya": "dragon-fruit",
        "plaice": "flounder",
        "pollock roe": "mentaiko",
        "pomegranate arils": "pomegranate",
        "pomegranate seeds": "pomegranate",
        "pomegranate syrup": "pomegranate-molasses",
        "pomodoro sauce": "marinara-sauce",
        "porgy": "sea-bream",
        "pork liver": "liver",
        "pork luncheon meat": "luncheon-meat",
        "pork ribs": "spare-ribs",
        "potherb mustard": "mizuna",
        "potsticker wrappers": "gyoza-wrappers",
        "powdered sugar": "icing-sugar",
        "prawn": "shrimp",
        "preserved mustard stem": "zha-cai",
        "purple onion": "red-onion",
        "puttanesca": "puttanesca-sauce",
        "queso blanco": "queso-fresco",
        "radish sprouts": "kaiware",
        "ragu": "bolognese-sauce",
        "ragù": "bolognese-sauce",
        "rainbow chard": "swiss-chard",
        "rainbow trout": "trout",
        "rambutan": "lychee",
        "rape blossoms": "nanohana",
        "raspberries": "raspberry",
        "rayu": "chili-oil",
        "red bean paste": "anko",
        "red beans": "azuki",
        "red beet": "beetroot",
        "red caviar": "salmon-roe",
        "red curry paste": "thai-curry-paste",
        "red pepper flakes": "chili-flakes",
        "red pepper powder": "cayenne",
        "red snapper": "sea-bream",
        "renkon": "lotus-root",
        "ribeye": "steak",
        "ribs": "spare-ribs",
        "rice paper wrappers": "rice-paper",
        "rice powder": "rice-flour",
        "rice vermicelli": "rice-noodles",
        "roast turkey": "turkey",
        "roasted peanuts": "peanuts",
        "roasted sesame dressing": "sesame-dressing",
        "roasted soybean flour": "kinako",
        "rock lobster": "lobster",
        "rocket": "arugula",
        "roe": "salmon-roe",
        "roquefort": "blue-cheese",
        "rotini": "fusilli",
        "saba": "mackerel",
        "saba fillet": "mackerel-fillet",
        "sake lees": "sake-kasu",
        "sakekasu": "sake-kasu",
        "sakura ebi": "dried-shrimp",
        "sakuraebi": "dried-shrimp",
        "salmon sashimi": "salmon-fillet",
        "salmon steak": "salmon-fillet",
        "salt beef": "corned-beef",
        "salt cod": "cod-fillet",
        "salt koji": "shio-koji",
        "salted black beans": "douchi",
        "sambal oelek": "sambal",
        "sambal ulek": "sambal",
        "samgyeopsal": "pork-belly",
        "sanma": "saury",
        "sashimi tuna": "tuna-steak",
        "satoimo": "taro",
        "satsuma": "mandarin",
        "scad": "horse-mackerel",
        "scallion": "spring-onion",
        "seabass": "sea-bass",
        "seabream": "sea-bream",
        "seared bonito": "bonito-fillet",
        "seasoned bamboo shoots": "menma",
        "seaweed": "nori",
        "seitan": "wheat-gluten",
        "sereh": "lemongrass",
        "sesame paste": "tahini",
        "sesame sauce": "sesame-dressing",
        "sha cha": "shacha-sauce",
        "shaoxing": "shaoxing-wine",
        "shaoxing rice wine": "shaoxing-wine",
        "shiitake mushroom": "shiitake",
        "shime saba": "mackerel-fillet",
        "shimi dofu": "koya-dofu",
        "shinachiku": "menma",
        "shiokoji": "shio-koji",
        "shirodashi": "shiro-dashi",
        "short pasta": "pasta",
        "shredded coconut": "coconut-flakes",
        "shumai wrappers": "wonton-wrappers",
        "sichuan pepper": "sichuan-peppercorns",
        "sichuan pickle": "zha-cai",
        "sichuan pickled mustard": "zha-cai",
        "silverbeet": "swiss-chard",
        "sirloin": "steak",
        "skipjack": "bonito",
        "skipjack tuna": "bonito",
        "sliced almonds": "almonds",
        "slivered almonds": "almonds",
        "smetana": "creme-fraiche",
        "smoked spanish paprika": "smoked-paprika",
        "snap peas": "snow-peas",
        "snapper": "sea-bream",
        "snapper fillet": "sea-bream-fillet",
        "snow pea shoots": "pea-shoots",
        "snow pea sprouts": "pea-shoots",
        "soft flour": "cake-flour",
        "sole": "flounder",
        "sole fillet": "flounder-fillet",
        "somen noodles": "somen",
        "soramame": "fava-beans",
        "soy flour": "kinako",
        "soy pulp": "okara",
        "soybean": "soybeans",
        "soybean flour": "kinako",
        "spaghetti sauce": "marinara-sauce",
        "spaghettini": "spaghetti",
        "spam": "luncheon-meat",
        "spanish onion": "red-onion",
        "spareribs": "spare-ribs",
        "spicy bean paste": "doubanjiang",
        "spicy cod roe": "mentaiko",
        "spiny lobster": "lobster",
        "spring roll rice paper": "rice-paper",
        "spring roll wrappers": "wonton-wrappers",
        "ssamjang": "doenjang",
        "steelhead": "trout",
        "sticky rice": "glutinous-rice",
        "sticky rice flour": "shiratamako",
        "stilton": "blue-cheese",
        "stock": "bouillon",
        "stock cube": "bouillon",
        "stout": "beer",
        "stracciatella": "burrata",
        "striploin": "steak",
        "strong flour": "bread-flour",
        "strong white flour": "bread-flour",
        "suan cai": "zha-cai",
        "sugar snap": "snow-peas",
        "sugar snap peas": "snow-peas",
        "sultanas": "raisins",
        "sumomo": "plum",
        "surimi": "crab-sticks",
        "suzuki": "sea-bass",
        "sweet bean paste": "anko",
        "sweet bean sauce": "tianmianjiang",
        "sweet chilli sauce": "sweet-chili-sauce",
        "sweet potato noodles": "harusame",
        "sweet red bean paste": "anko",
        "sweet rice": "glutinous-rice",
        "sweet rice flour": "shiratamako",
        "sweet soy sauce": "kecap-manis",
        "sweetfish": "ayu",
        "swiss cheese": "gruyere",
        "szechuan pepper": "sichuan-peppercorns",
        "szechuan peppercorns": "sichuan-peppercorns",
        "tagliatelle": "fettuccine",
        "tai": "sea-bream",
        "tai fillet": "sea-bream-fillet",
        "takenoko": "bamboo-shoots",
        "tako": "octopus",
        "takoyaki sauce": "okonomiyaki-sauce",
        "takuwan": "takuan",
        "tamarind concentrate": "tamarind",
        "tamarind paste": "tamarind",
        "tamarind pulp": "tamarind",
        "tangerine": "mandarin",
        "tarako": "mentaiko",
        "tarako sauce": "tarako-pasta-sauce",
        "tarako spaghetti sauce": "tarako-pasta-sauce",
        "taro root": "taro",
        "tart pastry": "shortcrust-pastry",
        "tebasaki": "chicken-wings",
        "tempura bits": "tenkasu",
        "tempura flakes": "tenkasu",
        "tempura scraps": "tenkasu",
        "terasi": "shrimp-paste",
        "thai sweet chili sauce": "sweet-chili-sauce",
        "thick fried tofu": "atsuage",
        "thin wheat noodles": "somen",
        "tinned tuna": "canned-tuna",
        "tobyo": "pea-shoots",
        "tofu dregs": "okara",
        "tofu skin": "yuba",
        "togarashi": "shichimi",
        "tomatillos": "tomatillo",
        "tomato pasta sauce": "marinara-sauce",
        "tomyo": "pea-shoots",
        "toumyou": "pea-shoots",
        "tsubuan": "anko",
        "tteokbokki rice cakes": "tteok",
        "tube fish cake": "chikuwa",
        "tulsi": "thai-basil",
        "tuna can": "canned-tuna",
        "tuna chunks": "canned-tuna",
        "tuna in oil": "canned-tuna",
        "tuna saku": "tuna-steak",
        "tuna sashimi": "tuna-steak",
        "turbot": "flounder",
        "turkey breast": "turkey",
        "umami seasoning": "msg",
        "unagi": "eel",
        "unagi kabayaki": "grilled-eel",
        "unagi no kabayaki": "grilled-eel",
        "uni": "sea-urchin",
        "unsalted peanuts": "peanuts",
        "veal cutlet": "veal",
        "veal escalope": "veal",
        "veal shank": "veal",
        "vegetable broth": "bouillon",
        "vegetable stock": "bouillon",
        "vermicelli": "harusame",
        "walnut halves": "walnuts",
        "wheat gluten cakes": "wheat-gluten",
        "white dashi": "shiro-dashi",
        "white kidney beans": "white-beans",
        "white radish": "daikon",
        "white rum": "rum",
        "white soy sauce": "shiro-dashi",
        "whitebait": "shirasu",
        "wonton skins": "wonton-wrappers",
        "wood ear": "kikurage",
        "wood ear mushroom": "kikurage",
        "yakifu": "wheat-gluten",
        "yakiniku tare": "yakiniku-sauce",
        "yam cake": "konnyaku",
        "yellow curry paste": "thai-curry-paste",
        "yellow mustard seeds": "mustard-seeds",
        "yellow pickled radish": "takuan",
        "yellowtail steak": "yellowtail-fillet",
        "yoghurt": "yogurt",
        "young jackfruit": "jackfruit",
        "yuca": "cassava",
        "zahtar": "zaatar",
        "zatar": "zaatar",
        "zhacai": "zha-cai",
        "ziti": "penne",
    ].reduce(into: [:]) { table, entry in table[normalized(entry.key)] = entry.value }

    /// Turns a schema icon path such as `img/ingredients/spring-onion.svg` into the catalog
    /// name `spring-onion`. Paths are kebab cased because that is how recipe files are written.
    public static func iconName(for path: String) -> String? {
        let stem = (path as NSString).lastPathComponent.replacingOccurrences(of: ".svg", with: "")
        return stem.isEmpty ? nil : stem
    }

    /// The asset catalog entry a path draws from, such as `SpringOnion`. The catalog is Pascal
    /// cased throughout, so the kebab cased name is converted on the way in.
    public static func assetName(for path: String) -> String? {
        iconName(for: path).map(pascalCased)
    }

    /// `spring-onion` written the way the asset catalog and the string catalog write it,
    /// `SpringOnion`.
    private static func pascalCased(_ name: String) -> String {
        name.split(separator: "-").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
    }

    /// The icon path a recipe file should carry for an ingredient asset.
    public static func ingredientPath(for name: String) -> String {
        "img/ingredients/\(name).svg"
    }

    /// The icon path a recipe file should carry for a tool asset.
    public static func toolPath(for name: String) -> String {
        "img/tools/\(name).svg"
    }

    /// How an asset name reads in a list, in the reader's language: `spring-onion` is "Spring
    /// onion" in English and "ねぎ" in Japanese. Every asset has a key of its own in the
    /// string catalog, and an asset with no entry falls back to its own name.
    public static func displayName(for asset: String) -> String {
        name(for: asset, String(culinary: String.LocalizationValue(nameKey(for: asset))))
    }

    /// The same name in English, whatever the reader's language, for the model that writes in
    /// English.
    static func englishName(for asset: String) -> String {
        name(for: asset, String(culinaryEnglish: String.LocalizationValue(nameKey(for: asset))))
    }

    /// A looked up name, or the asset's own name when the catalog has no entry for it.
    private static func name(for asset: String, _ localized: String) -> String {
        let key = nameKey(for: asset)
        guard localized != key else {
            let words = asset.replacingOccurrences(of: "-", with: " ")
            return words.prefix(1).uppercased() + words.dropFirst()
        }
        return localized
    }

    /// Where an asset's name is written in the string catalog, such as
    /// `Ingredient.Name.SpringOnion` or `Tool.Name.CuttingBoard`.
    private static func nameKey(for asset: String) -> String {
        let group = ingredientSet.contains(asset) ? "Ingredient.Name." : "Tool.Name."
        return group + pascalCased(asset)
    }

    /// Every asset name as a search compares it, worked out once. The reader's language is
    /// fixed for the life of the process, so nothing here is looked up twice.
    private static let searchNames: [String: String] = (ingredients + tools)
        .reduce(into: [:]) { table, asset in table[asset] = normalized(displayName(for: asset)) }

    private static let ingredientSet = Set(ingredients)

    /// The localized ingredient names, mapped back onto their assets, so a name the model
    /// wrote in the reader's language is found the same way an English one is.
    private static let localizedIngredients: [String: String] = ingredients
        .reduce(into: [:]) { table, asset in table[searchNames[asset] ?? ""] = asset }

    /// Maps a model guess back onto an icon that actually exists, falling back to a sensible default.
    public static func resolveIngredient(_ guess: String, itemName: String) -> String {
        resolve(guess, itemName: itemName, in: ingredients) ?? "salt"
    }

    /// Maps a model guess back onto a tool icon that actually exists.
    public static func resolveTool(_ guess: String, itemName: String) -> String {
        resolve(guess, itemName: itemName, in: tools) ?? "pan"
    }

    // MARK: - Searching

    /// The ingredients a cook's search text turns up, closest match first. An empty search
    /// returns the whole catalog.
    public static func ingredients(matching query: String) -> [String] {
        search(query, in: ingredients)
    }

    /// The tools a cook's search text turns up, closest match first.
    public static func tools(matching query: String) -> [String] {
        search(query, in: tools)
    }

    /// The same search, kept in the browsing groups of one shelf. Groups with nothing left in
    /// them are dropped.
    public static func categories(
        matching query: String,
        on shelf: IngredientShelf
    ) -> [(category: IngredientCategory, icons: [String])] {
        let matches = Set(ingredients(matching: query))
        return shelf.categories.compactMap { category in
            let icons = (ingredientOrder[category] ?? category.icons).filter(matches.contains)
            return icons.isEmpty ? nil : (category, icons)
        }
    }

    /// The same search across both shelves, for a picker that browses the whole ingredient
    /// catalog at once rather than one half of it.
    public static func allCategories(matching query: String) -> [(category: IngredientCategory, icons: [String])] {
        IngredientShelf.allCases.flatMap { categories(matching: query, on: $0) }
    }

    /// The shelf an ingredient asset is picked from, so a selection can be split the way the
    /// pickers are.
    public static func shelf(of asset: String) -> IngredientShelf {
        shelves[asset] ?? .fresh
    }

    private static let shelves: [String: IngredientShelf] = IngredientCategory.allCases
        .reduce(into: [:]) { table, category in
            for asset in category.icons { table[asset] = category.shelf }
        }

    /// The tools a search turns up, kept in browsing groups. Groups with nothing left in
    /// them are dropped.
    public static func toolCategories(matching query: String) -> [(category: ToolCategory, icons: [String])] {
        let matches = Set(tools(matching: query))
        return ToolCategory.allCases.compactMap { category in
            let icons = (toolOrder[category] ?? category.icons).filter(matches.contains)
            return icons.isEmpty ? nil : (category, icons)
        }
    }

    // MARK: - Ordering

    /// Each ingredient group in the order its picker shows it, worked out once.
    private static let ingredientOrder: [IngredientCategory: [String]] = IngredientCategory.allCases
        .reduce(into: [:]) { table, category in table[category] = sortedByName(category.icons) }

    /// Each tool group in the order its picker shows it, worked out once.
    private static let toolOrder: [ToolCategory: [String]] = ToolCategory.allCases
        .reduce(into: [:]) { table, category in table[category] = sortedByName(category.icons) }

    /// The language the catalog names are read in, which is not always the device's.
    private static let nameLocale = Locale(identifier: Bundle.module.preferredLocalizations.first ?? "en-US")

    /// Assets in the alphabetical order of the names the reader sees, compared the way the
    /// reader's language orders words.
    private static func sortedByName(_ assets: [String]) -> [String] {
        let keys = assets.reduce(into: [String: String]()) { table, asset in
            table[asset] = sortKey(for: displayName(for: asset))
        }
        return assets.sorted { lhs, rhs in
            let left = keys[lhs] ?? lhs
            let right = keys[rhs] ?? rhs
            return left.compare(
                right,
                options: [.caseInsensitive, .numeric, .widthInsensitive],
                range: nil,
                locale: nameLocale
            ) == .orderedAscending
        }
    }

    /// A name as it is ordered. Japanese is ordered by reading, so kanji are swapped for their
    /// hiragana and 牛乳 sits among the ぎ names rather than after every name in kana.
    private static func sortKey(for name: String) -> String {
        guard nameLocale.language.languageCode == .japanese else { return name }
        let text = name as NSString
        let tokenizer = CFStringTokenizerCreate(
            nil,
            text,
            CFRange(location: 0, length: text.length),
            kCFStringTokenizerUnitWord,
            nameLocale as CFLocale
        )
        var key = ""
        var cursor = 0
        while CFStringTokenizerAdvanceToNextToken(tokenizer) != [] {
            let range = CFStringTokenizerGetCurrentTokenRange(tokenizer)
            key += text.substring(with: NSRange(location: cursor, length: range.location - cursor))
            let token = text.substring(with: NSRange(location: range.location, length: range.length))
            if token.unicodeScalars.contains(where: \.properties.isIdeographic),
               let latin = CFStringTokenizerCopyCurrentTokenAttribute(
                   tokenizer,
                   kCFStringTokenizerAttributeLatinTranscription
               ) as? String,
               let reading = latin.applyingTransform(.latinToHiragana, reverse: false) {
                key += reading
            } else {
                key += token
            }
            cursor = range.location + range.length
        }
        return key + text.substring(from: cursor)
    }

    /// The asset covering an ingredient name, when the catalog has one.
    public static func ingredient(named name: String) -> String? {
        let cleaned = normalized(name)
        guard !cleaned.isEmpty else { return nil }
        if let alias = aliases[cleaned] { return alias }
        if let localized = localizedIngredients[cleaned] { return localized }
        return ingredients.first { normalized($0) == cleaned }
    }

    /// Ranks a set by how well each name matches the search text: whole word, then prefix,
    /// then anywhere in the name. Both the asset's own name and its localized name are scored,
    /// so a cook finds an icon by either.
    private static func search(_ query: String, in set: [String]) -> [String] {
        let cleaned = normalized(query)
        guard !cleaned.isEmpty else { return set }
        let words = cleaned.split(separator: " ").map(String.init)
        var ranked: [(name: String, score: Int)] = []
        for name in set {
            let candidates = [normalized(name), searchNames[name] ?? normalized(displayName(for: name))]
            let score = candidates.map { score($0, against: cleaned, words: words) }.max() ?? 0
            if score > 0 { ranked.append((name, score)) }
        }
        if let alias = aliases[cleaned], !ranked.contains(where: { $0.name == alias }) {
            ranked.append((alias, 90))
        }
        return ranked
            .sorted { $0.score == $1.score ? $0.name < $1.name : $0.score > $1.score }
            .map(\.name)
    }

    /// How well one name answers the search text. Of two names found inside the text, the
    /// longer says more, so "ground sichuan peppercorns" is the peppercorns rather than corn.
    private static func score(_ candidate: String, against query: String, words: [String]) -> Int {
        if candidate == query {
            return 100
        } else if candidate.hasPrefix(query) || query.hasPrefix(candidate) {
            return 60
        } else if query.contains(candidate) {
            return 40 + min(candidate.count, 19)
        } else if candidate.contains(query) {
            return 40
        }
        let candidateWords = Set(candidate.split(separator: " ").map(String.init))
        let shared = candidateWords.intersection(words)
        return shared.isEmpty ? 0 : 20 + shared.count
    }

    /// Lowercased, punctuation free, and space separated, so `Spring Onions!` and
    /// `spring-onion` compare equal.
    private static func normalized(_ text: String) -> String {
        let stripped = text.lowercased()
            .map { $0.isLetter || $0.isNumber ? String($0) : " " }
            .joined()
            .split(separator: " ")
            .map { $0.count > 3 && $0.hasSuffix("s") ? String($0.dropLast()) : String($0) }
        return stripped.joined(separator: " ")
    }

    private static func resolve(_ guess: String, itemName: String, in set: [String]) -> String? {
        let cleaned = (iconName(for: guess) ?? guess).lowercased()
        if set.contains(cleaned) { return cleaned }
        return search(itemName, in: set).first ?? search(cleaned, in: set).first
    }
}
