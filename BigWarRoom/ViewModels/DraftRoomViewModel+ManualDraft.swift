import Foundation

// MARK: - Manual Draft Entry & Position Selection
extension DraftRoomViewModel {
    
    func connectToManualDraft(draftID: String) async {
        // Start polling immediately to show picks
        polling.startPolling(draftID: draftID)
        
        // Note: We can't directly modify connectionStatus since it's read-only from coordinator
        // But we can track the manual draft connection separately
        isConnectedToManualDraft = true
        
        // Try to fetch draft info for basic display
        do {
            let draft = try await sleeperClient.fetchDraft(draftID: draftID)
            manualDraftInfo = draft
            
            // Create a minimal league object for UI consistency
            let draftLeague = SleeperLeague(
                leagueID: draft.leagueID ?? "manual_\(draftID)",
                name: draft.metadata?.name ?? "Manual Draft",
                status: .drafting,
                sport: "nfl",
                season: AppConstants.currentSeasonYear,
                seasonType: "regular", 
                totalRosters: draft.settings?.teams ?? 12,
                draftID: draftID,
                avatar: nil,
                settings: SleeperLeagueSettings(
                    teams: draft.settings?.teams,
                    playoffTeams: nil,
                    playoffWeekStart: nil,
                    leagueAverageMatch: nil,
                    maxKeepers: nil,
                    tradeDeadline: nil,
                    reserveSlots: nil,
                    taxiSlots: nil,
                    leagueType: nil,
                    isChopped: nil,
                    type: nil
                ),
                scoringSettings: nil,
                rosterPositions: nil
            )
            selectedDraft = draftLeague
            
        } catch {
            logWarning("Could not fetch draft info: \(error)", category: "ManualDraft")
            // Create fallback league for display
            selectedDraft = SleeperLeague(
                leagueID: "manual_\(draftID)",
                name: "Manual Draft",
                status: .drafting,
                sport: "nfl",
                season: AppConstants.currentSeasonYear, 
                seasonType: "regular",
                totalRosters: 12,
                draftID: draftID,
                avatar: nil,
                settings: nil,
                scoringSettings: nil,
                rosterPositions: nil
            )
        }
        
        // If we have a connected user, try to enhance with roster correlation
        if let userID = currentUserID {
            let foundRoster = await enhanceManualDraftWithRosterCorrelation(draftID: draftID, userID: userID)
            
            // If we couldn't auto-detect, ask for manual position
            if !foundRoster {
                manualDraftNeedsPosition = true
                // Ensure selectedManualPosition is valid for this draft
                let teamCount = manualDraftInfo?.settings?.teams ?? selectedDraft?.totalRosters ?? 16
                if selectedManualPosition > teamCount {
                    selectedManualPosition = 1
                }
            } else {
                // Only close if we successfully auto-detected the roster
                showManualDraftEntry = false
            }
        } else {
            // Not connected to Sleeper - ask for manual position
            manualDraftNeedsPosition = true
            // Ensure selectedManualPosition is valid for this draft
            let teamCount = manualDraftInfo?.settings?.teams ?? selectedDraft?.totalRosters ?? 16
            if selectedManualPosition > teamCount {
                selectedManualPosition = 1
            }
        }
        
        await refreshSuggestions()
    }

    /// Enhanced manual draft connection with full roster correlation
    /// Returns true if roster was found, false if manual position needed
    private func enhanceManualDraftWithRosterCorrelation(draftID: String, userID: String) async -> Bool {
        do {
            logDebug("Fetching draft info for manual draft: \(draftID)", category: "ManualDraft")
            let draft = try await sleeperClient.fetchDraft(draftID: draftID)
            
            guard let leagueID = draft.leagueID else {
                logInfo("Draft \(draftID) has no league ID - likely a mock draft", category: "ManualDraft")
                return false
            }
            
            logDebug("Found league ID: \(leagueID)", category: "ManualDraft")
            
            // Fetch league info to create a SleeperLeague object
            let league = try await sleeperClient.fetchLeague(leagueID: leagueID)
            logInfo("Fetched league: \(league.name)", category: "ManualDraft")
            
            // Fetch league rosters
            let rosters = try await sleeperClient.fetchRosters(leagueID: leagueID)
            allLeagueRosters = rosters
            
            // Find MY roster by matching owner ID with current user ID
            if let myRoster = rosters.first(where: { $0.ownerID == userID }) {
                // Update roster coordinator
                if let defaultRosterCoordinator = rosterCoordinator as? DefaultDraftRosterCoordinator {
                    defaultRosterCoordinator.setMyRosterID(myRoster.rosterID)
                }
                myDraftSlot = myRoster.draftSlot
                
                logInfo("Found your roster! ID: \(myRoster.rosterID), DraftSlot: \(myRoster.draftSlot ?? -1)", category: "ManualDraft")
                
                // Set up draft roster info for display
                var info: [Int: DraftRosterInfo] = [:]
                
                for roster in rosters {
                    let displayName = await resolveDisplayNameForManualDraft(roster: roster)
                    
                    info[roster.rosterID] = DraftRosterInfo(
                        rosterID: roster.rosterID,
                        ownerID: roster.ownerID,
                        displayName: displayName
                    )
                }
                
                draftRosters = info
                
                // Update selectedDraft with real league info
                selectedDraft = league
                
                // Load your actual roster from the league
                await loadMyActualRoster()
                
                // Initialize pick tracking for alerts
                lastPickCount = polling.allPicks.count
                lastMyPickCount = polling.allPicks.filter { $0.rosterID == myRosterID }.count
                
                updateMyRosterInfo()
                
                logInfo("Manual draft enhanced! Pick alerts and roster correlation enabled.", category: "ManualDraft")
                return true
                
            } else {
                logWarning("Could not find your roster in league \(leagueID)", category: "ManualDraft")
                return false
            }
            
        } catch {
            logError("Failed to enhance manual draft: \(error)", category: "ManualDraft")
            return false
        }
    }
    
