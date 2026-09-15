import Foundation

enum BrowserCatalog {
    static func discover() -> [BrowserDestination] {
        BrowserKind.allCases.filter(\.isInstalled).map { BrowserDestination(browser: $0) }
    }
}
