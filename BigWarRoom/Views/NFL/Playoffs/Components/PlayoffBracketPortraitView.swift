//
//  PlayoffBracketPortraitView.swift
//  BigWarRoom
//
//  Portrait view of playoff bracket showing current round
//

import SwiftUI

struct PlayoffBracketPortraitView: View {
    @Environment(TeamAssetManager.self) private var teamAssets
    
    let bracket: PlayoffBracket
    let currentRound: PlayoffRound
    let weekSelectionManager: WeekSelectionManager
    let onRefresh: () async -> Void
    
    var body: some View {
        let currentYear = Int(SeasonYearManager.shared.selectedYear) ?? AppConstants.currentSeasonYearInt
        
        ScrollView([.horizontal, .vertical], showsIndicators: false) {
            VStack(spacing: 0) {
                VStack(spacing: 2) {
                    Text("CURRENT \(String(currentYear))")
                        .font(.system(size: 16, weight: .black))
                        .foregroundColor(.white)
                        .italic()
                    
                    Text(PlayoffBracketHelpers.playoffRoundTitle(currentRound))
                        .font(.system(size: 22, weight: .black))
                        .foregroundColor(.white)
                        .italic()
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 48)
                
                HStack(alignment: .top, spacing: 30) {
                    PlayoffBracketConferenceColumn(
                        conference: .afc,
                        bracket: bracket,
                        currentRound: currentRound,
                        getSeedsForConference: PlayoffGameHelpers.getSeedsForConference,
                        findGame: PlayoffGameHelpers.findGame,
                        determineWinner: PlayoffGameHelpers.determineWinner,
                        shouldShowGameTime: PlayoffBracketHelpers.shouldShowGameTime
                    )
                    
                    PlayoffBracketConferenceColumn(
                        conference: .nfc,
                        bracket: bracket,
                        currentRound: currentRound,
                        getSeedsForConference: PlayoffGameHelpers.getSeedsForConference,
                        findGame: PlayoffGameHelpers.findGame,
                        determineWinner: PlayoffGameHelpers.determineWinner,
                        shouldShowGameTime: PlayoffBracketHelpers.shouldShowGameTime
                    )
                }
                .padding(.leading, 12)
                .padding(.trailing, 32)
                .padding(.bottom, 20)
                
                Spacer()
                
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: "rotate.right")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    
                    Text("HEY! You gotta turn your device sideways\nand interact with the full bracket.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(Color(.systemGray6).opacity(0.5))
                .cornerRadius(8)
            }
            .scaleEffect(0.9)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .offset(x: -12, y: -50)
        .refreshable {
            await onRefresh()
        }
    }
}