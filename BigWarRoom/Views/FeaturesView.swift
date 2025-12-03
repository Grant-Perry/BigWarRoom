//
//  FeaturesView.swift
//  BigWarRoom
//
//  Comprehensive features overview showcasing all BigWarRoom capabilities
//

import SwiftUI

struct FeaturesView: View {
    
    // MARK: - Feature Data Configuration
    private let features: [FeatureData] = [
        FeatureData(
            icon: "target", iconColor: .gpPostBot,
            title: "Mission Control",
            description: "Central hub displaying all your matchups across Sleeper and ESPN leagues. Shows current scores, projections, win probability, and color-coded borders (green winning, red losing). Tap any matchup to view details or launch Lineup RX.",
            badge: nil
        ),
        FeatureData(
            icon: "pills.fill", iconColor: .purple,
            title: "Lineup RX",
            description: "AI-powered lineup optimizer that analyzes your roster and suggests bench/start changes based on projections, opponent rank, and game time. Also provides waiver wire recommendations showing who to drop and multiple add options with projected point improvements.",
            badge: "AI"
        ),
        FeatureData(
            icon: "arrow.left.arrow.right", iconColor: .blue,
            title: "Start/Sit Analyzer",
            description: "Compare two players side-by-side with detailed stats, projections, opponent matchup info, and performance trends. Search or paste player names to see who has the better matchup. Shows OPRK rankings, injury status, and game times for informed decisions.",
            badge: nil
        ),
        FeatureData(
            icon: "chart.bar.fill", iconColor: .gpGreen,
            title: "All Live Players",
            description: "View every rostered player across all your leagues with live scoring. Shows score deltas (points gained since last update), matchup differentials (+/- vs opponent), and performance tiers. Smart default: automatically shows all players on non-game days, active only during games.",
            badge: "NEW"
        ),
        FeatureData(
            icon: "rectangle.stack.fill", iconColor: .cyan,
            title: "Modern Player Cards",
            description: "Optional redesigned player cards with a sleek horizontal layout. Toggle in Settings → Modern Player Card Design. Features floating badges for game status, matchup delta, and injury info with ultra-minimal aesthetics.",
            badge: "NEW"
        ),
        FeatureData(
            icon: "calendar.circle.fill", iconColor: .blue,
            title: "NFL Schedule",
            description: "View the full NFL schedule for any week with live scores, game status, team logos, and records. Shows which teams are in active games and final scores for completed games. Tap a game to see team rosters and depth charts.",
            badge: nil
        ),
        FeatureData(
            icon: "bed.double.fill", iconColor: .orange,
            title: "BYE Week Roster Alerts",
            description: "Schedule tab shows teams on BYE with visual indicators for your rostered players. Green checkmark = no rostered players affected. Red X = you have rostered players on that team who need attention. Quickly identify lineup holes.",
            badge: "NEW"
        ),
        FeatureData(
            icon: "person.text.rectangle.fill", iconColor: .cyan,
            title: "Player Stats Pages",
            description: "Detailed player profiles showing live game stats, season stats, injury status, team depth chart position, leagues where rostered (and rostered against), and fantasy analysis. Tap any player throughout the app to view their page.",
            badge: nil
        ),
        FeatureData(
            icon: "list.bullet.indent", iconColor: .green,
            title: "Team Depth Charts",
            description: "View NFL team depth charts for any position (QB, RB, WR, TE, K, DEF). Shows depth order, jersey numbers, injury status, and current PPR scoring. Tap players to view their full stats.",
            badge: nil
        ),
        FeatureData(
            icon: "person.2.fill", iconColor: .orange,
            title: "Opponent Intelligence",
            description: "Detailed view of your opponent's roster showing all their players, current scores, and projections. Threat Matrix shows opponent manager names in blue. Cross-League Conflicts highlights players you own that opponents also roster.",
            badge: nil
        ),
        FeatureData(
            icon: "clock.badge.checkmark.fill", iconColor: .gpYellow,
            title: "Yet to Play Filter",
            description: "In matchup details, toggle 'All | Only Yet to Play' to filter rosters to just players who haven't started. Uses real game status data - players with 0 points in finished games are correctly excluded.",
            badge: "NEW"
        ),
        FeatureData(
            icon: "cross.case.fill", iconColor: .red,
            title: "Injury Tracking",
            description: "Lists all injured, questionable, or bye-week players across your leagues. Shows injury status (Out, Questionable, Doubtful), which leagues are affected, and lets you tap to view that league's roster.",
            badge: nil
        ),
        FeatureData(
            icon: "eye.fill", iconColor: .gpOrange,
            title: "Player Watch",
            description: "Add any player to your watch list to track them across all leagues with live score updates. Useful for monitoring waiver targets or players you face in multiple leagues.",
            badge: nil
        ),
        FeatureData(
            icon: "magnifyingglass.circle.fill", iconColor: .gpBlue,
            title: "Player Search",
            description: "Search all NFL players or filter to just your rostered players. Shows player photos, teams, positions, and lets you tap to view full stats and depth chart info.",
            badge: nil
        ),
        FeatureData(
            icon: "shield.lefthalf.filled", iconColor: .yellow,
            title: "OPRK (Opponent Rank)",
            description: "Displays opponent defense rankings against each position (1-32). Shows which matchups favor your players. Green = good matchup (1-10), yellow = neutral (11-20), red = tough (21+).",
            badge: nil
        ),
        FeatureData(
            icon: "clock.fill", iconColor: .cyan,
            title: "Game Times",
            description: "Shows kickoff times for player matchups throughout the app. Helps you know which games are coming up and when players lock.",
            badge: nil
        ),
        FeatureData(
            icon: "exclamationmark.triangle.fill", iconColor: .orange,
            title: "Lineup Bye Week Alerts",
            description: "Identifies players on bye in your starting lineup and shows them in a dedicated alert section within Lineup RX. Helps you avoid starting players who won't play this week.",
            badge: nil
        ),
        FeatureData(
            icon: "list.number", iconColor: .gpGreen,
            title: "Move Instructions",
            description: "Step-by-step guide showing exactly how to implement recommended lineup changes. Lists each bench/start action in order with player names and positions.",
            badge: nil
        ),
        FeatureData(
            icon: "checkmark.square.fill", iconColor: .green,
            title: "Optimal Lineup Display",
            description: "Visual representation of what your lineup should look like after applying all recommended changes. Shows projected points for each position slot.",
            badge: nil
        ),
        FeatureData(
            icon: "scale.3d", iconColor: .purple,
            title: "Cross-League Conflicts",
            description: "Detects when you own a player in one league but face them as an opponent in another. Shows the player, leagues involved, and scoring impact.",
            badge: nil
        ),
        FeatureData(
            icon: "building.columns.fill", iconColor: .gpBlue,
            title: "Team Rosters",
            description: "View rosters for any NFL team. Shows all players by position with depth chart order, injuries, and stats. Tap any player to see their full profile.",
            badge: nil
        ),
        FeatureData(
            icon: "gauge.with.dots.needle.bottom.50percent", iconColor: .gpGreen,
            title: "Projected Points",
            description: "Displays fantasy point projections for all players based on current week matchups. Used throughout the app for lineup optimization and player comparisons.",
            badge: nil
        ),
        FeatureData(
            icon: "percent", iconColor: .cyan,
            title: "Win Probability",
            description: "Shows estimated win percentage on each matchup card. Color-coded green for likely wins, red for likely losses. Updates as games progress.",
            badge: nil
        ),
        FeatureData(
            icon: "arrow.up.arrow.down.circle.fill", iconColor: .blue,
            title: "Bench/Start Recommendations",
            description: "Visual indicators throughout Lineup RX showing which players to bench (red down arrow) and which to start (green up arrow). Based on projections and matchup analysis.",
            badge: nil
        ),
        FeatureData(
            icon: "square.stack.3d.up.fill", iconColor: .purple,
            title: "Waiver Wire Targets",
            description: "Grouped by player to drop, shows multiple waiver wire add options for each. Displays projected point improvement, opponent rank, and reasoning for each recommendation.",
            badge: nil
        ),
        FeatureData(
            icon: "number.circle.fill", iconColor: .cyan,
            title: "Week Selector",
            description: "Global week picker that lets you change which NFL week you're viewing. Works across all tabs - Mission Control, Schedule, Live Players, and Lineup RX.",
            badge: nil
        ),
        FeatureData(
            icon: "arrow.triangle.2.circlepath", iconColor: .gpGreen,
            title: "Auto-Refresh Timers",
            description: "Countdown timers showing when data will refresh. Color changes from green (fresh) to red (stale). Tap to manually refresh at any time.",
            badge: nil
        ),
        FeatureData(
            icon: "link.circle.fill", iconColor: .gpBlue,
            title: "External App Links",
            description: "Direct links to launch Sleeper app or ESPN website from any matchup card. Opens the specific league for quick lineup changes.",
            badge: nil
        ),
        FeatureData(
            icon: "icloud.fill", iconColor: .gray,
            title: "Multi-Platform Support",
            description: "Connect both ESPN and Sleeper accounts. View all leagues in one place with unified interface, regardless of platform.",
            badge: nil
        ),
        FeatureData(
            icon: "sportscourt.fill", iconColor: .orange,
            title: "Team Logos",
            description: "NFL team logos displayed throughout the app for visual identification. Shows team branding on player cards, matchup info, and roster views.",
            badge: nil
        ),
        FeatureData(
            icon: "house.fill", iconColor: .green,
            title: "Home/Away Indicators",
            description: "Shows whether players are home or away with 'vs' or '@' notation. Helps assess matchup context for lineup decisions.",
            badge: nil
        ),
        FeatureData(
            icon: "person.2.fill", iconColor: .blue,
            title: "War Room",
            description: "Draft preparation hub with player rankings, mock draft tools, and keeper league management. Access draft boards and strategy guides.",
            badge: nil
        ),
        FeatureData(
            icon: "list.bullet.clipboard", iconColor: .cyan,
            title: "Interactive Draft Board",
            description: "Live draft tracking showing picks in real-time. Filter by position, view team needs, and track your draft strategy as picks are made.",
            badge: nil
        ),
        FeatureData(
            icon: "bell.fill", iconColor: .yellow,
            title: "Status Badges",
            description: "Visual indicators throughout the app showing player status (injured, bye, playing, locked). Color-coded for quick recognition.",
            badge: nil
        ),
        FeatureData(
            icon: "circle.hexagongrid.fill", iconColor: .cyan,
            title: "Loading Screens",
            description: "Progress indicators with color transitions (red to green) during data loading. Shows loading status and prevents blank screens.",
            badge: nil
        )
    ]
    