    private func resolveDisplayNameForManualDraft(roster: SleeperRoster) async -> String {
        var displayName: String? = nil

        // Team name from roster metadata
        if let name = roster.metadata?.teamName, !name.isEmpty {
            displayName = name
        } else if let ownerName = roster.metadata?.ownerName, !ownerName.isEmpty {
            displayName = ownerName
        } else if let ownerDisplayName = roster.ownerDisplayName, !ownerDisplayName.isEmpty {
            displayName = ownerDisplayName
        } else if let ownerID = roster.ownerID, !ownerID.isEmpty {
            // Try cache first
            if let cached = userCache[ownerID] {
                displayName = cached.displayName ?? cached.username
            } else {
                // Fetch and store in cache
                do {
                    let fetched = try await sleeperClient.fetchUserByID(userID: ownerID)
                    userCache[ownerID] = fetched
                    displayName = fetched.displayName ?? fetched.username
                } catch {
                    logWarning("Could not fetch user for ownerID \(ownerID): \(error)", category: "ManualDraft")
                    displayName = nil
                }
            }
        }

        if displayName == nil || displayName!.isEmpty {
            displayName = "Team \(roster.rosterID)"
        }
        
        return displayName!
    }

    /// Set manual draft position when auto-detection fails or for ESPN leagues
    func setManualDraftPosition(_ position: Int) {
        myDraftSlot = position
        manualDraftNeedsPosition = false
        updateMyRosterInfo()
        
        // For ESPN leagues, we need to find the roster ID that corresponds to this draft pick
        if let leagueWrapper = selectedLeagueWrapper, leagueWrapper.source == .espn {
            // Find the roster with this roster ID (ESPN roster ID = draft pick number)
            if let matchingRoster = allLeagueRosters.first(where: { $0.rosterID == position }) {
                // Update roster coordinator
                if let defaultRosterCoordinator = rosterCoordinator as? DefaultDraftRosterCoordinator {
                    defaultRosterCoordinator.setMyRosterID(matchingRoster.rosterID)
                }
                logInfo("ESPN: Set roster ID \(matchingRoster.rosterID) for draft pick \(position)", category: "ManualDraft")
                
                // Load the actual roster now that we know which one is mine
                Task {
                    await loadMyActualRoster()
                }
            } else {
                logWarning("ESPN: Could not find roster with ID \(position)", category: "ManualDraft")
            }
        }
        
        // Now that position is set, we can close any manual draft entry UI
        showManualDraftEntry = false
        
        // Initialize pick tracking with manual position - count existing picks for this slot
        lastPickCount = polling.allPicks.count
        
        // Count picks already made for this draft slot
        let existingMyPicks = polling.allPicks.filter { $0.draftSlot == position }
        lastMyPickCount = existingMyPicks.count
        
        logInfo("Draft pick set to: \(position)", category: "ManualDraft")
        logDebug("Found \(existingMyPicks.count) existing picks for slot \(position)", category: "ManualDraft")
        
        // Update roster immediately with any existing picks for this position
        Task {
            await updateMyRosterFromPicks(polling.allPicks)
            await checkForTurnChange()
        }
    }

    func dismissManualPositionPrompt() {
        manualDraftNeedsPosition = false
        showManualDraftEntry = false
    }
}