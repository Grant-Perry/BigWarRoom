//
//  ByeWeekSection.swift
//  BigWarRoom
//
//  Displays NFL teams on BYE week in the Schedule view
//
// MARK: -> Schedule Bye Week Section

import SwiftUI

struct ScheduleByeWeekSection: View {
    let byeTeams: [NFLTeam]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header with week number
            HStack {
                Text("BYE - Week \(WeekSelectionManager.shared.selectedWeek)")
                    .font(.system(size: 16, weight: .black, design: .default))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(byeTeams.count) teams")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.horizontal, 20)
            
            // Teams grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(byeTeams) { team in
                    ScheduleByeTeamCell(team: team)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 16)
    }
}

// MARK: -> Schedule Bye Team Cell
struct ScheduleByeTeamCell: View {
    let team: NFLTeam
    
    var body: some View {
        VStack(spacing: 8) {
            // Team logo using TeamAssetManager (fetches from ESPN CDN)
            TeamAssetManager.shared.logoOrFallback(for: team.id)
                .frame(width: 50, height: 50)
                .background(
                    Circle()
                        .fill(team.primaryColor.opacity(0.15))
                        .frame(width: 60, height: 60)
                )
            
            // Team name
            Text(team.name)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(team.primaryColor.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

#Preview("Schedule Bye Week Section") {
    let sampleTeams = [
        NFLTeam.team(for: "KC")!,
        NFLTeam.team(for: "BUF")!,
        NFLTeam.team(for: "SF")!,
        NFLTeam.team(for: "PHI")!,
        NFLTeam.team(for: "DAL")!,
        NFLTeam.team(for: "MIA")!
    ]
    
    ZStack {
        Color.black.ignoresSafeArea()
        
        ScheduleByeWeekSection(byeTeams: sampleTeams)
    }
    .preferredColorScheme(.dark)
}