    // MARK: - Badge Color Dictionary (replaces massive switch statement)
    private let badgeColors: [String: Color] = [
        "AI": .purple,
        "LIVE": .red,
        "NEW": .gpGreen
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                foxStyleBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Header
                        headerSection
                        
                        // Data-Driven Features List
                        featuresSection
                    }
                    .padding(.bottom, 100) // Extra space for tab bar
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    // MARK: - Background
    private var foxStyleBackground: some View {
        Image("BG2")
            .resizable()
            .aspectRatio(contentMode: .fill)
            .opacity(0.4)
            .ignoresSafeArea(.all)
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.gpPostBot)
                
                Text("BigWarRoom Features")
                    .font(.system(size: 32, weight: .bold, design: .default))
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Complete feature reference")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                
                Text("Version: \(AppConstants.getVersion())")
				  .font(.system(size: 12, weight: .regular))
				  .italic()
				  .foregroundColor(.white.opacity(0.6))
            }
            .padding(.leading, 40)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 24)
    }
    
    // MARK: - Features Section
    private var featuresSection: some View {
        VStack(spacing: 16) {
            ForEach(features) { feature in
                FeatureCard(
                    icon: feature.icon,
                    iconColor: feature.iconColor,
                    title: feature.title,
                    description: feature.description,
                    badge: feature.badge,
                    badgeColor: getBadgeColor(for: feature.badge)
                )
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Helper Methods
    private func getBadgeColor(for badge: String?) -> Color {
        guard let badge = badge else { return .gpPostBot }
        return badgeColors[badge] ?? .gpPostBot
    }
}

// MARK: - Feature Data Model
struct FeatureData: Identifiable {
    let id = UUID()
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let badge: String?
}

// MARK: - Updated Feature Card Component
struct FeatureCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let badge: String?
    let badgeColor: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Icon
            VStack {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(iconColor)
                    .frame(width: 32, height: 32)
                
                Spacer()
            }
            
            // Content
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Badge
                    if let badge = badge {
                        Text(badge)
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(.black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(badgeColor)
                            )
                    }
                }
                
                Text(description)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                    .lineSpacing(2)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            iconColor.opacity(0.1),
                            iconColor.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }
}

#Preview("Features View") {
    FeaturesView()
        .preferredColorScheme(.dark)
}
