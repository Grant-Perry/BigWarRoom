import Foundation

// MARK: - League & Draft Selection
extension DraftRoomViewModel {
    
    func selectDraft(_ leagueWrapper: UnifiedLeagueManager.LeagueWrapper) async {
        // ESPN leagues: Ask for position FIRST, then complete setup
        if leagueWrapper.source == .espn {
            DebugPrint(mode: .draft, "ESPN league selected - prompting for draft position first")
            DebugPrint(mode: .draft, "League: \(leagueWrapper.league.name)")
            DebugPrint(mode: .draft, "Total Rosters: \(leagueWrapper.league.totalRosters)")
            
            // Store the league wrapper and show position prompt
            pendingESPNLeagueWrapper = leagueWrapper
            
            // Initialize ESPN draft position to 1 (don't rely on selectedManualPosition)
            selectedESPNDraftPosition = 1
            
            showingESPNPickPrompt = true
            
            // Don't proceed with setup yet - wait for position selection
            return
        }
        
        // For Sleeper leagues, proceed normally
        await completeLeagueSelection(leagueWrapper)
    }
    
    /// Complete the league selection after position is determined (or for Sleeper leagues)
    internal func completeLeagueSelection(_ leagueWrapper: UnifiedLeagueManager.LeagueWrapper) async {
        selectedLeagueWrapper = leagueWrapper
        selectedDraft = leagueWrapper.league
        let apiClient = leagueWrapper.client
        
        // Fetch roster metadata and find MY roster
        if let leagueID = selectedDraft?.leagueID {
            do {
                let rosters = try await apiClient.fetchRosters(leagueID: leagueID)
                allLeagueRosters = rosters
                
                logDebug("Found \(rosters.count) rosters in league \(leagueID)", category: "DraftRoom")
                
                await setupRosterIdentification(leagueWrapper: leagueWrapper, rosters: rosters)
                await buildRosterDisplayInfo(rosters: rosters, leagueWrapper: leagueWrapper)
                
                // Update roster coordinator with current context
                updateMyRosterInfo()
                
                // Only load actual roster if we have a roster ID
                if myRosterID != nil {
                    await loadMyActualRoster()
                }
                
                // Initialize pick tracking
                lastPickCount = polling.allPicks.count
                lastMyPickCount = polling.allPicks.filter { $0.rosterID == myRosterID }.count
                
            } catch {
                logError("Failed to fetch rosters for \(leagueWrapper.source.displayName) league: \(error)", category: "DraftRoom")
                draftRosters = [:]
                myDraftSlot = nil
                updateMyRosterInfo()
            }
        }
        
        await startDraftPolling(leagueWrapper: leagueWrapper)
        await refreshSuggestions()
    }
    
    private func setupRosterIdentification(leagueWrapper: UnifiedLeagueManager.LeagueWrapper, rosters: [SleeperRoster]) async {
        // ESPN leagues: Use the pre-selected draft pick to find roster
        if leagueWrapper.source == .espn {
            logDebug("ESPN league - using pre-selected draft pick: \(myDraftSlot ?? -1)", category: "DraftRoom")
            
            if let draftPosition = myDraftSlot {
                // Use pure positional logic for ESPN - don't try to match roster IDs
                logDebug("ESPN: Using pure positional logic for draft slot \(draftPosition)", category: "DraftRoom")
                logDebug("Your picks will be calculated using snake draft math from position \(draftPosition)", category: "DraftRoom")
            } else {
                logWarning("Could not determine draft position for ESPN league", category: "DraftRoom")
            }
            
        } else {
            // Sleeper leagues: Use Sleeper user ID matching
            if let userID = currentUserID {
                logDebug("Sleeper league - looking for my roster with userID: \(userID)", category: "DraftRoom")
                if let myRoster = rosters.first(where: { $0.ownerID == userID }) {
                    // The roster coordinator doesn't support this delegate method
                    myDraftSlot = myRoster.draftSlot
                    logDebug("Found MY Sleeper roster! RosterID: \(myRoster.rosterID), DraftSlot: \(myRoster.draftSlot ?? -1)", category: "DraftRoom")
                } else {
                    logWarning("Could not find my roster with Sleeper userID: \(userID)", category: "DraftRoom")
                }
            }
        }
        
        if myRosterID == nil {
            logWarning("Could not identify my roster in this league", category: "DraftRoom")
        } else {
            logDebug("Successfully identified my roster: ID=\(myRosterID!), DraftSlot=\(myDraftSlot ?? -1)", category: "DraftRoom")
        }
    }
    
