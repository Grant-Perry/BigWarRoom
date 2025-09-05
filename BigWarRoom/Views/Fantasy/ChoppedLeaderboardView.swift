//
//  ChoppedLeaderboardView.swift
//  BigWarRoom
//
//  🔥💀 CHOPPED LEAGUE BATTLE ROYALE 💀🔥
//  The most INSANE elimination fantasy football experience
//
// MARK: -> CHOPPED APOCALYPSE LEADERBOARD 

import SwiftUI

struct ChoppedLeaderboardView: View {
    let choppedSummary: ChoppedWeekSummary
    let leagueName: String
    
    @State private var showEliminationCeremony = false
    @State private var pulseAnimation = false
    @State private var dangerPulse = false
    
    var body: some View {
        ZStack {
            // APOCALYPTIC BACKGROUND
            apocalypticBackground
            
            ScrollView {
                VStack(spacing: 0) {
                    // BATTLE ROYALE HEADER
                    battleRoyaleHeader
                    
                    // SURVIVAL STATS
                    survivalStats
                    
                    // CHAMPION THRONE
                    if let champion = choppedSummary.champion {
                        championSection(champion)
                    }
                    
                    // SAFE ZONE
                    if !choppedSummary.safeTeams.isEmpty {
                        survivalSection(
                            title: "🛡️ SAFE ZONE",
                            subtitle: "Living to fight another week",
                            teams: choppedSummary.safeTeams,
                            sectionColor: .green
                        )
                    }
                    
                    // WARNING ZONE
                    if !choppedSummary.warningTeams.isEmpty {
                        survivalSection(
                            title: "⚡ WARNING ZONE",
                            subtitle: "Treading dangerous waters",
                            teams: choppedSummary.warningTeams,
                            sectionColor: .blue
                        )
                    }
                    
                    // DANGER ZONE - PULSING RED
                    if !choppedSummary.dangerZoneTeams.isEmpty {
                        dangerZoneSection
                    }
                    
                    // CRITICAL ZONE - DEATH ROW
                    if !choppedSummary.criticalTeams.isEmpty {
                        criticalZoneSection
                    }
                    
                    // HALL OF THE DEAD (ENHANCED WITH HISTORICAL ELIMINATIONS)
                    if !choppedSummary.eliminationHistory.isEmpty {
                        eliminatedHistorySection
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            startAnimations()
        }
        .sheet(isPresented: $showEliminationCeremony) {
            EliminationCeremonyView(
                eliminatedTeam: choppedSummary.eliminatedTeam,
                week: choppedSummary.week
            )
        }
    }
    
    // MARK: -> APOCALYPTIC BACKGROUND
    private var apocalypticBackground: some View {
        ZStack {
            // Base dark background
            Color.black.ignoresSafeArea()
            
            // Animated danger gradient for critical situations
            if !choppedSummary.criticalTeams.isEmpty {
                LinearGradient(
                    gradient: Gradient(colors: [
                        .red.opacity(0.1),
                        .black,
                        .red.opacity(0.1)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                .opacity(dangerPulse ? 0.3 : 0.1)
                .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: dangerPulse)
            }
        }
    }
    
    // MARK: -> BATTLE ROYALE HEADER
    private var battleRoyaleHeader: some View {
        VStack(spacing: 16) {
            // Main title with dramatic effect - USE LEAGUE NAME
            HStack {
                Text("💀")
                    .font(.system(size: 32))
                    .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulseAnimation)
                
                VStack {
                    Text(leagueName.uppercased())
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.red, .orange, .red],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                
                Text("🔥")
                    .font(.system(size: 32))
                    .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true).delay(0.5), value: pulseAnimation)
            }
            
            // Week and survival info
            HStack(spacing: 24) {
                VStack {
                    Text("WEEK \(choppedSummary.week)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("ELIMINATION ROUND")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.gray)
                        .tracking(1)
                }
                
                Rectangle()
                    .fill(Color.red)
                    .frame(width: 2, height: 40)
                
                VStack {
                    Text("\(choppedSummary.totalSurvivors)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.green)
                    
                    Text("SURVIVORS")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.gray)
                        .tracking(1)
                }
                
                Rectangle()
                    .fill(Color.red)
                    .frame(width: 2, height: 40)
                
                VStack {
                    Text("\(choppedSummary.eliminatedTeams.count)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.red)
                    
                    Text("ELIMINATED")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.gray)
                        .tracking(1)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [.red, .orange, .red],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 2
                        )
                )
        )
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }
    
    // MARK: -> SURVIVAL STATS
    private var survivalStats: some View {
        HStack(spacing: 16) {
            statCard(
                title: "ELIMINATION LINE",
                value: String(format: "%.1f", choppedSummary.cutoffScore),
                subtitle: "DEATH THRESHOLD",
                color: .red
            )
            
            statCard(
                title: "AVERAGE SCORE",
                value: String(format: "%.1f", choppedSummary.averageScore),
                subtitle: "SURVIVOR MEAN",
                color: .blue
            )
            
            statCard(
                title: "TOP SCORE",
                value: String(format: "%.1f", choppedSummary.highestScore),
                subtitle: "WEEK CHAMPION",
                color: .yellow
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    private func statCard(title: String, value: String, subtitle: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.gray)
                .tracking(1)
            
            Text(value)
                .font(.system(size: 20, weight: .black))
                .foregroundColor(color)
            
            Text(subtitle)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(.gray)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: -> CHAMPION SECTION
    private func championSection(_ champion: FantasyTeamRanking) -> some View {
        VStack(spacing: 16) {
            // Crown header
            HStack {
                Text("👑")
                    .font(.system(size: 24))
                
                Text("REIGNING CHAMPION")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange, .yellow],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .tracking(2)
                
                Text("👑")
                    .font(.system(size: 24))
            }
            
            // Champion card
            ChampionCard(ranking: champion)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
    }
    
    // MARK: -> DANGER ZONE SECTION (PULSING)
    private var dangerZoneSection: some View {
        VStack(spacing: 16) {
            // Danger header with pulsing effect
            HStack {
                Text("⚠️")
                    .font(.system(size: 20))
                    .scaleEffect(dangerPulse ? 1.3 : 1.0)
                    .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: dangerPulse)
                
                Text("DANGER ZONE")
                    .font(.system(size: 18, weight: .black))
                    .foregroundColor(.orange)
                    .tracking(2)
                
                Text("⚠️")
                    .font(.system(size: 20))
                    .scaleEffect(dangerPulse ? 1.3 : 1.0)
                    .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true).delay(0.5), value: dangerPulse)
                
                Spacer()
                
                Text("\(choppedSummary.dangerZoneTeams.count) IN DANGER")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.orange)
            }
            
            Text("🚨 ONE STEP AWAY FROM THE CHOPPING BLOCK 🚨")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .center)
            
            // Danger zone teams
            ForEach(choppedSummary.dangerZoneTeams) { ranking in
                DangerZoneCard(ranking: ranking)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.orange.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.orange.opacity(dangerPulse ? 0.6 : 0.3), lineWidth: 2)
                        .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: dangerPulse)
                )
        )
        .padding(.horizontal, 20)
    }
    
    // MARK: -> CRITICAL ZONE (DEATH ROW)
    private var criticalZoneSection: some View {
        VStack(spacing: 16) {
            // Critical header - MOST DRAMATIC
            HStack {
                Text("💀")
                    .font(.system(size: 24))
                    .scaleEffect(pulseAnimation ? 1.5 : 1.0)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulseAnimation)
                
                VStack {
                    Text("DEATH ROW")
                        .font(.system(size: 20, weight: .black))
                        .foregroundColor(.red)
                        .tracking(3)
                    
                    Text("ELIMINATION IMMINENT")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.gray)
                        .tracking(2)
                }
                
                Text("☠️")
                    .font(.system(size: 24))
                    .scaleEffect(pulseAnimation ? 1.5 : 1.0)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true).delay(0.3), value: pulseAnimation)
            }
            
            // Critical teams
            ForEach(choppedSummary.criticalTeams) { ranking in
                CriticalCard(ranking: ranking)
            }
            
            // Elimination ceremony button
            if choppedSummary.isComplete && choppedSummary.eliminatedTeam != nil {
                Button(action: {
                    showEliminationCeremony = true
                }) {
                    HStack {
                        Text("🎬")
                        Text("WATCH ELIMINATION CEREMONY")
                            .font(.system(size: 14, weight: .bold))
                            .tracking(1)
                        Text("🎬")
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(Color.red)
                            .shadow(color: .red.opacity(0.5), radius: 10)
                    )
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.red.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [.red, .black, .red],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 3
                        )
                )
        )
        .padding(.horizontal, 20)
    }
    
    // MARK: -> ELIMINATED SECTION (HALL OF THE DEAD)
    private var eliminatedSection: some View {
        VStack(spacing: 16) {
            // Hall of the dead header
            HStack {
                Text("🪦")
                    .font(.system(size: 20))
                
                Text("HALL OF THE DEAD")
                    .font(.system(size: 18, weight: .black))
                    .foregroundColor(.gray)
                    .tracking(2)
                
                Text("🪦")
                    .font(.system(size: 20))
                
                Spacer()
            }
            
            Text("In memory of those who have fallen...")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
                .italic()
                .frame(maxWidth: .infinity, alignment: .center)
            
            // Eliminated teams
            ForEach(choppedSummary.eliminatedTeams) { ranking in
                EliminatedCard(ranking: ranking)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
    
    // MARK: -> SURVIVAL SECTION (GENERIC)
    private func survivalSection(title: String, subtitle: String, teams: [FantasyTeamRanking], sectionColor: Color) -> some View {
        VStack(spacing: 16) {
            HStack {
                Text(title)
                    .font(.system(size: 18, weight: .black))
                    .foregroundColor(sectionColor)
                    .tracking(1)
                
                Spacer()
                
                Text("\(teams.count) TEAMS")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.gray)
            }
            
            Text(subtitle)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            ForEach(teams) { ranking in
                SurvivalCard(ranking: ranking)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(sectionColor.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(sectionColor.opacity(0.2), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
    }
    
    // MARK: -> HISTORICAL ELIMINATIONS SECTION (THE GRAVEYARD) 🪦💀
    private var eliminatedHistorySection: some View {
        VStack(spacing: 16) {
            // Graveyard header
            HStack {
                Text("🪦")
                    .font(.system(size: 20))
                
                Text("THE GRAVEYARD")
                    .font(.system(size: 18, weight: .black))
                    .foregroundColor(.gray)
                    .tracking(2)
                
                Text("💀")
                    .font(.system(size: 20))
                
                Spacer()
                
                Text("\(choppedSummary.eliminationHistory.count) FALLEN")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.red)
            }
            
            Text("\"They fought valiantly, but could not survive the chopping block...\"")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
                .italic()
                .frame(maxWidth: .infinity, alignment: .center)
            
            // Historical eliminations in chronological order
            ForEach(choppedSummary.eliminationHistory) { elimination in
                HistoricalEliminationCard(elimination: elimination)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
    
    // MARK: -> ANIMATIONS
    private func startAnimations() {
        pulseAnimation = true
        dangerPulse = true
    }
}

// MARK: -> CHAMPION CARD 👑
struct ChampionCard: View {
    let ranking: FantasyTeamRanking
    
    var body: some View {
        HStack(spacing: 16) {
            // Crown rank
            VStack {
                Text("👑")
                    .font(.system(size: 32))
                
                Text("1ST")
                    .font(.system(size: 12, weight: .black))
                    .foregroundColor(.yellow)
            }
            .frame(width: 60)
            
            // Team avatar with golden glow
            teamAvatar
                .overlay(
                    Circle()
                        .stroke(Color.yellow, lineWidth: 3)
                        .shadow(color: .yellow.opacity(0.6), radius: 8)
                )
            
            // Team info
            VStack(alignment: .leading, spacing: 6) {
                Text(ranking.team.ownerName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                Text("REIGNING SUPREME")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.yellow)
                    .tracking(1)
                
                HStack {
                    Text("Survival: \(ranking.survivalPercentage)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.green)
                    
                    Text("•")
                        .foregroundColor(.gray)
                    
                    Text("Weeks Alive: \(ranking.weeksAlive)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            // Points with royal treatment
            VStack(spacing: 4) {
                Text(ranking.weeklyPointsString)
                    .font(.system(size: 28, weight: .black))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text("POINTS")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.gray)
                    .tracking(1)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.yellow.opacity(0.1),
                            Color.orange.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 2
                        )
                )
        )
    }
    
    private var teamAvatar: some View {
        Group {
            if let avatarURL = ranking.team.avatarURL {
                AsyncImage(url: avatarURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure(_), .empty:
                        espnTeamAvatar
                    @unknown default:
                        espnTeamAvatar
                    }
                }
            } else {
                espnTeamAvatar
            }
        }
        .frame(width: 60, height: 60)
        .clipShape(Circle())
    }
    
    private var espnTeamAvatar: some View {
        Circle()
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        ranking.team.espnTeamColor,
                        ranking.team.espnTeamColor.opacity(0.7)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Text(ranking.team.teamInitials)
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundColor(.white)
            )
    }
}

// MARK: -> SURVIVAL CARD (SAFE/WARNING ZONES)
struct SurvivalCard: View {
    let ranking: FantasyTeamRanking
    
    var body: some View {
        HStack(spacing: 16) {
            // Rank badge
            VStack {
                Text(ranking.rankDisplay)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                
                Text("RANK")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.gray)
                    .tracking(0.5)
            }
            .frame(width: 50)
            
            // Team avatar
            teamAvatar
            
            // Team info
            VStack(alignment: .leading, spacing: 4) {
                Text(ranking.team.ownerName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                HStack(spacing: 8) {
                    Text(ranking.eliminationStatus.emoji)
                    Text(ranking.eliminationStatus.displayName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(ranking.eliminationStatus.color)
                }
                
                // 🎯 PROMINENT SLEEPER-STYLE SAFE % DISPLAY
                HStack(spacing: 12) {
                    Text("SAFE \(ranking.survivalPercentage)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(ranking.survivalProbability > 0.6 ? Color.green : ranking.survivalProbability > 0.3 ? Color.orange : Color.red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill((ranking.survivalProbability > 0.6 ? Color.green : ranking.survivalProbability > 0.3 ? Color.orange : Color.red).opacity(0.2))
                        )
                    
                    // Show projected score if different from current
                    if let projected = ranking.team.projectedScore, 
                       let current = ranking.team.currentScore,
                       abs(projected - current) > 1.0 {
                        Text("PROJ: \(String(format: "%.1f", projected))")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.cyan)
                    }
                }
            }
            
            Spacer()
            
            // Points with projected display
            VStack(alignment: .trailing, spacing: 4) {
                Text(ranking.weeklyPointsString)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                // Show "PROJ" or "PTS" based on scoring status
                if let current = ranking.team.currentScore, current > 0 {
                    Text("PTS")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.gray)
                } else if let projected = ranking.team.projectedScore, projected > 0 {
                    Text("PROJ")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.cyan)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(ranking.eliminationStatus.color.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var teamAvatar: some View {
        Group {
            if let avatarURL = ranking.team.avatarURL {
                AsyncImage(url: avatarURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure(_), .empty:
                        espnTeamAvatar
                    @unknown default:
                        espnTeamAvatar
                    }
                }
            } else {
                espnTeamAvatar
            }
        }
        .frame(width: 50, height: 50)
        .clipShape(Circle())
    }
    
    private var espnTeamAvatar: some View {
        Circle()
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        ranking.team.espnTeamColor,
                        ranking.team.espnTeamColor.opacity(0.8)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Text(ranking.team.teamInitials)
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundColor(.white)
            )
    }
}

// MARK: -> DANGER ZONE CARD ⚠️
struct DangerZoneCard: View {
    let ranking: FantasyTeamRanking
    @State private var warningPulse = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Warning rank with pulse
            VStack {
                Text(ranking.rankDisplay)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.orange)
                    .scaleEffect(warningPulse ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: warningPulse)
                
                Text("DANGER")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.orange)
                    .tracking(0.5)
            }
            .frame(width: 50)
            .onAppear { warningPulse = true }
            
            // Team avatar with warning glow
            teamAvatar
                .overlay(
                    Circle()
                        .stroke(Color.orange.opacity(warningPulse ? 0.8 : 0.4), lineWidth: 2)
                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: warningPulse)
                )
            
            // Team info with danger indicators
            VStack(alignment: .leading, spacing: 4) {
                Text(ranking.team.ownerName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                HStack {
                    Text("⚠️")
                    Text("ON THE CHOPPING BLOCK")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.orange)
                        .tracking(1)
                }
                
                // 🎯 PROMINENT SLEEPER-STYLE SAFE % DISPLAY FOR DANGER ZONE
                HStack(spacing: 12) {
                    Text("SAFE \(ranking.survivalPercentage)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.orange.opacity(0.3))
                        )
                        .scaleEffect(warningPulse ? 1.05 : 1.0)
                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: warningPulse)
                    
                    Text("From Safety: \(ranking.safetyMarginDisplay)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.orange)
                }
            }
            
            Spacer()
            
            // Points with warning styling
            VStack(alignment: .trailing, spacing: 4) {
                Text(ranking.weeklyPointsString)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.orange)
                
                // Show current vs projected status
                if let current = ranking.team.currentScore, current > 0 {
                    Text("CURRENT")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.orange)
                        .tracking(1)
                } else if let projected = ranking.team.projectedScore, projected > 0 {
                    Text("PROJECTED")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.orange)
                        .tracking(1)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange.opacity(warningPulse ? 0.6 : 0.1), lineWidth: 2)
                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: warningPulse)
                )
        )
    }
    
    private var teamAvatar: some View {
        Group {
            if let avatarURL = ranking.team.avatarURL {
                AsyncImage(url: avatarURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure(_), .empty:
                        espnTeamAvatar
                    @unknown default:
                        espnTeamAvatar
                    }
                }
            } else {
                espnTeamAvatar
            }
        }
        .frame(width: 50, height: 50)
        .clipShape(Circle())
    }
    
    private var espnTeamAvatar: some View {
        Circle()
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        ranking.team.espnTeamColor,
                        ranking.team.espnTeamColor.opacity(0.7)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Text(ranking.team.teamInitials)
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundColor(.white)
            )
    }
}

