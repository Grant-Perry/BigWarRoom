import SwiftUI

/// Global application constants and feature flags.
struct AppConstants {
    // Default to current NFL season (2025), not calendar year
    @AppStorage("selectedESPNYear") static var ESPNLeagueYear: String = "2025"
    
    // Dynamic debug mode - can be toggled in settings
    static var debug: Bool {
        get {
            return UserDefaults.standard.object(forKey: "debugModeEnabled") != nil ?
                UserDefaults.standard.bool(forKey: "debugModeEnabled") : false
        }
    }
    
    static let maxCacheDays = 5.0
    static let verSize = 12.0
    static let verColor = Color.gpGreen
    static let useAISuggestions = false
    static let availableYears = ["2024", "2025", "2026"]
    
    // MARK: -> Fantasy Matchup Refresh Settings (persistent)
    @AppStorage("MatchupRefresh") static var MatchupRefresh: Int = 15 // seconds (applies during live games)
    
    // MARK: -> Win Probability Calculation
    /// SD ~40 gives results similar to ESPN's win probability model
    @AppStorage("WinProbabilitySD") static var WinProbabilitySD: Double = 40.0

    // LEGACY: Keep these for backward compatibility (now managed by ESPNCredentialsManager)
    static let SWID = "{7D6C3526-D30A-4DBD-9849-3D9C03333E7C}"

    static let ESPN_S2_2025_Orig =
        "AEAQAAVXgHBaJ%2Fq1pPpnsckBKlBKXxsRJyttQjQhae67N%2Bz5kVdRdn001uU8V30qYT3z9n7R%2FsLNqWd%2BskxNWwMKr7kpL1%2Fs2J6BCvH8su%2F8gsDOcv44fRm6zbxMq6kQHoFdwGjSf7bnoMp8j5gDC29iDExGMF%2B5ObIreHcchFk8AQGZVNi2cSTCdxevEuioMNPDTbehk%2B4kPI1n5KxqtXnm9Z5gz5UpJv42IJNmT0nwfqMq9Vjz0MYqvj%2BbN7%2B5%2Bky9PwK8%2FUgAeWXObJ9ezOlCZGMmEO4Wyrq2dDl8DeGJKg%3D%3D"
    
    static let ESPN_S2 =
        "AECZhMx2EpWMK1F56f5N8HfKaTHgYIOYYEH%2F2DhPxf0BzfWqW%2BQTWZk1QC%2F4WfO0OdC1sUcG1jYOUISX217BGcQOS8VuqspUYVSzrXMiUlEA2JCYK1fhEPUYJvadfhNovy%2F%2F4j94exvkMUMVvuAfyog0W%2BmHN0lMsJh3Qh7Yot7yueZoicSwYM7nuks2FJrE%2FTZ8hw%2B8NmLCP3mYD1TgXke1GbiP6jTudabpmcYq%2FGK3RKUdyJInaRDCK08BkWJ%2FShcrHNl7l6Q3FATnalIQeBjJU%3D"

    static let ESPN_S2_2025 =
        "AEB88BoMXDka9K83s5stW9QsDt0GljM%2B1sNtLZd%2B9sDDlsYFz0SL9k3Aa0npXxbSxnmpFs4%2B1l4KgEil3tJb4unSis8ub8D%2BgT8ELZFoAAWD%2Brdg5F8kHsDaciUsquw9IECawaht67iaricSWJFmDeU8ae3xuyF71U1p22btvkbQdrWOC%2FQ%2BxMAxZhRl5HfrS1INxkQT%2BPAzM1K0IwtFqZBHXm8BWdu0f5OukBHqj%2BDkc1geGREKsbBz7dtRbtWDGs8Uk%2Bav63lCvpRVj7Cl0le7UlXe2II3CpJGKnQkLvmXojWV1YxHldhZ6mWv4JPs0to%3D"

    static let ESPNLeagueID = ["1241361400", "1739710242", "1003758336", "1486575797", "1471913910"]