    private func buildRosterDisplayInfo(rosters: [SleeperRoster], leagueWrapper: UnifiedLeagueManager.LeagueWrapper) async {
        var info: [Int: DraftRosterInfo] = [:]

        DebugPrint(mode: .draft, "Building draftRosters dictionary for \(rosters.count) rosters")
        
        for roster in rosters {
            let displayName = await resolveRosterDisplayName(for: roster)
            
            info[roster.rosterID] = DraftRosterInfo(
                rosterID: roster.rosterID,
                ownerID: roster.ownerID,
                displayName: displayName
            )
        }
        
        draftRosters = info
    }
    
    private func resolveRosterDisplayName(for roster: SleeperRoster) async -> String {
        var displayName: String? = nil

        // For ESPN leagues accessed through Sleeper, ALWAYS try Sleeper user lookup FIRST
        if let ownerID = roster.ownerID, !ownerID.isEmpty {
            // Try cache first
            if let cached = userCache[ownerID] {
                displayName = cached.displayName ?? cached.username
                logDebug("Using cached user: \(displayName ?? "nil")", category: "DraftRoom")
            } else {
                // Fetch and store in cache
                do {
                    let fetched = try await sleeperClient.fetchUserByID(userID: ownerID)
                    userCache[ownerID] = fetched
                    displayName = fetched.displayName ?? fetched.username
                    logDebug("Fetched user: \(displayName ?? "nil") (username: \(fetched.username))", category: "DraftRoom")
                } catch {
                    logWarning("Could not fetch user for ownerID \(ownerID): \(error)", category: "DraftRoom")
                    displayName = nil
                }
            }
        }
        
        // Only fall back to roster metadata if Sleeper lookup failed
        if displayName == nil || displayName!.isEmpty {
            if let name = roster.metadata?.teamName, !name.isEmpty, !name.hasPrefix("Team ") {
                displayName = name
            } else if let ownerName = roster.metadata?.ownerName, !ownerName.isEmpty {
                displayName = ownerName
            } else if let ownerDisplayName = roster.ownerDisplayName, !ownerDisplayName.isEmpty, !ownerDisplayName.hasPrefix("Team ") {
                displayName = ownerDisplayName
            }
        }

        if displayName == nil || displayName!.isEmpty {
            displayName = "Team \(roster.rosterID)"
        }
        
        return displayName!
    }
    
    private func startDraftPolling(leagueWrapper: UnifiedLeagueManager.LeagueWrapper) async {
        // Start polling the actual draft
        if let draftID = leagueWrapper.league.draftID {
            DebugPrint(mode: .draft, "Checking draft status before starting polling...")
            
            // For ESPN leagues, check if draft is actually live before polling
            if leagueWrapper.source == .espn {
                await handleESPNDraftPolling(draftID: draftID, apiClient: leagueWrapper.client)
            } else {
                // For Sleeper leagues, always start polling (they handle it well)
                DebugPrint(mode: .draft, "Sleeper league - starting polling for draftID: \(draftID)")
                polling.startPolling(draftID: draftID, apiClient: leagueWrapper.client)
            }
        } else {
            DebugPrint(mode: .draft, "No draftID found for league: \(leagueWrapper.league.name)")
            // For ESPN leagues, try using the league ID as draft ID
            if leagueWrapper.source == .espn {
                DebugPrint(mode: .draft, "ESPN league - trying to use leagueID as draftID: \(leagueWrapper.league.leagueID)")
                await handleESPNDraftPolling(draftID: leagueWrapper.league.leagueID, apiClient: leagueWrapper.client)
            }
        }
    }
    
