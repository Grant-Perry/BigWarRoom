//
//  PlayerStatsCardView.swift
//  BigWarRoom
//
//  Detailed player stats card with 2024 season data
//
// MARK: -> Player Stats Card

import SwiftUI

// MARK: -> Height Conversion Extension
extension String {
    /// Converts height from inches to feet and inches format
    /// E.g., "73" becomes "6' 1""
    var formattedHeight: String {
        // Check if already in feet/inches format
        if self.contains("'") || self.contains("\"") || self.contains("ft") {
            return self
        }
        
        // Try to convert from inches
        guard let totalInches = Int(self) else {
            return self // Return original if not a number
        }
        
        let feet = totalInches / 12
        let remainingInches = totalInches % 12
        
        if remainingInches == 0 {
            return "\(feet)'"
        } else {
            return "\(feet)' \(remainingInches)\""
        }
    }
}

struct PlayerStatsCardView: View {
    let player: SleeperPlayer
    let team: NFLTeam?
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var teamAssets = TeamAssetManager.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header with player image and basic info
                playerHeaderSection
                
                // Player Details from Sleeper
                playerDetailsSection
                
                // Fantasy Analysis based on search rank
                fantasyAnalysisSection
            }
            .padding()
        }
        .navigationTitle(player.shortName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: -> Header Section
    
    private var playerHeaderSection: some View {
        VStack(spacing: 16) {
            // Large player image with better loading
            PlayerImageView(
                player: player,
                size: 120,
                team: team
            )
            
            // Player info
            VStack(spacing: 8) {
                Text(player.fullName)
                    .font(.title2)
                    .fontWeight(.bold)
                
                HStack(spacing: 12) {
                    // Position badge
                    positionBadge
                    
                    // Team info
                    if let team = team {
                        HStack(spacing: 6) {
                            teamAssets.logoOrFallback(for: team.id)
                                .frame(width: 24, height: 24)
                            
                            Text(team.name)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Jersey number
                    if let number = player.number {
                        Text("#\(number)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
            
            // Additional info
            HStack(spacing: 20) {
                if let age = player.age {
                    infoItem("Age", "\(age)")
                }
                if let yearsExp = player.yearsExp {
                    infoItem("Exp", "Y\(yearsExp)")
                }
                if let height = player.height {
                    infoItem("Height", height.formattedHeight)
                }
                if let weight = player.weight {
                    infoItem("Weight", "\(weight) lbs")
                }
            }
            .font(.caption)
        }
        .padding()
        .background(teamBackgroundView)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: -> Player Details
    
    private var playerDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Player Information")
                .font(.headline)
            
            VStack(spacing: 12) {
                if let college = player.college {
                    detailRow("College", college)
                }
                
                if let height = player.height, let weight = player.weight {
                    detailRow("Size", "\(height.formattedHeight), \(weight) lbs")
                }
                
                if let yearsExp = player.yearsExp {
                    detailRow("Experience", "\(yearsExp) years")
                }
                
                if let searchRank = player.searchRank {
                    detailRow("Fantasy Rank", "#\(searchRank)")
                }
                
                if let depthChartPosition = player.depthChartPosition {
                    detailRow("Depth Chart", "Position \(depthChartPosition)")
                }
                
                if let injuryStatus = player.injuryStatus, !injuryStatus.isEmpty {
                    HStack {
                        Text("Injury Status")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(String(injuryStatus.prefix(5)))
                            .fontWeight(.semibold)
                            .foregroundColor(.red)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: -> Fantasy Analysis
    
    private var fantasyAnalysisSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Fantasy Analysis")
                .font(.headline)
            
            VStack(spacing: 12) {
                if let searchRank = player.searchRank {
                    let tier = calculateFantasyTier(searchRank: searchRank, position: player.position ?? "")
                    
                    fantasyRow("Search Rank", "#\(searchRank)", tierColor(tier))
                    fantasyRow("Fantasy Tier", "Tier \(tier)", tierColor(tier))
                    
                    Text(getTierDescription(tier: tier, position: player.position ?? ""))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
                
                // Position-specific analysis
                Text(getPositionAnalysis())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: -> Helper Functions
    
    private func calculateFantasyTier(searchRank: Int, position: String) -> Int {
        switch position.uppercased() {
        case "QB":
            if searchRank <= 12 { return 1 }
            if searchRank <= 24 { return 2 }
            if searchRank <= 36 { return 3 }
            return 4
        case "RB":
            if searchRank <= 24 { return 1 }
            if searchRank <= 48 { return 2 }
            if searchRank <= 84 { return 3 }
            return 4
        case "WR":
            if searchRank <= 36 { return 1 }
            if searchRank <= 72 { return 2 }
            if searchRank <= 120 { return 3 }
            return 4
        case "TE":
            if searchRank <= 12 { return 1 }
            if searchRank <= 24 { return 2 }
            if searchRank <= 36 { return 3 }
            return 4
        default:
            return 4
        }
    }
    
    private func getTierDescription(tier: Int, position: String) -> String {
        switch (tier, position.uppercased()) {
        case (1, "QB"): return "Elite QB1 - Weekly starter"
        case (2, "QB"): return "Solid QB1 - Reliable starter"
        case (3, "QB"): return "Streaming QB - Matchup dependent"
        case (1, "RB"): return "Elite RB1/2 - Every week starter"
        case (2, "RB"): return "Solid RB2/3 - Good starter"
        case (3, "RB"): return "Flex RB - Spot starter"
        case (1, "WR"): return "Elite WR1/2 - Must start"
        case (2, "WR"): return "Solid WR2/3 - Good starter" 
        case (3, "WR"): return "Flex WR - Depth play"
        case (1, "TE"): return "Elite TE - Set and forget"
        case (2, "TE"): return "Solid TE - Weekly starter"
        case (3, "TE"): return "Streaming TE - Matchup play"
        default: return "Deep bench / waiver wire"
        }
    }
    
    private func getPositionAnalysis() -> String {
        let pos = player.position?.uppercased() ?? ""
        let rank = player.searchRank ?? 999
        
        switch pos {
        case "QB":
            return "QB\(rank <= 12 ? "1" : rank <= 24 ? "2" : "3+") - Target in rounds \(rank <= 12 ? "6-8" : rank <= 24 ? "9-12" : "13+")"
        case "RB":
            return "RB\(rank <= 12 ? "1" : rank <= 36 ? "2" : "3+") - Target in rounds \(rank <= 24 ? "1-3" : rank <= 48 ? "4-6" : "7+")"
        case "WR":
            return "WR\(rank <= 18 ? "1" : rank <= 48 ? "2" : "3+") - Target in rounds \(rank <= 36 ? "1-4" : rank <= 72 ? "5-8" : "9+")"
        case "TE":
            return "TE\(rank <= 6 ? "1" : rank <= 18 ? "2" : "3+") - Target in rounds \(rank <= 12 ? "4-6" : rank <= 24 ? "7-10" : "11+")"
        default:
            return "Draft in later rounds based on team needs"
        }
    }

    // MARK: -> Helper Views
    
    private var playerFallbackImage: some View {
        Circle()
            .fill(team?.gradient ?? LinearGradient(colors: [.gray], startPoint: .top, endPoint: .bottom))
            .overlay(
                Text(player.firstName?.prefix(1).uppercased() ?? "?")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(team?.accentColor ?? .white)
            )
    }
    
    private var positionBadge: some View {
        Text(player.position ?? "")
            .font(.caption)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(positionColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var positionColor: Color {
        guard let position = player.position else { return .gray }
        
        switch position {
        case "QB": return .blue
        case "RB": return .green
        case "WR": return .purple
        case "TE": return .orange
        case "K": return .yellow
        case "DEF": return .red
        default: return .gray
        }
    }
    
    private var teamBackgroundView: some View {
        Group {
            if let team = team {
                RoundedRectangle(cornerRadius: 16)
                    .fill(team.backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(team.borderColor, lineWidth: 1)
                    )
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
            }
        }
    }
    
    private func infoItem(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .foregroundColor(.secondary)
            Text(value)
                .fontWeight(.medium)
        }
    }
    
    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
    }
    
    private func statsRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
    }
    
    private func fantasyRow(_ label: String, _ value: String, _ color: Color) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
    }
    
    private func tierColor(_ tier: Int) -> Color {
        switch tier {
        case 1: return .purple
        case 2: return .blue
        case 3: return .orange
        default: return .gray
        }
    }
}
//
//#Preview {
//    PlayerStatsCardView(
//        player: SleeperPlayer(
//            playerID: "wr-chase",
//            firstName: "Ja'Marr",
//            lastName: "Chase",
//            position: "WR",
//            team: "CIN",
//            number: 1,
//            status: "Active",
//            height: "73",
//            weight: "201",
//            age: 24,
//            college: "LSU",
//            yearsExp: 3,
//            fantasyPositions: ["WR"],
//            injuryStatus: nil,
//            depthChartOrder: 1,
//            depthChartPosition: 1,
//            searchRank: 5,
//            hashtag: "#JaMarrChase",
//            birthCountry: "United States",
//            espnID: 4362628,
//            yahooID: 32700,
//            rotowireID: 14885,
//            rotoworldID: 5479,
//            fantasyDataID: 21688,
//            sportradarID: "123",
//            statsID: 123
//        ),
//        team: NFLTeam.team(for: "CIN")
//    )
//}