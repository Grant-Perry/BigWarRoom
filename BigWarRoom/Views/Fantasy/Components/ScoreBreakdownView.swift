//
//  ScoreBreakdownView.swift
//  BigWarRoom
//
//  Score breakdown popup view for fantasy players
//

import SwiftUI

struct ScoreBreakdownView: View {
    let breakdown: PlayerScoreBreakdown
    @Environment(\.dismiss) private var dismiss

    // Get team color for gradient styling
    private var teamColor: Color {
        if let team = breakdown.player.team {
            return NFLTeamColors.color(for: team)
        }
        return .blue
    }
    
    private var backgroundGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                teamColor.opacity(0.8),
                teamColor.opacity(0.6),
                Color.black.opacity(0.7),
                Color(red: 0.15, green: 0.18, blue: 0.25).opacity(0.9)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var borderGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                teamColor.opacity(0.9),
                teamColor.opacity(0.7),
                Color.white.opacity(0.3),
                teamColor.opacity(0.8)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // Score color based on performance
    private var scoreColor: Color {
        let score = breakdown.totalScore
        // Consider 15+ points as "good" performance
        return score >= 15.0 ? .gpGreen : .gpRedPink
    }
    
    // Position color
    private var positionColor: Color {
        switch breakdown.player.position.uppercased() {
        case "QB": return .blue
        case "RB": return .green
        case "WR": return .purple
        case "TE": return .orange
        case "K": return .yellow
        case "DEF": return .red
        default: return .gray
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }
            VStack(spacing: 0) {
                headerSection
                if breakdown.hasStats {
                    ScrollView(.vertical, showsIndicators: true) {
                        statsTableSection
                    }
                    .frame(maxHeight: 400)
                } else {
                    noStatsSection
                }
                // NOTICE section styled like the Fantasy Points row, but now a disclaimer
                noticeSection
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(backgroundGradient)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(borderGradient, lineWidth: 2)
                    )
            )
            .padding(.horizontal, 24)
            .shadow(color: teamColor.opacity(0.3), radius: 20, x: 0, y: 10)
            .shadow(color: .black.opacity(0.5), radius: 15, x: 0, y: 8)
            
            // 🔥 UPDATED: Player image overlay on the left - properly clipped like the player card
            .overlay(
                HStack {
                    VStack {
                        AsyncImage(url: breakdown.player.headshotURL) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(breakdown.player.teamColor.opacity(0.3))
                                
                                Text(breakdown.player.position)
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                        .frame(width: 100, height: 130)
                        .scaleEffect(0.65)
                        .clipped()
                        .offset(x: 25, y: -10)
                        
                        Spacer()
                    }
                    
                    Spacer()
                    
                    // 🔥 UPDATED: Smaller score
                    VStack {
                        VStack(spacing: 6) {
                            // Smaller position badge
                               Text(breakdown.player.position.uppercased())
								   .font(.system(size: 10, weight: .bold))
								   .foregroundColor(.white)
								   .background(positionColor)
								   .clipShape(RoundedRectangle(cornerRadius: 6))
                            // Smaller score
                            Text(breakdown.totalScoreString)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(scoreColor)
                        }
                        .offset(x: -40, y: 35)
//                        .padding(.trailing, 40)
//                        .padding(.top, 100)
                        
                        Spacer()
                    }
                },
                alignment: .topLeading
            )
            .clipShape(RoundedRectangle(cornerRadius: 16)) // 🔥 MOVED: Apply clipShape to the entire modal structure
            