    private func handleESPNDraftPolling(draftID: String, apiClient: DraftAPIClient) async {
        // Try to get draft status first
        do {
            let draft = try await apiClient.fetchDraft(draftID: draftID)
            
            logDebug("ESPN Draft Status: \(draft.status.rawValue)", category: "DraftRoom")
            logDebug("Draft Type: \(draft.type.rawValue)", category: "DraftRoom")
            
            // Be more liberal about when to poll - poll for any active/upcoming status
            if draft.status.isActiveOrUpcoming {
                logInfo("ESPN draft is ACTIVE/UPCOMING (status: \(draft.status.rawValue)) - starting polling", category: "DraftRoom")
                polling.startPolling(draftID: draftID, apiClient: apiClient)
            } else {
                logInfo("ESPN draft is COMPLETED (status: \(draft.status.rawValue)) - fetching final picks only", category: "DraftRoom")
                
                // Fetch picks once for display but don't start continuous polling
                do {
                    let picks = try await apiClient.fetchDraftPicks(draftID: draftID)
                    logInfo("Fetched \(picks.count) completed draft picks for display", category: "DraftRoom")
                    
                    // Update polling service with the completed data without starting timer
                    await polling.setCompletedDraftData(draft: draft, picks: picks)
                } catch {
                    logWarning("Could not fetch completed draft picks: \(error)", category: "DraftRoom")
                }
            }
        } catch {
            logWarning("Could not check ESPN draft status: \(error)", category: "DraftRoom")
            logDebug("Defaulting to polling (might be necessary for some ESPN leagues)", category: "DraftRoom")
            polling.startPolling(draftID: draftID, apiClient: apiClient)
        }
    }
    
    /// Handle ESPN draft pick selection
    func setESPNDraftPosition(_ position: Int) async {
        guard let pendingWrapper = pendingESPNLeagueWrapper else {
            logWarning("No pending ESPN league to configure", category: "DraftRoom")
            return
        }
        
        logDebug("ESPN draft pick selected: \(position)", category: "DraftRoom")
        
        // Set the position first
        myDraftSlot = position
        updateMyRosterInfo()
        
        // Clear pending state
        pendingESPNLeagueWrapper = nil
        showingESPNPickPrompt = false
        
        // Now complete the league selection with position set
        await completeLeagueSelection(pendingWrapper)
        
        // Auto-navigate to Fantasy tab
        DispatchQueue.main.async {
            NSLog("🏈 Position \(position) selected - auto-navigating to Fantasy tab")
            NotificationCenter.default.post(
                name: Notification.Name("NavigateToFantasy"), 
                object: nil
            )
        }
    }
    
    /// Cancel ESPN pick selection
    func cancelESPNPositionSelection() {
        pendingESPNLeagueWrapper = nil
        showingESPNPickPrompt = false
        logDebug("ESPN league selection cancelled", category: "DraftRoom")
    }
    
    // Legacy method for backward compatibility
    func selectDraft(_ league: SleeperLeague) async {
        // Find the corresponding league wrapper
        if let wrapper = allAvailableDrafts.first(where: { $0.league.id == league.id }) {
            await selectDraft(wrapper)
        } else {
            // Fallback to legacy behavior - this is getting long, but kept for compatibility
            await legacySelectDraft(league)
        }
    }
    
    private func legacySelectDraft(_ league: SleeperLeague) async {
        selectedDraft = league
        selectedLeagueWrapper = nil
        
        if let leagueID = selectedDraft?.leagueID {
            do {
                let rosters = try await sleeperClient.fetchRosters(leagueID: leagueID)
                allLeagueRosters = rosters
                
                if let userID = currentUserID {
                    if let myRoster = rosters.first(where: { $0.ownerID == userID }) {
                        // if let defaultRosterCoordinator = rosterCoordinator as? DefaultDraftRosterCoordinator {
                        //     defaultRosterCoordinator.setMyRosterID(myRoster.rosterID)
                        // }
                        myDraftSlot = myRoster.draftSlot
                    }
                }
                
                var info: [Int: DraftRosterInfo] = [:]
                for roster in rosters {
                    let displayName = roster.ownerDisplayName ?? "Team \(roster.rosterID)"
                    info[roster.rosterID] = DraftRosterInfo(
                        rosterID: roster.rosterID,
                        ownerID: roster.ownerID,
                        displayName: displayName
                    )
                }
                draftRosters = info
                
                await loadMyActualRoster()
                
                lastPickCount = polling.allPicks.count
                lastMyPickCount = polling.allPicks.filter { $0.rosterID == myRosterID }.count
                
                updateMyRosterInfo()
                
            } catch {
                logError("Legacy draft selection failed: \(error)", category: "DraftRoom")
                draftRosters = [:]
                myDraftSlot = nil
                updateMyRosterInfo()
            }
        }
        
        if let draftID = league.draftID {
            polling.startPolling(draftID: draftID)
        }
        
        await refreshSuggestions()
    }
}