//
//  PlayoffGameDetailTeamSection.swift
//  BigWarRoom
//
//  Team section for playoff game detail card
//

import SwiftUI

/// Team section with logo, seed, and score overlay
struct PlayoffGameDetailTeamSection: View {
    @Environment(TeamAssetManager.self) private var teamAssets
    
    let team: PlayoffTeam
    let teamColor: Color
    let score: Int
    let hasScores: Bool
    let scoreSize: CGFloat
    let scoreOffset: CGFloat
    let displayOdds: GameBettingOdds?
    let isLive: Bool
    let isCompleted: Bool
    let alignment: HorizontalAlignment // .leading or .trailing
    
    var body: some View {
        ZStack {
            // Logo
            if let logo = teamAssets.logo(for: team.abbreviation) {
                logo
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 110, height: 110)
            }
            
            // Seed badge with moneyline - at bottom
            VStack {
                Spacer()
                HStack {
                    if alignment == .trailing { Spacer() }
                    
                    VStack(spacing: 4) {
                        // Timeout indicators
                        if isLive {
                            TimeoutIndicatorView(timeoutsRemaining: team.timeoutsRemaining ?? 3)
                        }
                        
                        // Seed badge with moneyline
                        if let seed = team.seed {
                            let isFavorite = displayOdds?.favoriteMoneylineTeamCode == team.abbreviation
                            let isUnderdog = displayOdds?.underdogMoneylineTeamCode == team.abbreviation
                            let moneyline = isFavorite ? displayOdds?.favoriteMoneylineOdds : (isUnderdog ? displayOdds?.underdogMoneylineOdds : nil)
                            
                            HStack(spacing: 4) {
                                Text("#\(seed)")
                                    .font(.system(size: 12, weight: .black))
                                    .foregroundStyle(.white)
                                
                                if let ml = moneyline, !isCompleted {
                                    Text(ml)
                                        .font(.system(size: 10, weight: .black))
                                        .foregroundStyle(isFavorite ? .green : .orange)
                                }
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.black.opacity(0.85)))
                        }
                    }
                    .padding(6)
                    
                    if alignment == .leading { Spacer() }
                }
            }
        }
        .frame(width: 100, height: 100)
        .overlay(alignment: alignment == .leading ? .trailing : .leading) {
            if hasScores {
                Text("\(score)")
                    .font(.bebas(size: scoreSize * 1.3))
                    .kerning(-3)
                    .foregroundColor(.white.opacity(0.35))
                    .lineLimit(1)
                    .minimumScaleFactor(0.1)
                    .allowsTightening(true)
                    .fixedSize(horizontal: true, vertical: false)
                    .shadow(color: .black.opacity(0.5), radius: 2, x: alignment == .leading ? 1 : -1, y: 1)
                    .offset(x: alignment == .leading ? (60 + scoreOffset) : (-60 - scoreOffset))
            }
        }
    }
}