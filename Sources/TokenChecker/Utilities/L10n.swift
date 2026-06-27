import Foundation

enum L10n {
    static func tr(_ key: String, language: AppLanguage) -> String {
        NSLocalizedString(key, tableName: nil, bundle: bundle(for: language), value: key, comment: "")
    }

    static func format(_ key: String, language: AppLanguage, _ arguments: CVarArg...) -> String {
        String(format: tr(key, language: language), locale: language.locale, arguments: arguments)
    }

    private static func bundle(for language: AppLanguage) -> Bundle {
        for resourceName in [language.resourceName, language.resourceName.lowercased()] {
            if let path = Bundle.module.path(forResource: resourceName, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                return bundle
            }
        }
        return .module
    }
}
