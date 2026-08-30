import Foundation

enum AppLinks {
    static let support = URL(string: "https://kamilunavo.com/schon-erledigt/support")!
    static let termsOfUse = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    static var privacy: URL {
        let page = Locale.current.language.languageCode?.identifier == "de" ? "datenschutz" : "privacy"
        return URL(string: "https://kamilunavo.com/schon-erledigt/\(page)")!
    }
}
