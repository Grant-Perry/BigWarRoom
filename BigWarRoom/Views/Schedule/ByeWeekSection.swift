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
    let unifiedLeagueManager: UnifiedLeagueManager
    let matchupsHubViewModel: MatchupsHubViewModel
    
    @State private var byeWeekImpacts: [String: ByeWeekImpact] = [:]
    @State private var isLoadingImpacts = false
    @State private var selectedImpactItem: ByeWeekImpactItem?  // 🔥 FIX: Use Identifiable item for sheet
    
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
                
                // Loading indicator while analyzing impact
                if isLoadingImpacts {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                }
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
                    ScheduleByeTeamCell(
                        team: team,
                        byeWeekImpact: byeWeekImpacts[team.id],
                        isLoadingImpacts: isLoadingImpacts
                    ) {
                        // 🔥 ONLY open sheet if impact exists AND has problems
                        if let impact = byeWeekImpacts[team.id], impact.hasProblem {
                            selectedImpactItem = ByeWeekImpactItem(impact: impact, team: team)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            
            // Legend explanation
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.green)
                        Text("No rostered players affected")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.gpRedPink)
                        Text("You have rostered players on BYE")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                
                HStack(spacing: 3) {
                    Text("Tap teams with")
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.gpRedPink)
                    Text("to see affected matchups")
                }
                .font(.system(size: 10, weight: .regular))
                .foregroundColor(.white.opacity(0.55))
                .italic()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
        .padding(.vertical, 16)
        .task {
            await analyzeByeWeekImpacts()
        }
        .onChange(of: WeekSelectionManager.shared.selectedWeek) { _, _ in
            Task {
                await analyzeByeWeekImpacts()
            }
        }
        .sheet(item: $selectedImpactItem) { item in
                ByeWeekPlayerImpactSheet(
                impact: item.impact,
                teamName: item.team.fullName,
                teamCode: item.team.id
                )
        }
    }
    
    // MARK: - Analyze Bye Week Impacts
    
    private func analyzeByeWeekImpacts() async {
        isLoadingImpacts = true
        defer { isLoadingImpacts = false }
        
        var impacts: [String: ByeWeekImpact] = [:]
        
        for team in byeTeams {
            let impact = await ByeWeekImpactService.shared.analyzeByeWeekImpact(
                for: team.id,
                week: WeekSelectionManager.shared.selectedWeek,
                unifiedLeagueManager: unifiedLeagueManager,
                matchupsHubViewModel: matchupsHubViewModel
            )
            
            impacts[team.id] = impact
        }
        
        byeWeekImpacts = impacts
    }
}

// MARK: -> Schedule Bye Team Cell
struct ScheduleByeTeamCell: View {
    let team: NFLTeam
    let byeWeekImpact: ByeWeekImpact?
    let isLoadingImpacts: Bool
    let onTap: () -> Void
    
    @State private var standingsService = NFLStandingsService.shared
    
    var body: some View {
        Button(action: {
            // Only fire action if not loading and has problem
            if !isLoadingImpacts, let impact = byeWeekImpact, impact.hasProblem {
                onTap()
            }
        }) {
            VStack(spacing: 8) {
                // Team logo with badge overlay
                ZStack(alignment: .topTrailing) {
                    TeamAssetManager.shared.logoOrFallback(for: team.id)
                        .frame(width: 50, height: 50)
                        .background(
                            Circle()
                                .fill(team.primaryColor.opacity(0.15))
                                .frame(width: 60, height: 60)
                        )
                        .grayscale(standingsService.isTeamEliminated(for: team.id) ? 1.0 : 0.0)
                        .opacity(standingsService.isTeamEliminated(for: team.id) ? 0.4 : 1.0)
                    
                    // Badge: Checkmark or X (only show after loading completes)
                    if !isLoadingImpacts, let impact = byeWeekImpact {
                        if impact.hasProblem {
                            // RED X - Problem!
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.gpRedPink)
                                .background(
                                    Circle()
                                        .fill(Color.black)
                                        .frame(width: 22, height: 22)
                                )
                                .offset(x: 4, y: -4)
                        } else {
                            // GREEN CHECKMARK - All clear!
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.green)
                                .background(
                                    Circle()
                                        .fill(Color.black)
                                        .frame(width: 22, height: 22)
                                )
                                .offset(x: 4, y: -4)
                        }
                    }
                    
                    // 🔥 NEW: Show elimination skull badge
                    if standingsService.isTeamEliminated(for: team.id) {
                        Image(systemName: "skull.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .background(
                                Circle()
                                    .fill(Color.black)
                                    .frame(width: 20, height: 20)
                            )
                            .offset(x: -24, y: -4)
                    }
                }
                
                // Team name
                Text(team.name)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(standingsService.isTeamEliminated(for: team.id) ? .white.opacity(0.4) : .white.opacity(0.8))
                
                // 🔥 NEW: Show "ELIMINATED" text if eliminated
                if standingsService.isTeamEliminated(for: team.id) {
                    Text("ELIMINATED")
                        .font(.system(size: 8, weight: .black))
                        .foregroundColor(.gray)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(borderColor, lineWidth: borderWidth)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        // 🔥 FIX: Keep full color even when disabled - only dim while loading
        .opacity(isLoadingImpacts ? 0.5 : 1.0)
        .allowsHitTesting(!isLoadingImpacts && byeWeekImpact?.hasProblem == true)
    }
    
    // MARK: - Helpers
    
    private var borderColor: Color {
        if isLoadingImpacts {
            return team.primaryColor.opacity(0.3)
        }
        
        // 🔥 NEW: Gray border for eliminated teams
        if standingsService.isTeamEliminated(for: team.id) {
            return Color.gray.opacity(0.3)
        }
        
        guard let impact = byeWeekImpact else {
            return team.primaryColor.opacity(0.3)
        }
        
        return impact.hasProblem ? Color.gpRedPink.opacity(0.5) : Color.green.opacity(0.3)
    }
    
    private var borderWidth: CGFloat {
        if isLoadingImpacts {
            return 1
        }
        
        guard let impact = byeWeekImpact else {
            return 1
        }
        
        return impact.hasProblem ? 2 : 1
    }
}

// MARK: - Identifiable wrapper for sheet presentation
struct ByeWeekImpactItem: Identifiable {
    let id = UUID()
    let impact: ByeWeekImpact
    let team: NFLTeam
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
    
    let mockUnifiedLeagueManager = UnifiedLeagueManager(
        sleeperClient: SleeperAPIClient(),
        espnClient: ESPNAPIClient(credentialsManager: ESPNCredentialsManager.shared),
        espnCredentials: ESPNCredentialsManager.shared
    )
    
    ZStack {
        Color.black.ignoresSafeArea()
        
        ScheduleByeWeekSection(
            byeTeams: sampleTeams,
            unifiedLeagueManager: mockUnifiedLeagueManager,
            matchupsHubViewModel: MatchupsHubViewModel.shared
        )
    }
    .preferredColorScheme(.dark)
}