// MARK: -> CRITICAL CARD (DEATH ROW) 💀
struct CriticalCard: View {
    let ranking: FantasyTeamRanking
    @State private var deathPulse = false
    @State private var heartbeat = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Death row rank with intense pulse
            VStack {
                Text("💀")
                    .font(.system(size: 24))
                    .scaleEffect(deathPulse ? 1.4 : 1.0)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: deathPulse)
                
                Text("LAST")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(.red)
                    .tracking(1)
            }
            .frame(width: 50)
            .onAppear { 
                deathPulse = true
                heartbeat = true
            }
            
            // Team avatar with death aura
            teamAvatar
                .overlay(
                    Circle()
                        .stroke(Color.red.opacity(deathPulse ? 1.0 : 0.3), lineWidth: 3)
                        .shadow(color: .red, radius: deathPulse ? 8 : 0)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: deathPulse)
                )
            
            // Team info with critical warnings
            VStack(alignment: .leading, spacing: 6) {
                Text(ranking.team.ownerName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                HStack {
                    Text("💀")
                        .scaleEffect(heartbeat ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: heartbeat)
                    
                    Text("ELIMINATION IMMINENT")
                        .font(.system(size: 12, weight: .black))
                        .foregroundColor(.red)
                        .tracking(1)
                }
                
                // 🎯 ULTRA-DRAMATIC SAFE % DISPLAY FOR DEATH ROW
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("SAFE \(ranking.survivalPercentage)")
                            .font(.system(size: 14, weight: .black))
                            .foregroundColor(.red)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.red.opacity(0.3))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.red, lineWidth: 2)
                                    )
                            )
                            .scaleEffect(heartbeat ? 1.1 : 1.0)
                            .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: heartbeat)
                        
                        Text("💔")
                            .scaleEffect(heartbeat ? 1.3 : 1.0)
                            .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true).delay(0.2), value: heartbeat)
                    }
                    
                    Text("⚰️ From Elimination: \(ranking.safetyMarginDisplay)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.red)
                }
            }
            
            Spacer()
            
            // Critical points display
            VStack(alignment: .trailing, spacing: 4) {
                Text(ranking.weeklyPointsString)
                    .font(.system(size: 24, weight: .black))
                    .foregroundColor(.red)
                    .scaleEffect(heartbeat ? 1.05 : 1.0)
                    .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: heartbeat)
                
                // Dramatic scoring status
                if let current = ranking.team.currentScore, current > 0 {
                    Text("FINAL SCORE")
                        .font(.system(size: 8, weight: .black))
                        .foregroundColor(.red)
                        .tracking(1)
                } else if let projected = ranking.team.projectedScore, projected > 0 {
                    Text("PROJECTED")
                        .font(.system(size: 8, weight: .black))
                        .foregroundColor(.red)
                        .tracking(1)
                } else {
                    Text("CRITICAL")
                        .font(.system(size: 8, weight: .black))
                        .foregroundColor(.red)
                        .tracking(1)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.red.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.red.opacity(deathPulse ? 1.0 : 0.5), lineWidth: 3)
                        .shadow(color: .red.opacity(0.5), radius: deathPulse ? 10 : 0)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: deathPulse)
                )
        )
    }
    
    private var teamAvatar: some View {
        Group {
            if let avatarURL = ranking.team.avatarURL {
                AsyncImage(url: avatarURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure(_), .empty:
                        espnTeamAvatar
                    @unknown default:
                        espnTeamAvatar
                    }
                }
            } else {
                espnTeamAvatar
            }
        }
        .frame(width: 50, height: 50)
        .clipShape(Circle())
        .grayscale(0.3) // Slightly faded for impending doom
    }
    
    private var espnTeamAvatar: some View {
        Circle()
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        ranking.team.espnTeamColor.opacity(0.7),
                        ranking.team.espnTeamColor.opacity(0.5)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Text(ranking.team.teamInitials)
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
            )
    }
}

