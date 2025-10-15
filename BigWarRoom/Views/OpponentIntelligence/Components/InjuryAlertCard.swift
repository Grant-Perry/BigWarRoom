//
//  InjuryAlertCard.swift
//  BigWarRoom
//
//  Critical Threat Alert card for injured/BYE players
//

import SwiftUI

/// Card displaying injury status alerts for my rostered players
struct InjuryAlertCard: View {
    let recommendation: StrategicRecommendation
    let onNavigateToMatchup: ((UnifiedMatchup) -> Void)? // Navigation callback
    
    // Convenience init for backward compatibility
    init(recommendation: StrategicRecommendation) {
        self.recommendation = recommendation
        self.onNavigateToMatchup = nil
    }
    
    // Full init with navigation callback
    init(recommendation: StrategicRecommendation, onNavigateToMatchup: ((UnifiedMatchup) -> Void)?) {
        self.recommendation = recommendation
        self.onNavigateToMatchup = onNavigateToMatchup
    }
    
    // Use actual InjuryAlert data if available, otherwise fall back to parsing
    private var injuryAlert: InjuryAlert? {
        recommendation.injuryAlert
    }
    
    private var playerName: String {
        if let alert = injuryAlert {
            return alert.player.fullName
        }
        // Fallback to parsing
        let components = recommendation.description.components(separatedBy: " is ")
        return components.first ?? "Unknown Player"
    }
    
    private var statusType: InjuryStatusType {
        if let alert = injuryAlert {
            return alert.injuryStatus
        }
        // Fallback to parsing
        let description = recommendation.description.lowercased()
        if description.contains("bye") {
            return .bye
        } else if description.contains("injured reserve") || description.contains("ir") {
            return .injuredReserve
        } else if description.contains("status is o") || description.contains("out") {
            return .out
        } else if description.contains("questionable") {
            return .questionable
        }
        return .questionable
    }
    
    private var leagueRosters: [InjuryLeagueRoster] {
        injuryAlert?.leagueRosters ?? []
    }
    
    private var priorityBadge: String {
        switch statusType {
        case .bye, .injuredReserve, .out, .pup, .nfi:
            return "URGENT"
        case .doubtful, .questionable:
            return "ATTENTION"
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            mainAlertContent
            
            if !leagueRosters.isEmpty {
                leagueRosterSection
            }
        }
        .background(blurBackdrop)
        .background(outerGlow)
    }
    
    // MARK: - View Components
    
    private var mainAlertContent: some View {
        HStack(spacing: 16) {
            playerImage // Player image now on the LEFT
            alertContent
            Spacer()
            statusIcon // Status icon now on the RIGHT
        }
        .padding(16)
    }
    
