import Foundation

enum AppConfiguration {
    static let appsFlyerDevKey = "FsqhDtV6LQVNxAdCc8tkVS"
    static let appleAppID = "6783875103"
    static let storeID = "id6783875103"
    static let expectedBundleID = "com.SteadyFlowplayJeremy"
    static let firebaseProjectID = "steadyflowplay-jumping-block"
    static let firebaseProjectNumber = "880942063197"

    static let siteURL = URL(string: "https://steadyflowplayjumpingblock.com")!
    static let privacyPolicyURL = URL(string: "https://steadyflowplayjumpingblock.com/privacy-policy.html")!
    static let supportURL = URL(string: "https://steadyflowplayjumpingblock.com/support.html")!
    static let configURL = URL(string: "https://steadyflowplayjumpingblock.com/config.php")!

    static var bundleID: String {
        Bundle.main.bundleIdentifier ?? expectedBundleID
    }
}
