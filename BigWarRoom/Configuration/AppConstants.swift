import SwiftUI

/// Global application constants and feature flags.
struct AppConstants {
    static let debug = false
    static let maxCacheDays = 5.0
    static let verSize = 11.0
    static let verColor = Color.gpGreen

    // Feature flags
    static let useAISuggestions = false

    // ESPN
    static let GpESPNID = "%7B8A3B2780-FA70-4A52-9AFD-3BEE4D5A7468%7D"
    static let ESPNLeagueID = ["1241361400", "1241361400", "1365003638"]
    static let ESPNLeagueYear = "2024"
    static let SWID = "{8A3B2780-FA70-4A52-9AFD-3BEE4D5A7468}"
    static let ESPN_S2 = "AEAQAAVXgHBaJ%2Fq1pPpnsckBKlBKXxsRJyttQjQhae67N%2Bz5kVdRdn001uU8V30qYT3z9n7R%2FsLNqWd%2BskxNWwMKr7kpL1%2Fs2J6BCvH8su%2F8gsDOcv44fRm6zbxMq6kQHoFdwGjSf7bnoMp8j5gDC29iDExGMF%2B5ObIreHcchFk8AQGZVNi2cSTCdxevEuioMNPDTbehk%2B4kPI1n5KxqtXnm9Z5gz5UpJv42IJNmT0nwfqMq9Vjz0MYqvj%2BbN7%2B5%2Bky9PwK8%2FUgAeWXObJ9ezOlCZGMmEO4Wyrq2dDl8DeGJKg%3D%3D"
    static let ESPN_AUTH = "{\"swid\":\"\(SWID)\"}"

    // Sleeper IDs
    static let GpManagerID = "1117588009542615040"
    static let sleeperID = "1117588009542615040"
    static let GpSleeperID = "1117588009542615040"
    static let rossManagerID = "1044843366334828544"
    static let managerID = rossManagerID

    // Leagues/Drafts
    static let BigBoysLeagueID = "1136822872179224576"
    static let BigBoysDraftID = "1136822873030782976"

    static let TwoBrothersLeagueID = "1044844006657982464"
    static let TwoBrothersDraftID = "1044844007601504256"

    // Active selections
    static let leagueID = TwoBrothersLeagueID
    static let SleeperLeagueID = TwoBrothersLeagueID
    static let draftID = TwoBrothersDraftID

    /// Returns the app's version string "X.Y (Build)" for display.
    static func getVersion() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "\(version) (\(build))"
    }
}
