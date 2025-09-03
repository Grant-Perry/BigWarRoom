//
//  FantasyMatchupDetailView.swift
//  BigWarRoom
//
//  Detailed view for a specific fantasy matchup showing active rosters - EXACT SleepThis Match
//
// MARK: -> Fantasy Matchup Detail View

import SwiftUI

struct FantasyMatchupDetailView: View {
    let matchup: FantasyMatchup
    @ObservedObject var fantasyViewModel: FantasyViewModel
    let leagueName: String
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        let awayTeamScore = fantasyViewModel.getScore(for: matchup, teamIndex: 0)
        let homeTeamScore = fantasyViewModel.getScore(for: matchup, teamIndex: 1)
        let awayTeamIsWinning = awayTeamScore > homeTeamScore
        let homeTeamIsWinning = homeTeamScore > awayTeamScore
        
        VStack(spacing: 0) {
            // Header with back button
            HStack {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.gray.opacity(0.2))
                        .clipShape(Circle())
                }
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            Text("Matchup Details")
                .font(.title2)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top, 8)
            
            FantasyDetailHeaderView(
                leagueName: leagueName,
                matchup: matchup,
                awayTeamIsWinning: awayTeamIsWinning,
                homeTeamIsWinning: homeTeamIsWinning,
                fantasyViewModel: fantasyViewModel
            )
            .frame(height: 140)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            ScrollView {
                VStack(spacing: 16) {
                    fantasyViewModel.activeRosterSection(matchup: matchup)
                    fantasyViewModel.benchSection(matchup: matchup)
                }
                .padding(.top, 8)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
        }
        .navigationBarHidden(true)
        .preferredColorScheme(.dark)
        .background(Color.black)
    }
}

// MARK: -> Fantasy Detail Header View
struct FantasyDetailHeaderView: View {
    let leagueName: String
    let matchup: FantasyMatchup
    let awayTeamIsWinning: Bool
    let homeTeamIsWinning: Bool
    @ObservedObject var fantasyViewModel: FantasyViewModel
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [.clear, .purple.opacity(0.2)]),
                startPoint: .bottom,
                endPoint: .top
            )
            .frame(height: 80)
            
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.2))
            
            VStack(spacing: 4) {
                Text(leagueName)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .padding(.top, 4)
                
                HStack(spacing: 16) {
                    // Away team (left side)
                    FantasyManagerDetails(
                        managerName: matchup.awayTeam.ownerName,
                        managerRecord: fantasyViewModel.getManagerRecord(managerID: matchup.awayTeam.id),
                        score: matchup.awayTeam.currentScore ?? 0.0,
                        isWinning: awayTeamIsWinning,
                        avatarURL: matchup.awayTeam.avatarURL,
                        fantasyViewModel: fantasyViewModel,
                        rosterID: matchup.awayTeam.rosterID,
                        selectedYear: Int(fantasyViewModel.selectedYear) ?? 2024
                    )
                    
                    VStack(spacing: 2) {
                        Text("VS")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.gray)
                        
                        Text("Week \(fantasyViewModel.selectedWeek)")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                        
                        Text(fantasyViewModel.scoreDifferenceText(matchup: matchup))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.gpGreen)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.black.opacity(0.2))
                            )
                    }
                    .padding(.vertical, 2)
                    
                    // Home team (right side)
                    FantasyManagerDetails(
                        managerName: matchup.homeTeam.ownerName,
                        managerRecord: fantasyViewModel.getManagerRecord(managerID: matchup.homeTeam.id),
                        score: matchup.homeTeam.currentScore ?? 0.0,
                        isWinning: homeTeamIsWinning,
                        avatarURL: matchup.homeTeam.avatarURL,
                        fantasyViewModel: fantasyViewModel,
                        rosterID: matchup.homeTeam.rosterID,
                        selectedYear: Int(fantasyViewModel.selectedYear) ?? 2024
                    )
                }
                .padding(.horizontal)
                .padding(.bottom, 4)
            }
        }
    }
}

// MARK: -> Fantasy Manager Details
struct FantasyManagerDetails: View {
    let managerName: String
    let managerRecord: String
    let score: Double
    let isWinning: Bool
    let avatarURL: URL?
    var fantasyViewModel: FantasyViewModel? = nil
    var rosterID: Int? = nil
    let selectedYear: Int
    
    @State private var showStatsPopup = false
    
    var body: some View {
        VStack(spacing: 4) {
            // Avatar section
            ZStack {
                if let url = avatarURL {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                    } placeholder: {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .frame(width: 40, height: 40)
                            .foregroundColor(.gray)
                    }
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .frame(width: 40, height: 40)
                        .foregroundColor(.gray)
                }
                
                if isWinning {
                    Circle()
                        .strokeBorder(Color.gpGreen, lineWidth: 2)
                        .frame(width: 44, height: 44)
                }
            }
            
            // Manager name
            Text(managerName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.yellow)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            // Record
            Text(managerRecord)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.gray)
            
