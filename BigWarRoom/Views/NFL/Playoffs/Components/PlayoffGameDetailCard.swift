//
//  PlayoffGameDetailCard.swift
//  BigWarRoom
//
//  Large matchup card for playoff game detail modal
//

import SwiftUI

struct PlayoffGameDetailCard: View {
   @Environment(TeamAssetManager.self) private var teamAssets
   
   let game: PlayoffGame
   let displayOdds: GameBettingOdds?
   let scoreSize: CGFloat
   let scoreOffset: CGFloat
   
   var body: some View {
      // 🔥 NEW: Log when card renders
      let _ = DebugPrint(mode: .bracketTimer, "🎨 [MODAL RENDER] Game: \(game.awayTeam.abbreviation)@\(game.homeTeam.abbreviation), Status: \(game.status.displayText), Away: \(game.awayTeam.score ?? 0), Home: \(game.homeTeam.score ?? 0)")
      let _ = DebugPrint(mode: .bracketTimer, "🎨 [LIVE SITUATION] Has liveSituation: \(game.liveSituation != nil), Down/Dist: \(game.liveSituation?.downDistanceDisplay ?? "N/A")")
      let _ = DebugPrint(mode: .bracketTimer, "🏈 [POSSESSION DEBUG] Possession: \(game.liveSituation?.possession ?? "NIL"), Away: \(game.awayTeam.abbreviation), Home: \(game.homeTeam.abbreviation), isLive: \(game.isLive)")
      
      let awayColor = teamAssets.team(for: game.awayTeam.abbreviation)?.primaryColor ?? .blue
      let homeColor = teamAssets.team(for: game.homeTeam.abbreviation)?.primaryColor ?? .red
      let awayScore = game.awayTeam.score ?? 0
      let homeScore = game.homeTeam.score ?? 0
      let hasScores = game.awayTeam.score != nil && game.homeTeam.score != nil
      
      HStack(spacing: 0) {
         // Away team logo (left side) with score overlay
         awayTeamSection(awayColor: awayColor, awayScore: awayScore, hasScores: hasScores)
         
         Spacer()
         
         // Center: Game info
         gameInfoSection()
         
         Spacer()
         
         // Home team logo (right side) with score overlay
         homeTeamSection(homeColor: homeColor, homeScore: homeScore, hasScores: hasScores)
      }
      .padding(.horizontal, 20)
      .frame(height: 100)
      .frame(maxWidth: .infinity)
      .background(
         Rectangle()
            .fill(
               LinearGradient(
                  colors: [
                     awayColor.opacity(0.7),
                     awayColor.opacity(0.5),
                     homeColor.opacity(0.5),
                     homeColor.opacity(0.7)
                  ],
                  startPoint: .leading,
                  endPoint: .trailing
               )
            )
      )
      .overlay(
         Rectangle()
            .stroke(
               LinearGradient(
                  colors: [awayColor, homeColor],
                  startPoint: .leading,
                  endPoint: .trailing
               ),
               lineWidth: 2
            )
      )
      .overlay {
         // 🏈 FOOTBALL OVERLAY - completely independent positioning
         if game.isLive, let possession = game.liveSituation?.possession, hasScores {
            GeometryReader { geo in
               if possession == game.awayTeam.abbreviation {
                  // Away team has possession - put football under left score
                  Text("🏈")
                     .font(.system(size: 20))
                     .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
                     .position(x: 130 + scoreOffset, y: 87)
               } else if possession == game.homeTeam.abbreviation {
                  // Home team has possession - put football under right score
                  Text("🏈")
                     .font(.system(size: 20))
                     .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
                     .position(x: geo.size.width - 130 - scoreOffset, y: 87)
               }
            }
         }
      }
      .clipShape(Rectangle())
      .cornerRadius(12)
      .shadow(color: .black.opacity(0.3), radius: 8)
   }
   
