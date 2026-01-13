//
//  GameDetailSheet.swift
//  BigWarRoom
//
//  Displays detailed information for a playoff game
//

import SwiftUI

struct GameDetailSheetContent: View {
    @Environment(TeamAssetManager.self) private var teamAssets
    let game: PlayoffGame
    let odds: GameBettingOdds?
    
    var body: some View {
        // Content
        ScrollView {
            VStack(spacing: 20) {
                // Matchup Card (like weeks 1-18)
                matchupCard
                
                // Details Card
                gameDetailsCard
            }
            .padding()
        }
    }
    
    private var matchupCard: some View {
        let awayColor = NFLTeam.team(for: game.awayTeam.abbreviation)?.primaryColor ?? .blue
        let homeColor = NFLTeam.team(for: game.homeTeam.abbreviation)?.primaryColor ?? .red
        
        return VStack(spacing: 0) {
            // Away Team Section
            HStack(spacing: 8) {
                // Away team logo (zoomed & clipped)
                ZStack(alignment: .bottomTrailing) {
                    if let logo = teamAssets.logo(for: game.awayTeam.abbreviation) {
                        logo
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .scaleEffect(1.5)
                            .frame(width: 90, height: 90)
                            .clipped()
                            .cornerRadius(8)
                    }
                    
                    // Seed badge
                    if let seed = game.awayTeam.seed {
                        Text("#\(seed)")
                            .font(.system(size: 12, weight: .black))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.black.opacity(0.85)))
                            .padding(3)
                    }
                }
                
                // Away team name
                Text(game.awayTeam.abbreviation)
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(.white)
                
                Spacer()
                
                // Away score (if available)
                if let score = game.awayTeam.score {
                    Text("\(score)")
                        .font(.system(size: 28, weight: .black))
                        .foregroundStyle(.white)
                        .padding(.trailing, 8)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .background(awayColor)
            
            // Center section with date/time
            VStack(spacing: 4) {
                if game.status.isCompleted {
                    Text("FINAL")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(.white)
                } else {
                    Text(game.formattedDate.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.9))
                    
                    Text(game.formattedTime)
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(.white)
                }
            }
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(Color(.systemGray5))
            
            // Home Team Section
            HStack(spacing: 8) {
                // Home team logo (zoomed & clipped)
                ZStack(alignment: .bottomTrailing) {
                    if let logo = teamAssets.logo(for: game.homeTeam.abbreviation) {
                        logo
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .scaleEffect(1.5)
                            .frame(width: 90, height: 90)
                            .clipped()
                            .cornerRadius(8)
                    }
                    
                    // Seed badge
                    if let seed = game.homeTeam.seed {
                        Text("#\(seed)")
                            .font(.system(size: 12, weight: .black))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.black.opacity(0.85)))
                            .padding(3)
                    }
                }
                
                // Home team name
                Text(game.homeTeam.abbreviation)
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(.white)
                
                Spacer()
                
                // Home score (if available)
                if let score = game.homeTeam.score {
                    Text("\(score)")
                        .font(.system(size: 28, weight: .black))
                        .foregroundStyle(.white)
                        .padding(.trailing, 8)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .background(homeColor)
        }
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.3), radius: 8)
    }
    
    private var gameDetailsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 🏈 NEW: Live game situation (down, distance, possession)
            if game.isLive, let situation = game.liveSituation {
                liveGameSituationRow(situation: situation)
                Divider()
            }
            
            // Only show venue/broadcasts for non-live games
            if !game.isLive {
                if let venue = game.venue {
                    detailRow(icon: "building.2.fill", title: "Stadium", value: venue.displayName)
                    Divider()
                }
                
                if let broadcasts = game.broadcasts, !broadcasts.isEmpty {
                    detailRow(icon: "tv.fill", title: "Network", value: broadcasts.joined(separator: ", "))
                    Divider()
                }
            }
            
            // Odds section
            if let odds = odds {
                oddsRow(odds: odds)
                Divider()
            } else if game.status == .scheduled {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "dollarsign.circle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Betting Odds")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Text("Not yet available")
                            .font(.caption)
                            .foregroundStyle(.secondary.opacity(0.7))
                    }
                    
                    Spacer()
                }
                Divider()
            }
            
            detailRow(icon: "clock.fill", title: "Status", value: game.status.displayText)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
    
    private func detailRow(icon: String, title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Text(value)
                    .font(.body)
                    .fontWeight(.medium)
            }
            
            Spacer()
        }
    }
    
    private func oddsRow(odds: GameBettingOdds) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "dollarsign.circle.fill")
                .font(.title3)
                .foregroundStyle(.green)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Betting Odds")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                VStack(alignment: .leading, spacing: 6) {
                    // Spread
                    if let spread = odds.spreadDisplay {
                        HStack(spacing: 6) {
                            Text("Spread:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(spread)
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                    }
                    
                    // Total
                    if let total = odds.totalDisplay {
                        HStack(spacing: 6) {
                            Text("Total:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(total)
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                    }
                    
                    // Moneyline
                    if let favTeam = odds.favoriteMoneylineTeamCode,
                       let favOdds = odds.favoriteMoneylineOdds {
                        HStack(spacing: 6) {
                            Text("Favorite:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(favTeam) \(favOdds)")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.green)
                        }
                    }
                    
                    // Sportsbook
                    if let book = odds.sportsbookEnum {
                        HStack(spacing: 4) {
                            Text("via")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            SportsbookBadge(book: book, size: 9)
                        }
                    }
                }
            }
            
            Spacer()
        }
    }
    
    // 🏈 NEW: Live game situation display
    private func liveGameSituationRow(situation: LiveGameSituation) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: "football.circle")
                    .font(.title3)
                    .foregroundStyle(.red)
                    .frame(width: 24)
                
                Text("Live Game Situation")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                
                Spacer()
            }
            
            // Possession indicator with football icon
            if let possession = situation.possession {
                HStack(spacing: 8) {
                    Text("🏈")
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Possession")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text(possession)
                            .font(.body)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.tertiarySystemGroupedBackground))
                .cornerRadius(8)
            }
            
            // HARDCODED TEST - ALWAYS SHOW
            VStack(alignment: .leading, spacing: 8) {
                Text("🔥 HARDCODED TEST")
                    .font(.caption)
                    .foregroundStyle(.red)
                
                FieldPositionView(
                    yardLine: "HOU 39",
                    awayTeam: "HOU",
                    homeTeam: "PIT"
                )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.red.opacity(0.2))
            .cornerRadius(8)
            
            // Drive stats
            if situation.drivePlayCount != nil || situation.driveYards != nil || situation.timeOfPossession != nil {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Current Drive")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 16) {
                        if let plays = situation.drivePlayCount {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(plays)")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                Text("Plays")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        if let yards = situation.driveYards {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(yards)")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                Text("Yards")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        if let top = situation.timeOfPossession {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(top)
                                    .font(.title3)
                                    .fontWeight(.bold)
                                Text("TOP")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        Spacer()
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.tertiarySystemGroupedBackground))
                .cornerRadius(8)
            }
            
            // Last play description
            if let lastPlay = situation.lastPlay {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Last Play")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(lastPlay)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.tertiarySystemGroupedBackground))
                .cornerRadius(8)
            }
        }
    }
    
    // 🔥 NEW: Helper to extract team code from yard line string
    private func extractTeamCode(from yardLine: String) -> String? {
        // Format is typically "CHI 35" or "GB 20"
        let components = yardLine.split(separator: " ")
        guard components.count >= 1 else { return nil }
        return String(components[0])
    }
}