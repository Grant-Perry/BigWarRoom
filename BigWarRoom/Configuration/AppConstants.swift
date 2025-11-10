import SwiftUI

/// Global application constants and feature flags.
struct AppConstants {
    // 🔥 FIXED: Default to current NFL season (2025), not calendar year
    @AppStorage("selectedESPNYear") static var ESPNLeagueYear: String = "2025"
    
    // Dynamic debug mode - can be toggled in settings
   // turn debugging on/off
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
    static let availableYears = ["2024", "2025", "2026"] // Add more years as needed
    
    // MARK: -> Fantasy Matchup Refresh Settings
    static let MatchupRefresh = 15 // seconds - how often fantasy matchups auto-refresh

    // LEGACY: Keep these for backward compatibility but they're now managed by ESPNCredentialsManager
    // These are Gp's original credentials - users will set their own in ESPNSetupView
    static let SWID = "{7D6C3526-D30A-4DBD-9849-3D9C03333E7C}"

    static let ESPN_S2_2025_Orig = "AEAQAAVXgHBaJ%2Fq1pPpnsckBKlBKXxsRJyttQjQhae67N%2Bz5kVdRdn001uU8V30qYT3z9n7R%2FsLNqWd%2BskxNWwMKr7kpL1%2Fs2J6BCvH8su%2F8gsDOcv44fRm6zbxMq6kQHoFdwGjSf7bnoMp8j5gDC29iDExGMF%2B5ObIreHcchFk8AQGZVNi2cSTCdxevEuioMNPDTbehk%2B4kPI1n5KxqtXnm9Z5gz5UpJv42IJNmT0nwfqMq9Vjz0MYqvj%2BbN7%2B5%2Bky9PwK8%2FUgAeWXObJ9ezOlCZGMmEO4Wyrq2dDl8DeGJKg%3D%3D"
    
   static let ESPN_S2 = "AECZhMx2EpWMK1F56f5N8HfKaTHgYIOYYEH%2F2DhPxf0BzfWqW%2BQTWZk1QC%2F4WfO0OdC1sUcG1jYOUISX217BGcQOS8VuqspUYVSzrXMiUlEA2JCYK1fhEPUYJvadfhNovy%2F%2F4j94exvkMUMVvuAfyog0W%2BmHN0lMsJh3Qh7Yot7yueZoicSwYM7nuks2FJrE%2FTZ8hw%2B8NmLCP3mYD1TgXke1GbiP6jTudabpmcYq%2FGK3RKUdyJInaRDCK08BkWJ%2FShcrHNl7l6Q3FATnalIQeBjJU%3D"

   static let ESPN_S2_2025 = "AEB88BoMXDka9K83s5stW9QsDt0GljM%2B1sNtLZd%2B9sDDlsYFz0SL9k3Aa0npXxbSxnmpFs4%2B1l4KgEil3tJb4unSis8ub8D%2BgT8ELZFoAAWD%2Brdg5F8kHsDaciUsquw9IECawaht67iaricSWJFmDeU8ae3xuyF71U1p22btvkbQdrWOC%2FQ%2BxMAxZhRl5HfrS1INxkQT%2BPAzM1K0IwtFqZBHXm8BWdu0f5OukBHqj%2BDkc1geGREKsbBz7dtRbtWDGs8Uk%2Bav63lCvpRVj7Cl0le7UlXe2II3CpJGKnQkLvmXojWV1YxHldhZ6mWv4JPs0to%3D"

    static let ESPNLeagueID = ["1241361400", "1739710242", "1003758336", "1486575797", "1471913910"] // Gp's original league IDs

    static let GpESPNID = SWID
    static let ESPN_AUTH = "{\"swid\":\"\(SWID)\"}"

    // Sleeper Default User Configuration
    static let SleeperUser = "Gp0"
    
    // Sleeper IDs - kept for backward compatibility but BigWarRoom gets leagues dynamically
    static let GpManagerID = "1117588009542615040"
    static let sleeperID = "1117588009542615040"
    static let GpSleeperID = "1117588009542615040"
    static let GpSleeperUsername = SleeperUser // Wire to the main property
    static let rossManagerID = "1044843366334828544"
    static let managerID = rossManagerID

