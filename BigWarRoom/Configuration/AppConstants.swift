import SwiftUI

/// Global application constants and feature flags.
struct AppConstants {
    static let debug = true
    static let maxCacheDays = 5.0
    static let verSize = 12.0
    static let verColor = Color.gpGreen

    // Feature flags
    static let useAISuggestions = false

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
                // Fallback Sleeper logo using text with Sleeper branding colors
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(LinearGradient(
                            colors: [Color.blue, Color.blue.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))

                    Text("SLEEPER")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .tracking(0.5)
                }
                .frame(width: 50, height: 50)
            }
        }
		.offset(y: -8)
    }

    // ESPN - Updated with working credentials from SleepThis
    static let ESPNLeagueID = ["1241361400", "1739710242", "1003758336"] // Keep hardcoded ESPN league IDs

    // Season configuration - can be changed dynamically
    @AppStorage("selectedESPNYear") static var ESPNLeagueYear: String = "2025"
    static let availableYears = ["2024", "2025", "2026"] // Add more years as needed

    static let SWID = "{7D6C3526-D3A-4DBD-9849-3D9C03333E7C}"


   static let ESPN_S2 = "AEAQAAVXgHBaJ%2Fq1pPpnsckBKlBKXxsRJyttQjQhae67N%2Bz5kVdRdn001uU8V30qYT3z9n7R%2FsLNqWd%2BskxNWwMKr7kpL1%2Fs2J6BCvH8su%2F8gsDOcv44fRm6zbxMq6kQHoFdwGjSf7bnoMp8j5gDC29iDExGMF%2B5ObIreHcchFk8AQGZVNi2cSTCdxevEuioMNPDTbehk%2B4kPI1n5KxqtXnm9Z5gz5UpJv42IJNmT0nwfqMq9Vjz0MYqvj%2BbN7%2B5%2Bky9PwK8%2FUgAeWXObJ9ezOlCZGMmEO4Wyrq2dDl8DeGJKg%3D%3D"


   static let ESPN_S2_2025 = "AECZhMx2EpWMK1F56f5N8HfKaTHgYIOYYEH%2F2DhPxf0BzfWqW%2BQTWZk1QC%2F4WfO0OdC1sUcG1jYOUISX217BGcQOS8VuqspUYVSzrXMiUlEA2BFibvpLExGWa5Pxbdu10Ml%2FBcljaVp9DHmOlH2sEU2JCYK1fhEPUYJvadfhNovy%2F%2F4j94exvkMUMVvuAfyog0W%2BmHN0lMsJh3Qh7Yot7yueZoicSwYM7nuks2FJrE%2FTZ8hw%2B8NmLCP3mYD1TgXke1GbiP6jTudabpmcYq%2FGK3RKUdyJInaRDCK08BkWJ%2FShcrHNl7l6Q3FATnalIQeBjJU%3D"


    static let GpESPNID = SWID
    static let ESPN_AUTH = "{\"swid\":\"\(SWID)\"}"

    // Sleeper IDs - kept for backward compatibility but BigWarRoom gets leagues dynamically
    static let GpManagerID = "1117588009542615040"
    static let sleeperID = "1117588009542615040"
    static let GpSleeperID = "1117588009542615040"
    static let rossManagerID = "1044843366334828544"
    static let managerID = rossManagerID

    // Legacy league/draft IDs - kept for SleepThis project compatibility
    static let BigBoysLeagueID = "1136822872179224576"
    static let BigBoysDraftID = "1136822873030782976"
    static let TwoBrothersLeagueID = "1044844006657982464"
    static let TweBrothersDraftID = "1044844007601504256"

    /// Returns the app's version string "X.Y (Build)" for display.
    static func getVersion() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "\(version) (\(build))"
    }
}