   @ViewBuilder
   private func awayTeamSection(awayColor: Color, awayScore: Int, hasScores: Bool) -> some View {
      ZStack {
         // Logo - no clipping, just scaled
         if let logo = teamAssets.logo(for: game.awayTeam.abbreviation) {
            logo
               .resizable()
               .aspectRatio(contentMode: .fill)
               .frame(width: 110, height: 110)
         }
         
         // Seed badge with moneyline - at bottom
         VStack {
            Spacer()
            HStack {
               VStack(spacing: 4) {
                  // Timeout indicators
                  if game.isLive {
                     TimeoutIndicatorView(timeoutsRemaining: game.awayTeam.timeoutsRemaining ?? 3)
                  }
                  
                  // Seed badge with moneyline
                  if let seed = game.awayTeam.seed {
                     let isAwayFavorite = displayOdds?.favoriteMoneylineTeamCode == game.awayTeam.abbreviation
                     let isAwayUnderdog = displayOdds?.underdogMoneylineTeamCode == game.awayTeam.abbreviation
                     let moneyline = isAwayFavorite ? displayOdds?.favoriteMoneylineOdds : (isAwayUnderdog ? displayOdds?.underdogMoneylineOdds : nil)
                     
                     HStack(spacing: 4) {
                        Text("#\(seed)")
                           .font(.system(size: 12, weight: .black))
                           .foregroundStyle(.white)
                        
                        if let ml = moneyline, !game.isCompleted {
                           Text(ml)
                              .font(.system(size: 10, weight: .black))
                              .foregroundStyle(isAwayFavorite ? .green : .orange)
                        }
                     }
                     .padding(.horizontal, 6)
                     .padding(.vertical, 2)
                     .background(Capsule().fill(Color.black.opacity(0.85)))
                  }
               }
               .padding(6)
            }
         }
      }
      .frame(width: 100, height: 100)
      .overlay(alignment: .trailing) {
         if hasScores {
            Text("\(awayScore)")
               .font(.bebas(size: scoreSize * 1.3))
               .kerning(-3)
               .foregroundColor(.white.opacity(0.35))
               .lineLimit(1)
               .minimumScaleFactor(0.1)
               .allowsTightening(true)
               .fixedSize(horizontal: true, vertical: false)
               .shadow(color: .black.opacity(0.5), radius: 2, x: 1, y: 1)
               .offset(x: 60 + scoreOffset)
         }
      }
   }
   
   @ViewBuilder
   private func homeTeamSection(homeColor: Color, homeScore: Int, hasScores: Bool) -> some View {
      ZStack {
         // Logo - no clipping, just scaled
         if let logo = teamAssets.logo(for: game.homeTeam.abbreviation) {
            logo
               .resizable()
               .aspectRatio(contentMode: .fill)
               .frame(width: 110, height: 110)
         }
         
         // Seed badge with moneyline - at bottom
         VStack {
            Spacer()
            HStack {
               VStack(spacing: 4) {
                  // Timeout indicators
                  if game.isLive {
                     TimeoutIndicatorView(timeoutsRemaining: game.homeTeam.timeoutsRemaining ?? 3)
                  }
                  
                  // Seed badge with moneyline
                  if let seed = game.homeTeam.seed {
                     let isHomeFavorite = displayOdds?.favoriteMoneylineTeamCode == game.homeTeam.abbreviation
                     let isHomeUnderdog = displayOdds?.underdogMoneylineTeamCode == game.homeTeam.abbreviation
                     let moneyline = isHomeFavorite ? displayOdds?.favoriteMoneylineOdds : (isHomeUnderdog ? displayOdds?.underdogMoneylineOdds : nil)
                     
                     HStack(spacing: 4) {
                        Text("#\(seed)")
                           .font(.system(size: 12, weight: .black))
                           .foregroundStyle(.white)
                        
                        if let ml = moneyline, !game.isCompleted {
                           Text(ml)
                              .font(.system(size: 10, weight: .black))
                              .foregroundStyle(isHomeFavorite ? .green : .orange)
                        }
                     }
                     .padding(.horizontal, 6)
                     .padding(.vertical, 2)
                     .background(Capsule().fill(Color.black.opacity(0.85)))
                  }
               }
               .padding(6)
               Spacer()
            }
         }
      }
      .frame(width: 100, height: 100)
      .overlay(alignment: .leading) {
         if hasScores {
            Text("\(homeScore)")
               .font(.bebas(size: scoreSize * 1.3))
               .kerning(-3)
               .foregroundColor(.white.opacity(0.35))
               .lineLimit(1)
               .minimumScaleFactor(0.1)
               .allowsTightening(true)
               .fixedSize(horizontal: true, vertical: false)
               .shadow(color: .black.opacity(0.5), radius: 2, x: -1, y: 1)
               .offset(x: -60 + (scoreOffset * -1))
         }
      }
   }
   
