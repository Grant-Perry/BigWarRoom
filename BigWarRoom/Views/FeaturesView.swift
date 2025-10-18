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
            description: "Track matchups across your Sleeper and ESPN leagues. View scores, projections, and win probabilities with color-coded borders and live updates.",
            badge: "LIVE"
        ),
        FeatureData(
            icon: "cross.case.fill", iconColor: .red,
            title: "Injury Status Tracking",
            description: "Monitor your players who are injured, on BYE, or questionable across all leagues. Shows which leagues are affected and provides navigation to make lineup changes.",
            badge: "HELPFUL"
        ),
        FeatureData(
            icon: "exclamationmark.triangle.fill", iconColor: .orange,
            title: "Strategic Recommendations",
            description: "Generates suggestions for lineup changes based on current matchup data. Analyzes opponent performance and game situations to provide actionable recommendations.",
            badge: "SUGGESTIONS"
        ),
        FeatureData(
            icon: "target", iconColor: .purple,
            title: "Opponent Analysis",
            description: "Visual overview of how your matchups are progressing. Shows score differentials, remaining players, and identifies which opponent players are performing well.",
            badge: "ANALYSIS"
        ),
        FeatureData(
            icon: "scale.3d", iconColor: .yellow,
            title: "Cross-League Conflict Detection",
            description: "Identifies when you own a player in one league but face them in another. Helps you understand the impact of player performance across multiple leagues.",
            badge: "DETECTION"
        ),
        FeatureData(
            icon: "person.2.fill", iconColor: .blue,
            title: "Opponent Player Database",
            description: "View all players on opponent rosters across your leagues. Filter by position and performance to track players that might impact your matchups.",
            badge: "DATABASE"
        ),
        FeatureData(
            icon: "chart.bar.fill", iconColor: .gpGreen,
            title: "All Rostered Players",
            description: "Track every player across all your leagues with live scoring, performance tiers, position filtering, and search. Sort by score, position, name, or team.",
            badge: "COMPREHENSIVE"
        ),
        FeatureData(
            icon: "calendar.circle.fill", iconColor: .blue,
            title: "NFL Schedule Integration",
            description: "View NFL schedule with live scores, game status, team logos, and betting lines. See which of your players are in active games.",
            badge: nil
        ),
        FeatureData(
            icon: "eye.fill", iconColor: .gpOrange,
            title: "Player Watch System",
            description: "Watch and track specific players across all leagues with live score updates and performance notifications.",
            badge: "TRACKING"
        ),
        FeatureData(
            icon: "magnifyingglass.circle.fill", iconColor: .gpBlue,
            title: "Player Search",
            description: "Search all NFL players or just your rostered players with name matching, position filtering, and results from the player database.",
            badge: "SEARCH"
        ),
        FeatureData(
            icon: "circle.hexagongrid.fill", iconColor: .cyan,
            title: "Centralized Loading System",
            description: "Loading screens with progress indicators that change color from red to green. Data loads upfront for quick tab switching.",
            badge: "EFFICIENT"
        ),
        FeatureData(
            icon: "arrow.clockwise.circle.fill", iconColor: .gpGreen,
            title: "Refresh Timers",
            description: "Countdown timers show when data will refresh next. Color changes from green when fresh to red when updates are due.",
            badge: "VISUAL"
        ),
        FeatureData(
            icon: "percent", iconColor: .gpGreen,
            title: "Win Probability Display",
            description: "Shows win percentage estimates on matchup cards with color coding for quick assessment of matchup status.",
            badge: "PROBABILITY"
        ),
        FeatureData(
            icon: "person.2.fill", iconColor: .orange,
            title: "War Room",
            description: "Draft preparation and league management tools. Research players, track draft picks, and manage roster strategy.",
            badge: nil
        ),
        FeatureData(
            icon: "list.bullet.clipboard", iconColor: .cyan,
            title: "Interactive Draft Board",
            description: "Visual draft tracking with player rankings, position needs, and real-time pick updates for following draft progress.",
            badge: nil
        ),
        FeatureData(
            icon: "clock.fill", iconColor: .red,
            title: "Live Draft Picks",
            description: "Real-time draft pick notifications and updates. Track selections as they happen across your leagues.",
            badge: "LIVE"
        ),
        FeatureData(
            icon: "textformat.size", iconColor: .blue,
            title: "Responsive Text Scaling",
            description: "Text automatically scales to fit available space with line limits and minimum scale factors to prevent cutoff issues.",
            badge: "RESPONSIVE"
        ),
        FeatureData(
            icon: "keyboard.fill", iconColor: .gray,
            title: "Keyboard Handling",
            description: "Search bars stay properly positioned when keyboard appears, with auto-focus and proper safe area handling.",
            badge: "UX"
        ),
        FeatureData(
            icon: "link.circle.fill", iconColor: .gpBlue,
            title: "External App Integration",
            description: "Direct links to launch Sleeper app or ESPN website for making lineup changes. Integrates with your existing fantasy workflow.",
            badge: "INTEGRATION"
        ),
        FeatureData(
            icon: "icloud.fill", iconColor: .gray,
            title: "Multi-Platform Support",
            description: "Works with both ESPN and Sleeper platforms. Combines data from multiple leagues in a unified interface.",
            badge: "UNIVERSAL"
        ),
        FeatureData(
            icon: "server.rack", iconColor: .green,
            title: "Centralized Data Management",
            description: "Single interface for all fantasy data with caching, background updates, and coordinated loading across app features.",
            badge: "ORGANIZED"
        ),
        FeatureData(
            icon: "bell.fill", iconColor: .yellow,
            title: "Status Notifications",
            description: "Visual indicators for scoring plays, injury updates, and lineup changes. Contextual badges and alerts keep you informed.",
            badge: "NOTIFICATIONS"
        )
    ]
    
    // MARK: - Badge Color Dictionary (replaces massive switch statement)
    private let badgeColors: [String: Color] = [
        "NEW": .gpGreen,
        "LIVE": .red,
        "SMART": .purple,
        "AUTO": .blue,
        "UNIVERSAL": .orange,
        "CRITICAL": .red,
        "ENHANCED": .gpGreen,
        "POWERFUL": .gpBlue,
        "SMOOTH": .cyan,
        "VISUAL": .gpOrange,
        "IMPROVED": .gpGreen,
        "POLISHED": .blue,
        "UX": .purple,
        "INTEGRATION": .gpBlue,
        "ARCHITECTURE": .green,
        "HELPFUL": .gpPostBot,
        "SUGGESTIONS": .gpPostBot,
        "ANALYSIS": .gpPostBot,
        "DETECTION": .gpPostBot,
        "DATABASE": .gpPostBot,
        "COMPREHENSIVE": .gpPostBot,
        "TRACKING": .gpPostBot,
        "SEARCH": .gpPostBot,
        "EFFICIENT": .gpPostBot,
        "PROBABILITY": .gpPostBot,
        "RESPONSIVE": .gpPostBot,
        "ORGANIZED": .gpPostBot,
        "NOTIFICATIONS": .gpPostBot
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
            
            Text("Your complete fantasy football command center")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
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