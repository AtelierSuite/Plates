import Foundation

extension String {
    /// A string from this package's own catalog. Everything the package says, to a model or to
    /// the cook, is written there rather than in the app's.
    nonisolated init(culinary key: String.LocalizationValue) {
        self.init(localized: key, bundle: .module)
    }
}

extension LocalizedStringResource {
    /// A key in this package's catalog, for text the app shows as it stands.
    nonisolated init(culinary key: String.LocalizationValue) {
        self.init(key, bundle: .atURL(Bundle.module.bundleURL))
    }
}

extension String {
    /// A string from this package's catalog in US English, whatever language the app is read
    /// in. Gemma is always asked in English, so everything it is given is read through here.
    nonisolated init(culinaryEnglish key: String.LocalizationValue) {
        self.init(localized: key, bundle: .englishModule)
    }
}

extension Bundle {
    /// The package's English strings on their own, so a lookup never falls through to the
    /// reader's language.
    nonisolated static let englishModule: Bundle = Bundle.module
        .path(forResource: "en-US", ofType: "lproj")
        .flatMap(Bundle.init(path:)) ?? .module

    /// The package's Japanese strings on their own, for reading a name the way a cook writing
    /// in Japanese would, and for lines code writes into a Japanese recipe, whatever language
    /// the app is read in.
    nonisolated static let japaneseModule: Bundle = Bundle.module
        .path(forResource: "ja", ofType: "lproj")
        .flatMap(Bundle.init(path:)) ?? .module
}
