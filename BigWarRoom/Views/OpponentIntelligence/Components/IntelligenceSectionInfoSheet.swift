//
//  IntelligenceSectionInfoSheet.swift
//  BigWarRoom
//
//  Info sheet for Intelligence dashboard sections
//

import SwiftUI

struct IntelligenceSectionInfoSheet: View {
    let sectionType: IntelligenceSectionType
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                foxStyleBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header
                        headerSection
                        
                        // Main content
                        contentSection
                        
                        // Example section if applicable
                        if let example = sectionType.example {
                            exampleSection(example)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                    .fontWeight(.semibold)
                }
            }
        }
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: sectionType.icon)
                    .font(.system(size: 32))
                    .foregroundColor(sectionType.color)
                
                Text(sectionType.title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            Text(sectionType.tldr)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(sectionType.color.opacity(0.9))
                .padding(.leading, 40)
        }
        .padding(.top, 20)
    }
    
    // MARK: - Content Section
    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What This Section Does")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            Text(sectionType.description)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .lineSpacing(4)
            
            if !sectionType.keyFeatures.isEmpty {
                Text("Key Features")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.top, 8)
                
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(sectionType.keyFeatures, id: \.self) { feature in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(sectionType.color)
                                .padding(.top, 2)
                            
                            Text(feature)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                                .lineSpacing(2)
                        }
                    }
                }
            }
            
            if let strategy = sectionType.strategicValue {
                Text("Strategic Value")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.top, 8)
                
                Text(strategy)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .lineSpacing(4)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(sectionType.color.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Example Section
    private func exampleSection(_ example: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Example")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            
            Text(example)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .lineSpacing(3)
                .italic()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(sectionType.color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(sectionType.color.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Intelligence Section Types

enum IntelligenceSectionType: CaseIterable {
    case injuryAlerts
    case gameAlerts
    case criticalThreatAlerts
    case threatMatrix
    case playerConflicts
    case allOpponentPlayers
    
    
    private static let sectionData: [IntelligenceSectionType: IntelligenceSectionConfig] = [
        .injuryAlerts: IntelligenceSectionConfig(
            title: "Player Injury Alerts",
            icon: "cross.case.fill",
            color: .red,
            tldr: "Shows YOUR injured/questionable players across all leagues with instant 'FIX' buttons",
            description: "Real-time monitoring of YOUR players who are injured, on BYE, or questionable. This is the highest priority section because these issues cost you games if ignored. The system scans all your leagues and identifies players with status problems, then provides direct 'FIX' buttons to navigate to lineup changes.",
            keyFeatures: [
                "Multi-league injury tracking for same player",
                "BYE weeks, IR, Out, Doubtful, Questionable status",
                "Direct 'FIX' buttons to lineup management",
                "Priority-based alerting (starters vs bench)",
                "Real-time status updates"
            ],
            strategicValue: "Prevents automatic losses from injured players in starting lineups. Catching injury alerts early can be the difference between winning and losing close matchups.",
            example: "Josh Jacobs is QUESTIONABLE in 2 leagues: 'Crazy 8's' (STARTING) and 'Work League' (STARTING). Very unlikely to play - prepare backup."
        ),
        
        .gameAlerts: IntelligenceSectionConfig(
            title: "Game Alerts",
            icon: "bolt.circle.fill",
            color: .gpOrange,
            tldr: "Real-time alerts for the biggest scoring plays happening across your leagues",
            description: "Tracks the highest scoring play from each data refresh across all your leagues. When a player has a big scoring gain (like a long TD or multiple catches), it gets logged here as a 'Game Alert'. This helps you stay on top of which players are having explosive performances that might be affecting your matchups.",
            keyFeatures: [
                "Highest scoring play per refresh cycle",
                "Real-time point delta tracking",
                "Player and league identification",
                "Time-stamped alert history",
                "Session-based storage (up to 50 alerts)"
            ],
            strategicValue: "Provides real-time awareness of explosive plays happening across your leagues. Helps identify which players are having breakout performances and might affect your matchups or future lineup decisions.",
            example: "Ja'Marr Chase (WR, CIN) scored +18.32 points in Main League (2 minutes ago) - likely an 80-yard touchdown!"
        ),
        
        .criticalThreatAlerts: IntelligenceSectionConfig(
            title: "Critical Threat Alerts",
            icon: "exclamationmark.triangle.fill",
            color: .orange,
            tldr: "AI recommendations for immediate lineup changes and strategic moves",
            description: "Strategic recommendations and warnings based on current game state. The AI analyzes your matchups and provides specific, actionable advice like 'Start Player X' or 'Bench Player Y'. These recommendations consider opponent strengths, your weaknesses, and real-time game flow.",
            keyFeatures: [
                "AI-powered strategic recommendations",
                "Priority-based alerting system",
                "Lineup optimization suggestions",
                "Opportunity identification",
                "Game flow analysis integration"
            ],
            strategicValue: "Provides tactical advantage by highlighting immediate actions you should take.",
            example: "CRITICAL: Start Jayden Daniels over Dak Prescott in 'Main League' - better matchup and higher ceiling needed to catch up."
        ),
        
        .threatMatrix: IntelligenceSectionConfig(
            title: "Threat Matrix",
            icon: "target",
            color: .purple,
            tldr: "Visual war room showing how badly each opponent is beating you right now",
            description: "Analyzes each opponent team across all your leagues and assigns threat levels from Critical (red) to Low (green). Shows your current score vs opponent score, players left to play, and identifies their top threat player. The visual hierarchy puts your worst matchups (where you're getting crushed) first.",
            keyFeatures: [
                "Color-coded threat levels (Critical to Low)",
                "Live score differentials",
                "Remaining players tracking",
                "Top threat player identification",
                "Multi-league matchup overview"
            ],
            strategicValue: "Gives you strategic situational awareness across all leagues. Helps prioritize which matchups need attention and where you're in trouble.",
            example: "DharokObama (MEDIUM threat) - You: 45.2, Them: 52.1, 3 players to play. Top threat: Lamar Jackson (24.8 pts)."
        ),
        
        .playerConflicts: IntelligenceSectionConfig(
            title: "Player Conflicts",
            icon: "scale.3d",
            color: .yellow,
            tldr: "Spots when you own Player X in League A but face him in League B - strategic nightmare resolver",
            description: "Identifies strategic dilemmas when you own the same player in one league but face them in another. The system calculates net impact across leagues to help you decide whether to start/sit conflicted players. It also spots when multiple opponents across leagues own the same player.",
            keyFeatures: [
                "Cross-league conflict detection",
                "Net impact calculation",
                "Strategic recommendations",
                "Multiple opponent tracking",
                "Conflict severity assessment"
            ],
            strategicValue: "Resolves complex strategic decisions when same players appear across multiple leagues. Maximizes your overall win probability rather than optimizing individual leagues.",
            example: "You own Saquon Barkley in 'Dynasty League' (+15.2 pts) but face him in 'Redraft League' (-15.2 pts). Net impact: 0.0 - neutral conflict."
        ),
        
        .allOpponentPlayers: IntelligenceSectionConfig(
            title: "All Opponent Players",
            icon: "person.2.fill",
            color: .blue,
            tldr: "Every single player on every opponent roster, ranked by how much they're destroying you",
            description: "Comprehensive view of every player on every opponent roster across all your leagues. Players are ranked by threat level, current performance, and potential impact. You can filter by position, add players to your watch list, and get detailed threat assessments for each opponent player.",
            keyFeatures: [
                "Comprehensive opponent player detail",
                "Threat level rankings",
                "Position filtering",
                "Watch list integration",
                "Performance tracking"
            ],
            strategicValue: "Intelligence gathering on opponent assets. Know which players to fear, which are underperforming, and identify potential trade targets.",
            example: "Lamar Jackson (Ravens QB) - 24.8 pts, EXPLOSIVE threat, owned by 3 opponents across your leagues. Add to watch list?"
        )
    ]
    
    var title: String { Self.sectionData[self]?.title ?? "Unknown" }
    var icon: String { Self.sectionData[self]?.icon ?? "questionmark" }
    var color: Color { Self.sectionData[self]?.color ?? .gray }
    var tldr: String { Self.sectionData[self]?.tldr ?? "" }
    var description: String { Self.sectionData[self]?.description ?? "" }
    var keyFeatures: [String] { Self.sectionData[self]?.keyFeatures ?? [] }
    var strategicValue: String? { Self.sectionData[self]?.strategicValue }
    var example: String? { Self.sectionData[self]?.example }
}

// MARK: - Intelligence Section Configuration

struct IntelligenceSectionConfig {
    let title: String
    let icon: String
    let color: Color
    let tldr: String
    let description: String
    let keyFeatures: [String]
    let strategicValue: String?
    let example: String?
}

#Preview("Injury Alerts Info") {
    IntelligenceSectionInfoSheet(sectionType: .injuryAlerts)
        .preferredColorScheme(.dark)
}