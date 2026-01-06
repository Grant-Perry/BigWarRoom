//
   //  BracketTeamCell.swift
   //  BigWarRoom
   //
   //  Created by Gp. on 1/6/26.
   //  Updated: Forces Left-to-Right layout to keep NFC cards identical to AFC.
   //

import SwiftUI

struct BracketTeamCell: View {
   @Environment(TeamAssetManager.self) private var teamAssets
   @Environment(NFLStandingsService.self) private var standingsService
   let team: PlayoffTeam?
   let isReversed: Bool

   var body: some View {
	  ZStack {
		 if let team = team {
			let color = teamAssets.team(for: team.abbreviation)?.primaryColor ?? .gray
			RoundedRectangle(cornerRadius: 6)
			   .fill(LinearGradient(gradient: Gradient(colors: [color, color.opacity(0.6)]), startPoint: .top, endPoint: .bottom))
		 } else {
			   // Empty Matchup Box
			RoundedRectangle(cornerRadius: 6)
			   .fill(
				  LinearGradient(
					 gradient: Gradient(colors: [
						.gray.opacity(0.15),
						.clear.opacity(0.15)
					 ]),
					 startPoint: .topLeading,
					 endPoint: .bottomTrailing
				  )
			   )
		 }

		 RoundedRectangle(cornerRadius: 6)
			.stroke(Color.white.opacity(0.35), lineWidth: 1)

		 if let team = team {
			   // Background Seed # - only show if seed exists and is > 0
			if let seed = team.seed, seed > 0 {
			   HStack(alignment: .top, spacing: 0) {
				  Text("#")
					 .font(.system(size: 18, weight: .black))
					 .foregroundColor(.white.opacity(0.25))
					 .offset(y: -1)
				  Text("\(seed)")
					 .font(.system(size: 36, weight: .black))
					 .foregroundColor(.white.opacity(0.3))
			   }
			   .frame(maxWidth: .infinity, alignment: .trailing)
			   .padding(.horizontal, 4)
			}

			   // Content Row
			   // Standard order: Logo -> Info -> Spacer
			HStack(spacing: 6) {
			   logoView(team: team)
			   infoView(team: team)
			   Spacer()
			}
			.padding(.horizontal, 6)
		 }
	  }
	  .frame(width: 95, height: 40)
		 // THE FIX: Force this cell to always render Left-to-Right,
		 // ignoring the parent's flip for the NFC side.
	  .environment(\.layoutDirection, .leftToRight)
   }

   private func logoView(team: PlayoffTeam) -> some View {
	  Group {
		 if let logo = teamAssets.logo(for: team.abbreviation) {
			logo.resizable().scaledToFit()
		 } else { Circle().fill(Color.gray.opacity(0.3)) }
	  }
	  .frame(width: 26, height: 26)
   }

   private func infoView(team: PlayoffTeam) -> some View {
	  let record = standingsService.getTeamRecord(for: team.abbreviation)
	  return VStack(alignment: .leading, spacing: 0) {
		 Text(team.abbreviation.uppercased())
			.font(.system(size: 10, weight: .heavy))
			.foregroundColor(.white)
		 Text(record)
			.font(.system(size: 8, weight: .medium))
			.monospacedDigit()
			.foregroundColor(.white.opacity(0.7))
	  }
   }
}