//
//  PlayoffOddsBar.swift
//  BigWarRoom
//
//  Condensed odds bar with sportsbook picker
//

import SwiftUI

struct PlayoffOddsBar: View {
   let displayOdds: GameBettingOdds?
   let currentSportsbook: Sportsbook
   let onBookPickerTap: () -> Void
   
   var body: some View {
      HStack(spacing: 16) {
         // Moneyline
         if let favTeam = displayOdds?.favoriteMoneylineTeamCode,
            let favOdds = displayOdds?.favoriteMoneylineOdds,
            let dogTeam = displayOdds?.underdogMoneylineTeamCode,
            let dogOdds = displayOdds?.underdogMoneylineOdds {
            VStack(alignment: .leading, spacing: 2) {
               Text("MONEYLINE")
                  .font(.system(size: 9, weight: .bold))
                  .foregroundStyle(.secondary)
               HStack(spacing: 6) {
                  Text("\(favTeam) \(favOdds)")
                     .font(.system(size: 13, weight: .bold))
                     .foregroundStyle(.green)
                  Text("/")
                     .font(.system(size: 11, weight: .medium))
                     .foregroundStyle(.secondary)
                  Text("\(dogTeam) \(dogOdds)")
                     .font(.system(size: 13, weight: .bold))
                     .foregroundStyle(.orange)
               }
            }
         }
         
         Divider()
            .frame(height: 30)
         
         // Spread
         if let spread = displayOdds?.spreadDisplay {
            VStack(alignment: .leading, spacing: 2) {
               Text("SPREAD")
                  .font(.system(size: 9, weight: .bold))
                  .foregroundStyle(.secondary)
               Text(spread)
                  .font(.system(size: 13, weight: .bold))
                  .foregroundStyle(.primary)
            }
         }
         
         Divider()
            .frame(height: 30)
         
         // Total
         if let total = displayOdds?.totalDisplay {
            VStack(alignment: .leading, spacing: 2) {
               Text("TOTAL")
                  .font(.system(size: 9, weight: .bold))
                  .foregroundStyle(.secondary)
               Text(total)
                  .font(.system(size: 13, weight: .bold))
                  .foregroundStyle(.primary)
            }
         }
         
         Spacer()
         
         // Sportsbook badge (TAPPABLE)
         Button {
            onBookPickerTap()
         } label: {
            HStack(spacing: 4) {
               Text("via")
                  .font(.system(size: 9, weight: .medium))
                  .foregroundStyle(.secondary)
               SportsbookBadge(book: currentSportsbook, size: 10)
               Image(systemName: "chevron.down")
                  .font(.system(size: 8, weight: .bold))
                  .foregroundStyle(.secondary)
            }
         }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .background(Color(.secondarySystemGroupedBackground))
      .cornerRadius(10)
   }
}