    private var playerImage: some View {
        Group {
            if let alert = injuryAlert {
                // Use the same pattern as FantasyPlayerCardHeadshotView for consistency (DRY)
                AsyncImage(url: alert.player.headshotURL) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(width: 60, height: 60)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .clipShape(Circle()) // Changed to Circle
                            .overlay(
                                Circle() // Changed to Circle
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1) // Thin white border
                            )
                    case .failure:
                        // Fallback: Try ESPN URL like FantasyPlayerCardFallbackHeadshotView
                        if let espnURL = alert.player.espnHeadshotURL {
                            AsyncImage(url: espnURL) { phase2 in
                                switch phase2 {
                                case .success(let image2):
                                    image2
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 60, height: 60)
                                        .clipShape(Circle()) // Changed to Circle
                                        .overlay(
                                            Circle() // Changed to Circle
                                                .stroke(Color.white.opacity(0.2), lineWidth: 1) // Thin white border
                                        )
                                default:
                                    playerImagePlaceholder
                                }
                            }
                        } else {
                            playerImagePlaceholder
                        }
                    @unknown default:
                        playerImagePlaceholder
                    }
                }
            } else {
                playerImagePlaceholder
            }
        }
        .frame(width: 60, height: 60) // Square frame for circle
    }
    
    private var playerImagePlaceholder: some View {
        Circle() // Changed to Circle
            .fill(Color.gray.opacity(0.3))
            .overlay(
                VStack(spacing: 2) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.6))
                    
                    // Show position if available
                    if let alert = injuryAlert {
                        Text(alert.player.position)
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            )
            .overlay(
                Circle() // Changed to Circle
                    .stroke(Color.white.opacity(0.2), lineWidth: 1) // Thin white border
            )
            .frame(width: 60, height: 60) // Square frame for circle
    }
    
    private var statusIcon: some View {
        ZStack {
            Circle()
                .fill(statusType == .bye ? Color.gpPink : statusType.color)
                .frame(width: 50, height: 50)
            
            // Large capital letter instead of SF Symbol
            Text(String(statusType.displayName.prefix(1)))
                .font(.system(size: 24, weight: .black))
                .foregroundColor(.white)
            
            if recommendation.priority == .critical {
                priorityIndicator
            }
        }
    }
    
    private var priorityIndicator: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Circle()
                    .fill(Color.red)
                    .frame(width: 16, height: 16)
                    .overlay(
                        Image(systemName: "exclamationmark")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(.white)
                    )
            }
        }
        .frame(width: 50, height: 50)
    }
    
    private var alertContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Player name first - larger font
            Text(playerName)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            
            // Status with special handling for BYE
            HStack(spacing: 4) {
                if statusType == .bye {
                    // BYE Week: Red oval around entire word "BYE" with gpPink background
                    Text("BYE")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gpPink)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.red, lineWidth: 1)
                                )
                        )
                    
                    Text("Week")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                } else {
                    // Other statuses: First letter in colored circle + rest of word
                    Circle()
                        .fill(statusType.color)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Text(String(statusType.displayName.prefix(1)))
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                    )
                    // Rest of the status word - closer/overlapping
                    Text(String(statusType.displayName.dropFirst()))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                        .offset(y: -1)
                }
            }
            
            Text(getActionText())
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .lineLimit(2)
        }
    }
    
    private var alertHeader: some View {
        HStack {
            Spacer()
            
            Text(priorityBadge)
                .font(.system(size: 10, weight: .black))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(statusType.color)
                )
        }
    }
    
    private var leagueRosterSection: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color.white.opacity(0.2))
            
            VStack(alignment: .leading, spacing: 8) {
                leagueHeader
                leagueGrid
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            .background(
                // Add the gpDeltaPurple gradient background
                LinearGradient(
                    colors: [
					 Color.padresDark.opacity(0.4),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }
    
    private var leagueHeader: some View {
        HStack {
            Image(systemName: "building.2.fill")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.7))
            
            Text("Rostered in \(leagueRosters.count) league\(leagueRosters.count > 1 ? "s" : ""):")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
            
            Spacer()
        }
    }
    
    private var leagueGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), alignment: .leading),
            GridItem(.flexible(), alignment: .trailing)
        ], spacing: 8) {
            ForEach(Array(leagueRosters.enumerated()), id: \.element.id) { index, leagueRoster in
                leagueButton(for: leagueRoster)
            }
        }
    }
    
    private func leagueButton(for leagueRoster: InjuryLeagueRoster) -> some View {
        Button(action: {
            openLeagueURL(for: leagueRoster)
        }) {
            HStack(spacing: 8) {
                leagueSourceLogo(for: leagueRoster)
                leagueInfo(for: leagueRoster)
                Spacer()
                
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(leagueButtonBackground)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func leagueSourceLogo(for leagueRoster: InjuryLeagueRoster) -> some View {
        Group {
            if leagueRoster.leagueSource == .espn {
                Image("espnLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
            } else {
                Image("sleeperLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
            }
        }
    }
    
    private func leagueInfo(for leagueRoster: InjuryLeagueRoster) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(leagueRoster.leagueName)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
            
            if leagueRosters.count > 1 {
                Text(leagueRoster.isStarterInThisLeague ? "STARTING" : "BENCH")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }
    
    private var leagueButtonBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(.thinMaterial)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.3))
            )
    }
    
    private var blurBackdrop: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(.thinMaterial)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.2))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(statusType.color, lineWidth: 2)
            )
    }
    
    private var outerGlow: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(
                LinearGradient(
                    colors: [
                        statusType.color.opacity(0.15),
                        statusType.color.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .blur(radius: 1)
    }
    
    // MARK: - Helper Methods
    
    private func getActionText() -> String {
        switch statusType {
        case .bye:
            return "Replace immediately - won't play this week"
        case .injuredReserve:
            return "Move to IR slot or find replacement"
        case .out:
            return "Replace before games start - confirmed out"
        case .doubtful:
            return "Very unlikely to play - prepare backup"
        case .questionable:
            return "Monitor status and prepare backup plan"
        case .pup:
            return "Expected out at least 6 weeks - find replacement"
        case .nfi:
            return "Non-football injury - monitor status updates"
        }
    }
    
    /// Open external league URL based on league source
    private func openLeagueURL(for leagueRoster: InjuryLeagueRoster) {
        switch leagueRoster.leagueSource {
        case .sleeper:
            // Launch Sleeper app
            if let sleeperURL = URL(string: "sleeper://") {
                #if os(iOS)
                UIApplication.shared.open(sleeperURL)
                #endif
                print("🚀 Launching Sleeper app")
            }
            
        case .espn:
            // ESPN: Use full web URL with league ID and team ID
            guard let url = generateLeagueURL(for: leagueRoster) else {
                print("❌ Could not generate ESPN league URL for \(leagueRoster.leagueName)")
                return
            }
            
            print("🔗 Opening ESPN league URL: \(url.absoluteString)")
            
            #if os(iOS)
            UIApplication.shared.open(url)
            #elseif os(macOS)
            NSWorkspace.shared.open(url)
            #endif
        }
    }
    
    /// Generate the appropriate URL for the league
    private func generateLeagueURL(for leagueRoster: InjuryLeagueRoster) -> URL? {
        let matchup = leagueRoster.matchup
        
        switch leagueRoster.leagueSource {
        case .sleeper:
            // Sleeper uses app launch, no URL needed
            return nil
            
        case .espn:
            // ESPN URL: https://fantasy.espn.com/football/team?leagueId=[LeagueID]&teamId=[TeamID]&view=overview
            let leagueID = matchup.league.league.leagueID
            
            guard let teamID = ESPNCredentialsManager.shared.getTeamID(for: leagueID) else {
                print("❌ ESPN: No team ID found for league \(leagueID)")
                return nil
            }
            
            let urlString = "https://fantasy.espn.com/football/team?leagueId=\(leagueID)&teamId=\(teamID)&view=overview"
            return URL(string: urlString)
        }
    }
    
    private func navigateToLeagueRoster(_ leagueRoster: InjuryLeagueRoster) {
        // DEPRECATED: This method is now replaced by openLeagueURL
        // Navigate to the specific matchup for this league
        onNavigateToMatchup?(leagueRoster.matchup)
        print("Navigating to \(leagueRoster.leagueName) matchup for \(playerName)")
    }
    
    private func navigateToLeague(_ leagueName: String) {
        // This method is obsolete - replaced with navigateToLeagueRoster
    }
}

// MARK: - Preview

#Preview("Multi-League Injury Alert") {
    ScrollView {
        VStack(spacing: 16) {
            // Multi-league BYE Alert
            InjuryAlertCard(recommendation: StrategicRecommendation(
                type: .injuryAlert,
                title: "Player on BYE Week", 
                description: "Josh Allen is on BYE Week in 3 leagues: Main League, Dynasty League, Work League. Replace immediately - won't play this week.",
                priority: .critical,
                actionable: true,
                opponentTeam: nil
            ))
            
            // Single league IR Alert  
            InjuryAlertCard(recommendation: StrategicRecommendation(
                type: .injuryAlert,
                title: "Player on Injured Reserve",
                description: "Christian McCaffrey is on Injured Reserve (IR) in Dynasty League. Move to IR slot or find replacement.",
                priority: .critical,
                actionable: true,
                opponentTeam: nil
            ))
            
            // OUT Alert
            InjuryAlertCard(recommendation: StrategicRecommendation(
                type: .injuryAlert,
                title: "Player Out",
                description: "Cooper Kupp is OUT in 2 leagues: Redraft League, Friends League. Replace immediately.",
                priority: .critical,
                actionable: true,
                opponentTeam: nil
            ))
            
            // Doubtful Alert
            InjuryAlertCard(recommendation: StrategicRecommendation(
                type: .injuryAlert,
                title: "Player Doubtful",
                description: "Derrick Henry is DOUBTFUL in Work League. Very unlikely to play.",
                priority: .high,
                actionable: true,
                opponentTeam: nil
            ))
            
            // Questionable Alert
            InjuryAlertCard(recommendation: StrategicRecommendation(
                type: .injuryAlert,
                title: "Player Questionable", 
                description: "Travis Kelce is QUESTIONABLE in Work League. Monitor closely and have backup ready.",
                priority: .high,
                actionable: true,
                opponentTeam: nil
            ))
            
            // PUP Alert
            InjuryAlertCard(recommendation: StrategicRecommendation(
                type: .injuryAlert,
                title: "Player on PUP List",
                description: "Nick Chubb is on Physically Unable to Perform list in Dynasty League. Expected to be out at least 6 weeks.",
                priority: .critical,
                actionable: true,
                opponentTeam: nil
            ))
        }
        .padding()
    }
    .background(Color.black)
    .preferredColorScheme(.dark)
}