    static let GpESPNID = SWID
    static let ESPN_AUTH = "{\"swid\":\"\(SWID)\"}"

    // Sleeper Default User Configuration
    static let SleeperUser = "Gp0"
    static let GpManagerID = "1117588009542615040"
    static let sleeperID = "1117588009542615040"
    static let GpSleeperID = "1117588009542615040"
    static let GpSleeperUsername = SleeperUser
    static let rossManagerID = "1044843366334828544"
    static let managerID = rossManagerID

    // Legacy league/draft IDs - compatibility
    static let BigBoysLeagueID = "1136822872179224576"
    static let BigBoysDraftID = "1136822873030782976"
    static let TwoBrothersLeagueID = "1044844006657982464"

    /// Returns the app's version string "X.Y (Build)" for display.
    static func getVersion() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "\(version) (\(build))"
    }

    // MARK: -> Current Season Year (SSOT)
    static var currentSeasonYear: String {
        return ESPNLeagueYear
    }
    
    static var currentSeasonYearInt: Int {
        return Int(ESPNLeagueYear) ?? 2025
    }
    
    // MARK: -> ESPN Token Management (SSOT)
    static var currentESPNToken: String {
        return getPrimaryESPNToken(for: currentSeasonYear)
    }
    
    static var currentAlternateESPNToken: String {
        return getAlternateESPNToken(for: currentSeasonYear)
    }
    
    static func getPrimaryESPNToken(for year: String) -> String {
        return year == "2025" ? ESPN_S2_2025 : ESPN_S2
    }
    
    static func getAlternateESPNToken(for year: String) -> String {
        return year == "2025" ? ESPN_S2 : ESPN_S2_2025
    }
    
    static func getESPNTokenForLeague(_ leagueID: String, year: String) -> String {
        let problematicLeagues = ["1241361400"]
        if problematicLeagues.contains(leagueID) {
            return ESPN_S2_2025
        } else {
            return getPrimaryESPNToken(for: year)
        }
    }

    // MARK: - UserDefaults Cleanup (CRITICAL FIX)
    static func cleanupCorruptedUserDefaults() {
        let keysToRemove = [
            "AllLivePlayers_PreviousScores",
            "AllLivePlayers_PlayerStatsCache",
            "AllLivePlayers_MatchupCache"
        ]
        
        var totalSizeFreed = 0
        
        for key in keysToRemove {
            if let data = UserDefaults.standard.data(forKey: key) {
                totalSizeFreed += data.count
                DebugPrint(mode: .general, "🚨 CLEANUP: Removing corrupted UserDefaults key: \(key) (\(data.count) bytes)")
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        
        UserDefaults.standard.synchronize()
        
        if totalSizeFreed > 0 {
            let sizeKB = Double(totalSizeFreed) / 1024.0
            let sizeMB = sizeKB / 1024.0
            DebugPrint(mode: .general, "🚨 CLEANUP: UserDefaults cleanup complete - freed \(String(format: "%.2f", sizeMB)) MB")
        } else {
            DebugPrint(mode: .general, "🚨 CLEANUP: No corrupted UserDefaults data found")
        }
    }

    // MARK: VIEWS

    // App Logo - Main branding logo for loading screen and about page
    static var appLogo: some View {
        Group {
            if UIImage(named: "AppLogo") != nil {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
            } else {
                GlowingAppLogo()
            }
        }
    }

    // ESPN Logo - with fallback for missing image asset
    static var espnLogo: some View {
        Group {
            if UIImage(named: "espnLogo") != nil {
                Image("espnLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(LinearGradient(
                            colors: [Color.red, Color.red.opacity(0.9)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))

                    Text("ESPN")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .tracking(0.5)
                }
                .frame(width: 50, height: 50)
            }
        }
    }

    // Sleeper Logo - with fallback for missing image asset
    static var sleeperLogo: some View {
        Group {
            if UIImage(named: "sleeperLogo") != nil {
                Image("sleeperLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )

                    Text("SLEEPER")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .tracking(0.5)
                }
                .frame(width: 50, height: 50)
            }
        }
    }
}