   @ViewBuilder
   private func gameInfoSection() -> some View {
      VStack(spacing: 3) {
         // Day name
         if !game.smartFormattedDate.isEmpty, !game.isLive {
            Text(game.smartFormattedDate.uppercased())
               .font(.system(size: 12, weight: .bold))
               .foregroundColor(.white)
               .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
         }
         
         // LIVE GAME STATUS or time
         if game.isLive, case .inProgress(let quarter, let time) = game.status {
            VStack(spacing: 2) {
               Text(quarter.uppercased())
                  .font(.system(size: 14, weight: .black))
                  .foregroundColor(.gpGreen)
                  .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
               
               if !time.isEmpty {
                  Text(time)
                     .font(.system(size: 16, weight: .black))
                     .foregroundColor(.white.opacity(0.9))
                     .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
               }
               
               // 🏈 NEW: Down & Distance under game time (use cached if current not available)
               if game.isLive {
                  // Try current situation first, fallback to cached
                  if let down = game.liveSituation?.down ?? game.lastKnownDownDistance?.down,
                     let distance = game.liveSituation?.distance ?? game.lastKnownDownDistance?.distance,
                     down > 0, distance > 0 {
                     let suffix: String = {
                        switch down {
                        case 1: return "st"
                        case 2: return "nd"
                        case 3: return "rd"
                        default: return "th"
                        }
                     }()
                     
                     Text("\(down)\(suffix) & \(distance)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white.opacity(0.8))
                        .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                  }
               }
            }
         } else {
            Text(game.formattedTime)
               .font(.system(size: 16, weight: .black))
               .foregroundColor(.white)
               .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
         }
         
         // Stadium
         if let venue = game.venue, let venueName = venue.fullName, !game.isLive {
            Text(venueName)
               .font(.system(size: 11, weight: .semibold))
               .foregroundColor(.white.opacity(0.9))
               .lineLimit(1)
               .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
            
            // City, State
            if let city = venue.city, let state = venue.state {
               Text("\(city), \(state)")
                  .font(.system(size: 10, weight: .medium))
                  .foregroundColor(.white.opacity(0.8))
                  .lineLimit(1)
                  .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
            } else if let city = venue.city {
               Text(city)
                  .font(.system(size: 10, weight: .medium))
                  .foregroundColor(.white.opacity(0.8))
                  .lineLimit(1)
                  .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
            }
         }
         
         // Network
         if let broadcasts = game.broadcasts, !broadcasts.isEmpty, !game.isLive {
            HStack(spacing: 4) {
               Image(systemName: "antenna.radiowaves.left.and.right")
                  .font(.system(size: 9, weight: .semibold))
                  .foregroundColor(.white.opacity(0.7))
               
               Text(broadcasts.joined(separator: ", "))
                  .font(.system(size: 10, weight: .semibold))
                  .foregroundColor(.white.opacity(0.7))
                  .lineLimit(1)
            }
            .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
         }
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 8)
   }
}

// MARK: - Timeout Indicator View

/// Shows 3 circles representing timeouts remaining (filled = available, empty = used)
struct TimeoutIndicatorView: View {
   let timeoutsRemaining: Int
   
   var body: some View {
      HStack(spacing: 3) {
         ForEach(0..<3, id: \.self) { index in
            Circle()
               .fill(index < timeoutsRemaining ? Color.yellow : Color.clear)
               .frame(width: 10, height: 10)
               .overlay(
                  Circle()
                     .stroke(Color.secondary, lineWidth: 1)
               )
         }
      }
   }
}