//
//  MatchupsHubViewModel+Loading.swift
//  BigWarRoom
//
//  Main loading logic for MatchupsHubViewModel
//

import Foundation
import SwiftUI
import Combine

// MARK: - Loading Operations
extension MatchupsHubViewModel {
    
    /// Main loading function - Load all matchups across all connected leagues
    internal func performLoadAllMatchups() async {
        guard !isLoading else { 
            DebugPrint(mode: .matchupLoading, "performLoadAllMatchups called - ALREADY LOADING, ignoring")
            return 
        }
        
        DebugPrint(mode: .matchupLoading, "🔥 STORE: performLoadAllMatchups STARTING")
        
        await MainActor.run {
            isLoading = true
            myMatchups = []
            errorMessage = nil
            currentLoadingLeague = "Loading from data store..."
            loadingProgress = 0.0
        }
        
        do {
            // Step 1: Fetch available leagues - 10% progress
            await updateProgress(0.10, message: "Loading available leagues...", sessionId: "STORE")
            
            let sleeperUserID = sleeperCredentials.getUserIdentifier()
            
            await unifiedLeagueManager.fetchAllLeagues(
                sleeperUserID: sleeperUserID,
                season: getCurrentYear()
            )
            
            let availableLeagues = unifiedLeagueManager.allLeagues
            
            guard !availableLeagues.isEmpty else {
                await MainActor.run {
                    errorMessage = "No leagues found. Connect your leagues first!"
                    isLoading = false
                }
                return
            }
            
            // Step 2: Convert to LeagueDescriptor and warm the store - 30% progress
            await updateProgress(0.30, message: "Warming data store...", sessionId: "STORE")
            
            let leagueDescriptors = availableLeagues.map { league in
                LeagueDescriptor(
                    id: league.league.leagueID,
                    name: league.league.name,
                    platform: league.source,
                    avatarURL: nil
                )
            }
            
            let currentWeek = getCurrentWeek()
            await matchupDataStore.warmLeagues(leagueDescriptors, week: currentWeek)
            
            // Step 3: Hydrate each matchup lazily - 30% -> 90% progress
            await updateProgress(0.40, message: "Loading matchups...", sessionId: "STORE")
            
            var loadedMatchups: [UnifiedMatchup] = []
            let totalLeagues = availableLeagues.count
            var processedLeagues = 0
            
            for league in availableLeagues {
                processedLeagues += 1
                
                // Create snapshot ID
                let snapshotID = MatchupSnapshot.ID(
                    leagueID: league.league.leagueID,
                    matchupID: "\(league.league.leagueID)_\(currentWeek)",
                    platform: league.source,
                    week: currentWeek
                )
                
                // Try to hydrate from store
                do {
                    let snapshot = try await matchupDataStore.hydrateMatchup(snapshotID)
                    
                    // 🔥 SINGLE CONVERSION POINT: Snapshot → UnifiedMatchup
                    let unifiedMatchup = convertSnapshotToUnifiedMatchup(snapshot, league: league)
                    loadedMatchups.append(unifiedMatchup)
                    
                } catch {
                    DebugPrint(mode: .matchupLoading, "❌ Failed to hydrate \(league.league.name): \(error)")
                }
                
                let progress = 0.40 + (Double(processedLeagues) / Double(totalLeagues)) * 0.50
                await updateProgress(progress, message: "Loaded \(processedLeagues) of \(totalLeagues)...", sessionId: "STORE")
            }
            
            // Update UI with loaded matchups
            await MainActor.run {
                self.myMatchups = loadedMatchups.sorted { $0.priority > $1.priority }
            }
            
            // Finalize - 100% progress
            await updateProgress(1.0, message: "Complete!", sessionId: "STORE")
            await finalizeLoading()
            
        }
        
        DebugPrint(mode: .matchupLoading, "🔥 STORE: performLoadAllMatchups COMPLETE - \(myMatchups.count) matchups")
    }
    
    /// 🔥 NEW: Bulletproof progress update that forces UI refresh
    private func updateProgress(_ progress: Double, message: String, sessionId: String) async {
        let clampedProgress = max(0.0, min(1.0, progress))
        
        await MainActor.run {
            self.loadingProgress = clampedProgress
            self.currentLoadingLeague = message
        }
    }
    
    /// Finalize the loading process
    private func finalizeLoading() async {
        await MainActor.run {
            self.isLoading = false
            self.currentLoadingLeague = ""
            self.lastUpdateTime = Date()
            
            // Sort final matchups by priority
            self.myMatchups.sort { $0.priority > $1.priority }
        }
        
        // 💊 RX: Check optimization status for all matchups after loading
        await refreshAllOptimizationStatuses()
    }
    