            // Score with winning color
            Text(String(format: "%.2f", score))
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(isWinning ? .gpGreen : .red)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: -> Fantasy Player Card (Exact SleepThis Match)
struct FantasyPlayerCard: View {
    let player: FantasyPlayer
    let fantasyViewModel: FantasyViewModel
    
    @State private var teamColor: Color = .gray
    @State private var nflPlayer: NFLPlayer?
    var isActive: Bool = true
    
    var body: some View {
        VStack {
            ZStack(alignment: .topLeading) {
                VStack {
                    HStack {
                        Spacer()
                        ZStack(alignment: .topTrailing) {
                            Text(nflPlayer?.jersey ?? player.jerseyNumber ?? "")
                                .font(.system(size: 85, weight: .bold))
                                .italic()
                                .foregroundColor(teamColor)
                                .opacity(0.7)
                        }
                    }
                    .padding(.trailing, 8)
                    Spacer()
                }
                
                RoundedRectangle(cornerRadius: 15)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [teamColor, .clear]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                // Team logo
                if let team = player.team {
                    AsyncImage(url: getTeamLogoURL(for: team)) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        case .failure:
                            Image(systemName: "sportscourt.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(width: 80, height: 80)
                    .offset(x: 20, y: -4)
                    .opacity(0.6)
                    .shadow(color: teamColor.opacity(0.5), radius: 10, x: 0, y: 0)
                }
                
                HStack(spacing: 12) {
                    // Player headshot
                    AsyncImage(url: player.headshotURL) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 95, height: 95)
                                .clipped()
                        case .failure:
                            Image(systemName: "person.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 95, height: 95)
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .offset(x: -20, y: -5)
                    .zIndex(2)
                    
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(player.position)
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.8))
                            .offset(x: -5, y: 45)
                        
                        Spacer()
                        
                        HStack(alignment: .bottom, spacing: 4) {
                            Spacer()
                            Text(player.currentPointsString)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.95)
                                .scaledToFit()
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .offset(y: -9)
                    }
                    .padding(.vertical, 8)
                    .padding(.trailing, 8)
                    .zIndex(3)
                }
                
                // Player name
                Text(player.fullName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.top, 16)
                    .padding(.trailing, 14)
                    .padding(.leading, 45)
                    .zIndex(4)
                
                // Game matchup info (DEN vs. SEA style)
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        FantasyGameMatchupView(player: player)
                            .padding(EdgeInsets(top: 8, leading: 0, bottom: 22, trailing: 42))
                    }
                }
                .offset(x: -12, y: -2)
                .zIndex(5)
            }
            .frame(height: 90)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.black)
                    .shadow(color: isActive ? .gpGreen.opacity(0.5) : .clear, radius: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(Color.gray, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 15))
        }
        .task {
            // Set team color based on NFL team
            if let team = player.team {
                teamColor = NFLTeamColors.color(for: team)
            }
        }
    }
    
    private func getTeamLogoURL(for team: String) -> URL? {
        // NFL team logo URLs
        return URL(string: "https://a.espncdn.com/i/teamlogos/nfl/500/\(team.lowercased()).png")
    }
}

// MARK: -> Game Matchup View (DEN vs. SEA style)
struct FantasyGameMatchupView: View {
    let player: FantasyPlayer
    
    var body: some View {
        VStack(spacing: 1) {
            // NFL matchup (e.g., "DEN vs. SEA")
            if let team = player.team {
                Text("\(team) vs. \(getOpponentTeam(for: team))")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.gray.opacity(0.8))
                    )
            }
            
            // Game status (e.g., "2nd 14:32")
            if let gameStatus = player.gameStatus {
                Text(gameStatus.timeString)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(gameStatusColor(gameStatus.status))
                    )
            }
        }
    }
    
    private func gameStatusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "live": return .red
        case "pregame": return .orange
        case "postgame", "final": return .gray
        case "bye": return .purple
        default: return .gray
        }
    }
    
    private func getOpponentTeam(for team: String) -> String {
        // Mock opponent mapping - in real app, fetch from NFL schedule API
        let opponents = [
            "DEN": "SEA", "SEA": "DEN", "KC": "LV", "LV": "KC", 
            "BUF": "MIA", "MIA": "BUF", "NYJ": "NE", "NE": "NYJ",
            "DAL": "NYG", "NYG": "DAL", "WSH": "PHI", "PHI": "WSH"
        ]
        return opponents[team] ?? "TBD"
    }
}

// MARK: -> NFLPlayer Model (Simplified)
struct NFLPlayer {
    let jersey: String
    let team: String
}