            // Close button, matches original
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(Color.black.opacity(0.7))
                                    .overlay(
                                        Circle()
                                            .stroke(borderGradient, lineWidth: 1)
                                    )
                            )
                    }
                    .padding(.trailing, 32)
                    .padding(.top, 8)
                }
                Spacer()
            }
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 12) {
            // Player name
            Text(breakdown.playerDisplayName)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            // League info with logo
            HStack(spacing: 8) {
                // League logo
                if let leagueContext = breakdown.leagueContext {
                    Image(leagueContext.source == .espn ? "espnLogo" : "sleeperLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 25, height: 25)
                }
                
                // League name (you'll need to pass this through)
                Text(breakdown.leagueName ?? "Unknown League")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
            }
            
            // Week info
            Text(breakdown.weekDisplayString)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.top, 20)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity)
        .background(
            Rectangle()
                .fill(Color.black.opacity(0.2))
        )
    }

    private var statsTableSection: some View {
        VStack(spacing: 0) {
            tableHeaderRow
            Rectangle()
                .fill(teamColor.opacity(0.6))
                .frame(height: 2)
            
            // 🔥 NEW: Add ScrollView for stats
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 0) {
                    ForEach(breakdown.items) { item in
                        statsRow(item: item)
                        if item.id != breakdown.items.last?.id {
                            Rectangle()
                                .fill(Color.white.opacity(0.1))
                                .frame(height: 0.5)
                        }
                    }
                }
            }
            .frame(maxHeight: 300) // Limit height so notice is always visible
        }
        .padding(.horizontal, 16)
    }

    private var tableHeaderRow: some View {
        HStack(spacing: 8) {
            Text("STAT")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("QTY")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 60, alignment: .center)
            if breakdown.hasRealScoringData {
                Text("PTS PER")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 70, alignment: .center)
                Text("POINTS")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 70, alignment: .trailing)
            }
        }
        .padding(.vertical, 12)
    }

    private func statsRow(item: ScoreBreakdownItem) -> some View {
        HStack(spacing: 8) {
            Text(item.statName)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(item.statValueString)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 60, alignment: .center)
            if breakdown.hasRealScoringData {
                Text(item.pointsPerStatString)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 70, alignment: .center)
                Text(item.totalPointsString)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 70, alignment: .trailing)
            }
        }
        .padding(.vertical, 12)
    }

    // MARK: - NOTICE Section (takes the place of the Fantasy Points row)
    private var noticeSection: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(teamColor.opacity(0.8))
                .frame(height: 3)
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CALCULATED BREAKDOWN")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Based on available stats and league scoring rules")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
                
                // Calculated vs Official comparison
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 8) {
                        Text("Calculated Total:")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                        Text("\(calculatedTotalString) pts")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    HStack(spacing: 8) {
                        Text("Drift:")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                        Text("\(deltaString) pts")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(deltaColor)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.3),
                    teamColor.opacity(0.1)
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }

    // MARK: - Calculated Total and Delta Properties
    
    /// Sum of all breakdown item points
    private var calculatedTotal: Double {
        breakdown.items.reduce(0) { $0 + $1.totalPoints }
    }
    
    /// Formatted calculated total string
    private var calculatedTotalString: String {
        return String(format: "%.2f", calculatedTotal)
    }
    
    /// Delta between calculated and official totals (from calculated perspective)
    private var delta: Double {
        return calculatedTotal - breakdown.totalScore
    }
    
    /// Formatted delta string with sign or bullseye for perfect match
    private var deltaString: String {
        if abs(delta) < 0.01 {
            return "🎯 0.00"
        } else {
            let deltaValue = abs(delta)
            let sign = delta >= 0 ? "+" : "-"
            return "\(sign)\(String(format: "%.2f", deltaValue))"
        }
    }
    
    /// Color for delta display - with animation for perfect matches
    private var deltaColor: Color {
        if abs(delta) < 0.01 {
		   return .gpMinty // Perfect match gets special color
        } else if delta > 0 {
            return .gpGreen // Positive delta = we're over-calculating
        } else {
            return .gpRedPink // Negative delta = we're missing points  
        }
    }

    private var noStatsSection: some View {
        VStack(spacing: 12) {
            Text("No stats available")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
            
            Text("This player hasn't recorded any stats yet this week")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
            
            // 🔥 NEW: Show player's next game or BYE status
            VStack(spacing: 8) {
                Text("\(breakdown.playerDisplayName) is playing:")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                
                gameStatusView
                    .scaleEffect(1.2) // Make it slightly larger for emphasis
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 32)
    }
    
    // 🔥 NEW: Game status view for no stats section
    private var gameStatusView: some View {
        Group {
            if let team = breakdown.player.team {
                if let gameInfo = NFLGameDataService.shared.getGameInfo(for: team) {
                    // Show actual game matchup
                    VStack(spacing: 4) {
                        Text(gameInfo.matchupString)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(teamColor.opacity(0.8))
                            )
                        
                        Text(gameInfo.formattedGameTime)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                    }
                } else {
                    // Show BYE week
                    Text("BYE")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(teamColor.opacity(0.8))
                        )
                }
            } else {
                // No team info available
                Text("Unknown Schedule")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }
}
