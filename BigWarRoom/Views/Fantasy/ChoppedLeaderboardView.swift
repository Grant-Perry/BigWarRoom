//
//  ChoppedLeaderboardView.swift
//  BigWarRoom
//
//  🔥💀 CHOPPED LEAGUE BATTLE ROYALE 💀🔥
//  The most INSANE elimination fantasy football experience
//
// MARK: -> CHOPPED APOCALYPSE LEADERBOARD 

import SwiftUI

/// **ChoppedLeaderboardView**
/// 
/// Main view for the Chopped elimination leaderboard. Now properly architected with:
/// - MVVM pattern using ChoppedLeaderboardViewModel
/// - Extracted components in separate files
/// - Clean separation of business logic and presentation
/// - DRY principles throughout
/// - 🔥 NEW: Tappable team cards to view rosters
struct ChoppedLeaderboardView: View {
    @StateObject private var viewModel: ChoppedLeaderboardViewModel
    let leagueID: String // 🔥 NEW: Pass league ID for roster navigation
    
    // MARK: - Navigation State (NEW!)
    @State private var showingMyRoster = false
    
    // MARK: - Initialization
    init(choppedSummary: ChoppedWeekSummary, leagueName: String, leagueID: String) {
        self._viewModel = StateObject(wrappedValue: ChoppedLeaderboardViewModel(
            choppedSummary: choppedSummary,
            leagueName: leagueName
        ))
        self.leagueID = leagueID // 🔥 NEW: Store league ID
    }
    