// MARK: -> ELIMINATED CARD (HALL OF THE DEAD) 🪦
struct EliminatedCard: View {
    let ranking: FantasyTeamRanking
    
    var body: some View {
        HStack(spacing: 16) {
            // Death marker
            VStack {
                Text("🪦")
                    .font(.system(size: 20))
                
                Text("WEEK \(ranking.weeksAlive)")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.gray)
            }
            .frame(width: 50)
            
            // Faded team avatar
            teamAvatar
            
            // Memorial info
            VStack(alignment: .leading, spacing: 4) {
                Text(ranking.team.ownerName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.gray)
                    .strikethrough()
                
                Text("💀 ELIMINATED - WEEK \(ranking.weeksAlive)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                
                Text("\"Fought valiantly but couldn't survive\"")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.gray)
                    .italic()
            }
            
            Spacer()
            
            // Final score
            VStack(alignment: .trailing, spacing: 4) {
                Text(ranking.weeklyPointsString)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.gray)
                
                Text("FINAL")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.gray)
                    .tracking(1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var teamAvatar: some View {
        Group {
            if let avatarURL = ranking.team.avatarURL {
                AsyncImage(url: avatarURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure(_), .empty:
                        espnTeamAvatar
                    @unknown default:
                        espnTeamAvatar
                    }
                }
            } else {
                espnTeamAvatar
            }
        }
        .frame(width: 50, height: 50)
        .clipShape(Circle())
        .grayscale(1.0) // Completely grayscale for the dead
        .opacity(0.6)
    }
    