    /// Fetch NFL game data for live detection
    private func fetchNFLGameData() async {
        let selectedWeek = WeekSelectionManager.shared.selectedWeek
        let currentYear = Calendar.current.component(.year, from: Date())
        
        DebugPrint(mode: .weekCheck, "📅 MatchupsHub: Fetching NFL game data for user-selected week \(selectedWeek)")
        
        NFLGameDataService.shared.fetchGameData(forWeek: selectedWeek, year: currentYear)
    }
    
    // MARK: - 🔥 SINGLE SOURCE OF TRUTH: Snapshot → UnifiedMatchup Conversion
    
    /// Convert MatchupSnapshot to UnifiedMatchup (SINGLE conversion point for SSOT)
    /// This is the ONLY place where we convert from domain model (snapshot) to view model (UnifiedMatchup)
    internal func convertSnapshotToUnifiedMatchup(_ snapshot: MatchupSnapshot, league: UnifiedLeagueManager.LeagueWrapper) -> UnifiedMatchup {
        // Build FantasyMatchup from snapshot
        let fantasyMatchup = FantasyMatchup(
            id: snapshot.id.matchupID,
            leagueID: snapshot.id.leagueID,
            week: snapshot.id.week,
            year: getCurrentYear(),
            homeTeam: convertTeamSnapshot(snapshot.myTeam),
            awayTeam: convertTeamSnapshot(snapshot.opponentTeam),
            status: parseMatchupStatus(snapshot.metadata.status),
            winProbability: snapshot.myTeam.score.winProbability,
            startTime: snapshot.metadata.startTime,
            sleeperMatchups: nil
        )
        
        return UnifiedMatchup(
            id: snapshot.id.matchupID,
            league: league,
            fantasyMatchup: fantasyMatchup,
            choppedSummary: nil,  // TODO: Handle chopped leagues
            lastUpdated: snapshot.lastUpdated,
            myTeamRanking: nil,  // TODO: Handle chopped ranking
            myIdentifiedTeamID: snapshot.myTeam.info.teamID,
            authenticatedUsername: sleeperCredentials.currentUsername,
            allLeagueMatchups: nil  // TODO: Handle horizontal scrolling
        )
    }
    
    /// Convert TeamSnapshot to FantasyTeam
    private func convertTeamSnapshot(_ snapshot: TeamSnapshot) -> FantasyTeam {
        let roster = snapshot.roster.map { player in
            // Convert game status string back to GameStatus struct (if present)
            let gameStatus: GameStatus? = player.metrics.gameStatus.map { statusString in
                GameStatus(status: statusString)
            }
            
            return FantasyPlayer(
                id: player.id,
                sleeperID: player.identity.sleeperID,
                espnID: player.identity.espnID,
                firstName: player.identity.firstName,
                lastName: player.identity.lastName,
                position: player.context.position,
                team: player.context.team,
                jerseyNumber: player.context.jerseyNumber,
                currentPoints: player.metrics.currentScore,
                projectedPoints: player.metrics.projectedScore,
                gameStatus: gameStatus,
                isStarter: player.context.isStarter,
                lineupSlot: player.context.lineupSlot,
                injuryStatus: player.context.injuryStatus
            )
        }
        
        return FantasyTeam(
            id: snapshot.info.teamID,
            name: snapshot.info.ownerName,
            ownerName: snapshot.info.ownerName,
            record: parseRecord(snapshot.info.record),
            avatar: snapshot.info.avatarURL,
            currentScore: snapshot.score.actual,
            projectedScore: snapshot.score.projected,
            roster: roster,
            rosterID: Int(snapshot.info.teamID) ?? 0,
            faabTotal: nil,
            faabUsed: nil
        )
    }
    
    /// Parse record string into TeamRecord
    private func parseRecord(_ recordString: String) -> TeamRecord? {
        guard !recordString.isEmpty else { return nil }
        let parts = recordString.split(separator: "-")
        guard parts.count >= 2 else { return nil }
        let wins = Int(parts[0]) ?? 0
        let losses = Int(parts[1]) ?? 0
        let ties = parts.count > 2 ? Int(parts[2]) : nil
        return TeamRecord(wins: wins, losses: losses, ties: ties)
    }
    
    /// Parse matchup status string to enum
    private func parseMatchupStatus(_ statusString: String) -> MatchupStatus {
        switch statusString.lowercased() {
        case "live", "in_progress":
            return .live
        case "completed", "final":
            return .complete
        default:
            return .upcoming
        }
    }
}