    var body: some View {
        ZStack {
            // APOCALYPTIC BACKGROUND
            apocalypticBackground
            
            ScrollView {
                VStack(spacing: 0) {
                    // BATTLE ROYALE HEADER
                    battleRoyaleHeader
                    
                    // SURVIVAL STATS (only if week started)
                    if viewModel.shouldShowSurvivalStats {
                        survivalStats
                    } else {
                        preGameMessage
                    }
                    
                    // CHAMPION THRONE (only if week started)
                    if viewModel.hasChampion, let champion = viewModel.choppedSummary.champion {
                        championSection(champion)
                    }
                    
                    // If week hasn't started, show all teams in neutral waiting state
                    if !viewModel.hasWeekStarted {
                        allTeamsWaitingSection
                    } else {
                        // Normal ranked sections when week has started
                        
                        // SAFE ZONE
                        if viewModel.hasSafeTeams {
                            survivalSection(
                                title: "🛡️ SAFE ZONE",
                                subtitle: "Living to fight another week",
                                teams: viewModel.choppedSummary.safeTeams,
                                sectionColor: .green
                            )
                        }
                        
                        // WARNING ZONE
                        if viewModel.hasWarningTeams {
                            survivalSection(
                                title: "⚡ WARNING ZONE",
                                subtitle: "Treading dangerous waters",
                                teams: viewModel.choppedSummary.warningTeams,
                                sectionColor: .blue
                            )
                        }
                        
                        // DANGER ZONE - PULSING RED
                        if viewModel.hasDangerZoneTeams {
                            dangerZoneSection
                        }
                        
                        // CRITICAL ZONE - DEATH ROW
                        if viewModel.hasCriticalTeams {
                            criticalZoneSection
                        }
                    }
                    
                    // HALL OF THE DEAD (always show if there's history)
                    if viewModel.hasEliminationHistory {
                        eliminatedHistorySection
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            viewModel.startAnimations()
        }
        .sheet(isPresented: $viewModel.showEliminationCeremony) {
            EliminationCeremonyView(
                eliminatedTeam: viewModel.choppedSummary.eliminatedTeam,
                week: viewModel.choppedSummary.week
            )
        }
        .sheet(isPresented: $showingMyRoster) {
            // NEW: Your roster sheet
            if let myTeam = viewModel.myTeamRanking {
                ChoppedTeamRosterView(
                    teamRanking: myTeam,
                    leagueID: leagueID,
                    week: viewModel.choppedSummary.week
                )
            }
        }
    }
    
    // MARK: -> APOCALYPTIC BACKGROUND
    private var apocalypticBackground: some View {
        ZStack {
            // Base dark background
            Color.black.ignoresSafeArea()
            
            // Animated danger gradient for critical situations
            if viewModel.shouldShowDangerBackground {
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
                .opacity(viewModel.dangerPulse ? 0.3 : 0.1)
                .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: viewModel.dangerPulse)
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
                    .scaleEffect(viewModel.pulseAnimation ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: viewModel.pulseAnimation)
                
                VStack {
                    Text(viewModel.dramaticLeagueName)
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.red, .orange, .yellow, .orange, .red],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .shadow(color: .red.opacity(0.5), radius: 2, x: 0, y: 1)
                }
                
                Text("🔥")
                    .font(.system(size: 32))
                    .scaleEffect(viewModel.pulseAnimation ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true).delay(0.5), value: viewModel.pulseAnimation)
            }
            
            // WEEK ELIMINATION ROUND HEADER with intense gradients
            VStack(spacing: 8) {
                Text("WEEK \(viewModel.choppedSummary.week)")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .gray, .white],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .tracking(2)
                    .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                
                Text("ELIMINATION ROUND")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.red, .orange, .red],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .tracking(3)
                    .shadow(color: .red.opacity(0.3), radius: 1, x: 0, y: 0)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.red.opacity(0.2),
                                Color.black,
                                Color.red.opacity(0.1),
                                Color.black
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                LinearGradient(
                                    colors: [.red, .orange, .red],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 2
                            )
                            .opacity(viewModel.pulseAnimation ? 1.0 : 0.7)
                            .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: viewModel.pulseAnimation)
                    )
            )
            
            // Week and survival info with enhanced backgrounds
            HStack(spacing: 8) {
                // SURVIVORS stat card with green gradient
                VStack(spacing: 4) {
                    Text(viewModel.survivorsCount)
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.green, .mint, .green],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    
                    Text("SURVIVORS")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.green)
                        .tracking(1)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.green.opacity(0.2),
                                    Color.green.opacity(0.05)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.green.opacity(0.4), lineWidth: 1)
                        )
                )
                
                // Red separator with glow
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, .red, .red, .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 2, height: 40)
                    .shadow(color: .red.opacity(0.6), radius: 2, x: 0, y: 0)
                
                // ELIMINATED stat card with red gradient
                VStack(spacing: 4) {
                    Text(viewModel.eliminatedCount)
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.red, .pink, .red],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    
                    Text("ELIMINATED")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.red)
                        .tracking(1)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.red.opacity(0.2),
                                    Color.red.opacity(0.05)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.red.opacity(0.4), lineWidth: 1)
                        )
                )
            }
            
            // Show pre-game message if week hasn't started with enhanced styling
            if !viewModel.hasWeekStarted {
                HStack(spacing: 8) {
                    Text("⏰")
                        .font(.system(size: 16))
                        .scaleEffect(viewModel.pulseAnimation ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: viewModel.pulseAnimation)
                    
                    Text("GAMES HAVEN'T STARTED YET")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.orange, .yellow, .orange],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .tracking(1)
                    
                    Text("⏰")
                        .font(.system(size: 16))
                        .scaleEffect(viewModel.pulseAnimation ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true).delay(0.3), value: viewModel.pulseAnimation)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.orange.opacity(0.2),
                                    Color.yellow.opacity(0.1),
                                    Color.orange.opacity(0.2)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(
                                    LinearGradient(
                                        colors: [.orange, .yellow, .orange],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    lineWidth: 1.5
                                )
                                .opacity(viewModel.pulseAnimation ? 1.0 : 0.6)
                                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: viewModel.pulseAnimation)
                        )
                )
                .shadow(color: .orange.opacity(0.3), radius: 4, x: 0, y: 2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 24)
        .background(
            // Main header background with apocalyptic gradients
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black,
                            Color.red.opacity(0.1),
                            Color.black,
                            Color.orange.opacity(0.05),
                            Color.black
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [.red, .orange, .yellow, .orange, .red],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 3
                        )
                        .opacity(viewModel.pulseAnimation ? 1.0 : 0.8)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: viewModel.pulseAnimation)
                )
        )
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .shadow(color: .red.opacity(0.2), radius: 8, x: 0, y: 4)
    }
    
    // MARK: -> SURVIVAL STATS (Only show if week has started)
    private var survivalStats: some View {
        Group {
            if viewModel.shouldShowSurvivalStats {
                // Single row with all 5 compact stat cards
                HStack(spacing: 6) {
                    // Your personal stats card (COMPACT!)
                    compactPersonalStatCard
                    
                    compactStatCard(
                        title: "ALIVE",
                        value: viewModel.survivorsCount,
                        subtitle: "TEAMS",
                        color: .green
                    )
                    
                    compactStatCard(
                        title: "CUTOFF",
                        value: viewModel.eliminationLineDisplay,
                        subtitle: "LINE",
                        color: .red
                    )
                    
                    compactStatCard(
                        title: "AVG",
                        value: viewModel.averageScoreDisplay,
                        subtitle: "MEAN",
                        color: .blue
                    )
                    
                    compactStatCard(
                        title: "HIGH",
                        value: viewModel.topScoreDisplay,
                        subtitle: "WEEK",
                        color: .yellow
                    )
                }
                .padding(.horizontal, 24) // Increased from 20 to 24 to prevent border clipping
                .padding(.vertical, 8)
            } else {
                // Show pre-game message instead of stats
                VStack(spacing: 12) {
                    Text("📊 BATTLE STATS UNAVAILABLE")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.gray)
                        .tracking(1)
                    
                    Text("Rankings and survival percentages will appear once games begin")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                .padding(.vertical, 20)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: -> COMPACT STAT CARD
    private func compactStatCard(title: String, value: String, subtitle: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.gray)
                .tracking(0.5)
            
            Text(value)
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(
                    LinearGradient(
                        colors: [color, color.opacity(0.7), color],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            Text(subtitle)
                .font(.system(size: 7, weight: .medium))
                .foregroundColor(.gray)
                .tracking(0.3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [
                            color.opacity(0.15),
                            color.opacity(0.05)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            LinearGradient(
                                colors: [color.opacity(0.4), color.opacity(0.2)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: color.opacity(0.2), radius: 2, x: 0, y: 1)
    }
    
    // MARK: -> COMPACT PERSONAL STAT CARD
    private var compactPersonalStatCard: some View {
        Button(action: {
            // Show your roster using SwiftUI sheet navigation
            showingMyRoster = true
        }) {
            VStack(spacing: 4) {
                // Your rank badge (smaller)
                HStack(spacing: 2) {
                    Text(viewModel.myRankDisplay)
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(viewModel.myStatusColor)
                        )
                    
                    Text("YOU")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(.gray)
                        .tracking(0.3)
                }
                
                // Your score (smaller)
                Text(viewModel.myScoreDisplay)
                    .font(.system(size: 16, weight: .black))
                    .foregroundColor(viewModel.myStatusColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                // Your status (compact)
                HStack(spacing: 2) {
                    Text(viewModel.myStatusEmoji)
                        .font(.system(size: 8))
                    
                    Text(viewModel.myStatusText)
                        .font(.system(size: 7, weight: .medium))
                        .foregroundColor(viewModel.myStatusColor)
                        .tracking(0.3)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(viewModel.myStatusColor.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(viewModel.myStatusColor.opacity(0.3), lineWidth: 1.5)
                            .shadow(color: viewModel.myStatusColor.opacity(0.2), radius: 2)
                    )
            )
            .scaleEffect(viewModel.pulseAnimation && viewModel.isMyTeamInDanger ? 1.03 : 1.0)
            .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: viewModel.pulseAnimation)
        }
        .buttonStyle(PlainButtonStyle()) // Prevents default button styling
    }
    
    // MARK: -> CHAMPION SECTION
    private func championSection(_ champion: FantasyTeamRanking) -> some View {
        VStack(spacing: 16) {
            // Crown header with dynamic week
            HStack {
                Text("👑")
                    .font(.system(size: 24))
                
                Text("\(viewModel.weekDisplay) LEADER")
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
            
            // Champion card with tap functionality
            ChampionCard(
                ranking: champion,
                leagueID: leagueID, // 🔥 NEW: Pass league ID
                week: viewModel.choppedSummary.week // 🔥 NEW: Pass week
            )
        }
        .padding(.horizontal, 16)
        .padding(.top, 4) // Reduced top padding to tighten gap
        .padding(.bottom, 20)
    }
    
    // MARK: -> DANGER ZONE SECTION (PULSING)
    private var dangerZoneSection: some View {
        VStack(spacing: 16) {
            // Danger header with pulsing effect
            HStack {
                Text("⚠️")
                    .font(.system(size: 20))
                    .scaleEffect(viewModel.dangerPulse ? 1.3 : 1.0)
                    .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: viewModel.dangerPulse)
                
                Text("DANGER ZONE")
                    .font(.system(size: 18, weight: .black))
                    .foregroundColor(.orange)
                    .tracking(2)
                
                Text("⚠️")
                    .font(.system(size: 20))
                    .scaleEffect(viewModel.dangerPulse ? 1.3 : 1.0)
                    .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true).delay(0.5), value: viewModel.dangerPulse)
                
                Spacer()
                
                Text("\(viewModel.dangerZoneCount) IN DANGER")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.orange)
            }
            
            Text("🚨 ONE STEP AWAY FROM THE CHOPPING BLOCK 🚨")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .center)
            
            // Death zone teams with tap functionality
            ForEach(viewModel.choppedSummary.dangerZoneTeams) { ranking in
                DangerZoneCard(
                    ranking: ranking,
                    leagueID: leagueID, // 🔥 NEW: Pass league ID
                    week: viewModel.choppedSummary.week // 🔥 NEW: Pass week
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.orange.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.orange.opacity(viewModel.dangerPulse ? 0.6 : 0.3), lineWidth: 2)
                        .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: viewModel.dangerPulse)
                )
        )
        .padding(.horizontal, 16)
    }
    
    // MARK: -> CRITICAL ZONE (DEATH ROW)
    private var criticalZoneSection: some View {
        VStack(spacing: 16) {
            // Critical header - MOST DRAMATIC
            HStack {
                Text("💀")
                    .font(.system(size: 24))
                    .scaleEffect(viewModel.pulseAnimation ? 1.5 : 1.0)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: viewModel.pulseAnimation)
                
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
                    .scaleEffect(viewModel.pulseAnimation ? 1.5 : 1.0)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true).delay(0.3), value: viewModel.pulseAnimation)
            }
            
            // Critical teams with tap functionality
            ForEach(viewModel.choppedSummary.criticalTeams) { ranking in
                CriticalCard(
                    ranking: ranking,
                    leagueID: leagueID, // 🔥 NEW: Pass league ID
                    week: viewModel.choppedSummary.week // 🔥 NEW: Pass week
                )
            }
            
            // Elimination ceremony button
            if viewModel.shouldShowEliminationCeremonyButton {
                Button(action: {
                    viewModel.showEliminationCeremonyModal()
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
        .padding(.horizontal, 16)
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
        .padding(.horizontal, 16)
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
            
            // Teams with tap functionality
            ForEach(teams) { ranking in
                SurvivalCard(
                    ranking: ranking,
                    leagueID: leagueID, // 🔥 NEW: Pass league ID
                    week: viewModel.choppedSummary.week // 🔥 NEW: Pass week
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(sectionColor.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(sectionColor.opacity(0.2), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
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
                
                Text("\(viewModel.fallenCount) FALLEN")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.red)
            }
            
            Text("\"They fought valiantly, but could not survive the chopping block...\"")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
                .italic()
                .frame(maxWidth: .infinity, alignment: .center)
            
            // 🔥 GRAVEYARD DISCLAIMER
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .font(.system(size: 12))
                    .foregroundColor(.orange)
                
                Text("Elimination weeks estimated - Sleeper doesn't chronicle the fallen")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.orange)
                    .italic()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.orange.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                    )
            )
            
            // Historical eliminations in chronological order
            ForEach(viewModel.choppedSummary.eliminationHistory) { elimination in
                HistoricalEliminationCard(elimination: elimination)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
    }
    
    // MARK: -> PRE-GAME MESSAGE
    private var preGameMessage: some View {
        VStack(spacing: 12) {
            Text("📊 GAMES HAVEN'T STARTED")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.orange)
                .tracking(1)
            
            Text("Tap any manager below to view their lineup")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
    }
    
    // MARK: -> ALL TEAMS WAITING SECTION (PRE-GAME)
    private var allTeamsWaitingSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("⏰ ALL MANAGERS")
                    .font(.system(size: 18, weight: .black))
                    .foregroundColor(.gray)
                    .tracking(1)
                
                Spacer()
                
                Text("\(viewModel.choppedSummary.rankings.count) TEAMS")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.gray)
            }
            
            Text("Waiting for games to begin...")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Show all teams without rankings - just in neutral waiting state
            ForEach(viewModel.choppedSummary.rankings.sorted(by: { $0.team.ownerName < $1.team.ownerName })) { ranking in
                WaitingTeamCard(
                    ranking: ranking,
                    leagueID: leagueID,
                    week: viewModel.choppedSummary.week
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
    }
}