    // Legacy league/draft IDs - kept for SleepThis project compatibility
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
    /// Get the current season year - now requires dependency injection instead of singleton
    /// NOTE: This will need to be updated in Phase 3 when we wire up dependency injection
    /// For now, keeping ESPNLeagueYear as the source of truth
    static var currentSeasonYear: String {
        return ESPNLeagueYear
    }
    
    /// Get the current season year as Int for API calls
    static var currentSeasonYearInt: Int {
        return Int(ESPNLeagueYear) ?? 2025
    }
    
    // MARK: -> ESPN Token Management (Updated to use SSOT)
    /// Get the primary ESPN token for current season year
    static var currentESPNToken: String {
        return getPrimaryESPNToken(for: currentSeasonYear)
    }
    
    /// Get the alternate ESPN token for current season year
    static var currentAlternateESPNToken: String {
        return getAlternateESPNToken(for: currentSeasonYear)
    }
    
    /// Get the primary ESPN token for a given year
    static func getPrimaryESPNToken(for year: String) -> String {
        return year == "2025" ? ESPN_S2_2025 : ESPN_S2
    }
    
    /// Get the alternate ESPN token for a given year (for fallback)
    static func getAlternateESPNToken(for year: String) -> String {
        return year == "2025" ? ESPN_S2 : ESPN_S2_2025
    }
    
    /// Get the best ESPN token for a specific league (with known problematic leagues)
    static func getESPNTokenForLeague(_ leagueID: String, year: String) -> String {
        // Known problematic leagues that need the 2025 token first
        let problematicLeagues = ["1241361400"] // Add more as needed
        
        if problematicLeagues.contains(leagueID) {
            // Use ESPN_S2_2025 first for problematic leagues (regardless of year)
            return ESPN_S2_2025
        } else {
            // Use primary token for normal leagues
            return getPrimaryESPNToken(for: year)
        }
    }

    // MARK: VIEWS

    // App Logo - Main branding logo for loading screen and about page
    static var appLogo: some View {
        // Try to load the actual app logo/icon first, fallback to designed logo
        Group {
            if UIImage(named: "AppLogo") != nil {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
            } else {
                // Fallback designed logo with beautiful glow - NO ROTATION
                GlowingAppLogo()
            }
        }
    }

    // ESPN Logo - with fallback for missing image asset
    static var espnLogo: some View {
        // Try to load the image, fallback to a styled ESPN badge
        Group {
            if UIImage(named: "espnLogo") != nil {
                Image("espnLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)
            } else {
                // Fallback ESPN logo using text with ESPN branding colors
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
        // Try to load the image, fallback to a styled Sleeper badge
        Group {
            if UIImage(named: "sleeperLogo") != nil {
                Image("sleeperLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)
            } else {
                // Clean Sleeper logo using text with minimal styling
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

// MARK: - Glowing App Logo Component (No Rotation!)

private struct GlowingAppLogo: View {
    @State private var glowIntensity: Double = 0.3
    
    var body: some View {
        ZStack {
            // Glow layers - multiple for intense effect
            ForEach(0..<3) { index in
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [Color.purple.opacity(0.6), Color.blue.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120 + CGFloat(index * 10), height: 120 + CGFloat(index * 10))
                    .blur(radius: CGFloat(5 + index * 5))
                    .opacity(glowIntensity * (1.0 - Double(index) * 0.3))
            }
            
            // Main logo background
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.95),
                            Color.purple.opacity(0.1),
                            Color.blue.opacity(0.2)
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 60
                    )
                )
                .frame(width: 100, height: 100)
            
            // Logo icon - brain for BigWarRoom
            Image(systemName: "brain.head.profile.fill")
                .font(.system(size: 40, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.purple, Color.blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .onAppear {
            // Gentle pulsing glow instead of rotation
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                glowIntensity = 0.8
            }
        }
    }
}