    private var espnTeamAvatar: some View {
        Circle()
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.gray.opacity(0.4),
                        Color.gray.opacity(0.2)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Text(ranking.team.teamInitials)
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundColor(.gray.opacity(0.6))
            )
    }
}

// MARK: -> ELIMINATION CEREMONY VIEW 🎬💀
struct EliminationCeremonyView: View {
    let eliminatedTeam: FantasyTeamRanking?
    let week: Int
    
    @Environment(\.dismiss) private var dismiss
    @State private var showElimination = false
    @State private var torchFlicker = false
    
    var body: some View {
        ZStack {
            // Dark ceremonial background
            Color.black.ignoresSafeArea()
            
            // Flickering torch effect
            LinearGradient(
                colors: [.orange.opacity(0.1), .red.opacity(0.1), .black],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .opacity(torchFlicker ? 0.3 : 0.1)
            .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: torchFlicker)
            
            VStack(spacing: 30) {
                // Ceremony header
                VStack(spacing: 16) {
                    Text("🎬")
                        .font(.system(size: 48))
                    
                    Text("ELIMINATION CEREMONY")
                        .font(.system(size: 24, weight: .black))
                        .foregroundColor(.red)
                        .tracking(3)
                    
                    Text("WEEK \(week)")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                        .tracking(2)
                }
                
                // Dramatic reveal
                if let eliminated = eliminatedTeam, showElimination {
                    VStack(spacing: 20) {
                        Text("THE CHOPPED CONTESTANT...")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.orange)
                            .tracking(2)
                        
                        // Eliminated team display
                        VStack(spacing: 16) {
                            // Team avatar with death effect
                            Group {
                                if let avatarURL = eliminated.team.avatarURL {
                                    AsyncImage(url: avatarURL) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                        default:
                                            Circle()
                                                .fill(Color.gray)
                                        }
                                    }
                                } else {
                                    Circle()
                                        .fill(eliminated.team.espnTeamColor)
                                        .overlay(
                                            Text(eliminated.team.teamInitials)
                                                .font(.system(size: 24, weight: .black))
                                                .foregroundColor(.white)
                                        )
                                }
                            }
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                            .grayscale(1.0)
                            .overlay(
                                Circle()
                                    .stroke(Color.red, lineWidth: 4)
                            )
                            .overlay(
                                Text("💀")
                                    .font(.system(size: 40))
                                    .offset(x: 40, y: -40)
                            )
                            
                            Text(eliminated.team.ownerName)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.red)
                                .strikethrough()
                            
                            Text("FINAL SCORE: \(eliminated.weeklyPointsString)")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.gray)
                            
                            Text("\"Your journey ends here.\"")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.gray)
                                .italic()
                        }
                        .padding(.vertical, 20)
                    }
                    .transition(.opacity.combined(with: .scale))
                }
                
                Spacer()
                
                // Torch extinguishing button
                Button(action: {
                    dismiss()
                }) {
                    HStack {
                        Text("🕯️")
                        Text("EXTINGUISH THE TORCH")
                            .font(.system(size: 16, weight: .bold))
                            .tracking(1)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(Color.red.opacity(0.8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 25)
                                    .stroke(Color.orange, lineWidth: 2)
                            )
                    )
                }
            }
            .padding(.horizontal, 20)
        }
        .onAppear {
            torchFlicker = true
            
            // Dramatic delay before revealing elimination
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeInOut(duration: 1.0)) {
                    showElimination = true
                }
            }
        }
    }
}

// MARK: -> HISTORICAL ELIMINATION CARD 💀⚰️
struct HistoricalEliminationCard: View {
    let elimination: EliminationEvent
    
    var body: some View {
        HStack(spacing: 16) {
            // Week tombstone
            VStack {
                Text("⚰️")
                    .font(.system(size: 24))
                
                Text("WK \(elimination.week)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.red)
                    .tracking(1)
            }
            .frame(width: 50)
            
            // Eliminated team info
            VStack(alignment: .leading, spacing: 4) {
                Text(elimination.eliminatedTeam.team.ownerName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.gray)
                    .strikethrough()
                
                Text("💀 ELIMINATED WEEK \(elimination.week)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.red)
                
                if let lastWords = elimination.lastWords {
                    Text("\"\(lastWords)\"")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.gray)
                        .italic()
                }
                
                Text("Margin: \(elimination.marginDisplay) • \(elimination.dramaMeterDisplay)")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Final score and elimination details
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.2f", elimination.eliminationScore))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.red)
                
                Text("FINAL")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.gray)
                    .tracking(1)
                
                // Drama indicator
                HStack(spacing: 2) {
                    ForEach(0..<Int(elimination.dramaMeter * 5), id: \.self) { _ in
                        Text("💔")
                            .font(.system(size: 8))
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.red.opacity(0.2), lineWidth: 1)
                )
        )
    }
}