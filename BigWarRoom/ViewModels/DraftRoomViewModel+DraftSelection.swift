import Foundation

// MARK: - League & Draft Selection
extension DraftRoomViewModel {
    
    func selectDraft(_ leagueWrapper: UnifiedLeagueManager.LeagueWrapper) async {
        // ESPN leagues: Ask for position FIRST, then complete setup
        if leagueWrapper.source == .espn {
            // xprint("🏈 ESPN league selected - prompting for draft position first")
            // xprint("   League: \(leagueWrapper.league.name)")
            // xprint("   Total Rosters: \(leagueWrapper.league.totalRosters)")
            
            // Store the league wrapper and show position prompt
            pendingESPNLeagueWrapper = leagueWrapper
            
            // Debug the maxTeamsInDraft calculation
            // xprint("   maxTeamsInDraft will be: \(maxTeamsInDraft)")
            
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
                
                // xprint("🏈 Found \(rosters.count) rosters in league \(leagueID)")
                for (index, roster) in rosters.enumerated() {
                    // xprint("  Roster \(index + 1): ID=\(roster.rosterID), Owner=\(roster.ownerID ?? "nil"), Display=\(roster.ownerDisplayName ?? "nil")")
                }
                
                await setupRosterIdentification(leagueWrapper: leagueWrapper, rosters: rosters)
                await buildRosterDisplayInfo(rosters: rosters, leagueWrapper: leagueWrapper)
                
                // Only load actual roster if we have a roster ID
                if _myRosterID != nil {
                    await loadMyActualRoster()
                }
                
                // Initialize pick tracking
                lastPickCount = polling.allPicks.count
                lastMyPickCount = polling.allPicks.filter { $0.rosterID == _myRosterID }.count
                
            } catch {
                // xprint("🏈 Failed to fetch rosters for \(leagueWrapper.source.displayName) league: \(error)")
                draftRosters = [:]
                _myRosterID = nil
                myDraftSlot = nil
            }
        }
        
        await startDraftPolling(leagueWrapper: leagueWrapper)
        await refreshSuggestions()
    }
    
    private func setupRosterIdentification(leagueWrapper: UnifiedLeagueManager.LeagueWrapper, rosters: [SleeperRoster]) async {
        // ESPN leagues: Use the pre-selected draft pick to find roster
        if leagueWrapper.source == .espn {
            // xprint("🏈 ESPN league - using pre-selected draft pick: \(myDraftSlot ?? -1)")
            
            // FIXED: Pure positional logic - ignore ESPN teamIds completely
            if let draftPosition = myDraftSlot {
                // Don't try to match roster IDs - just use pure draft slot logic
                _myRosterID = nil // Set to nil - we'll use draft slot matching instead
                // xprint("🏈 ESPN: Using pure positional logic for draft slot \(draftPosition)")
                // xprint("🏈 Your picks will be calculated using snake draft math from position \(draftPosition)")
            } else {
                // xprint("🏈 Could not determine draft position for ESPN league")
            }
            
        } else {
            // Sleeper leagues: Use Sleeper user ID matching
            if let userID = currentUserID {
                // xprint("🏈 Sleeper league - looking for my roster with userID: \(userID)")
                if let myRoster = rosters.first(where: { $0.ownerID == userID }) {
                    _myRosterID = myRoster.rosterID
                    myDraftSlot = myRoster.draftSlot
                    // xprint("🏈 Found MY Sleeper roster! RosterID: \(myRoster.rosterID), DraftSlot: \(myRoster.draftSlot ?? -1)")
                } else {
                    // xprint("🏈 Could not find my roster with Sleeper userID: \(userID)")
                }
            }
        }
        
        if _myRosterID == nil {
            // xprint("🏈 Could not identify my roster in this league")
        } else {
            // xprint("🏈 Successfully identified my roster: ID=\(_myRosterID!), DraftSlot=\(myDraftSlot ?? -1)")
        }
    }
    
    private func buildRosterDisplayInfo(rosters: [SleeperRoster], leagueWrapper: UnifiedLeagueManager.LeagueWrapper) async {
        var info: [Int: DraftRosterInfo] = [:]

        // xprint("🔍 DEBUG: Building draftRosters dictionary...")
        // xprint("   Found \(rosters.count) rosters in league")
        // xprint("   League source: \(leagueWrapper.source)")
        
        for roster in rosters {
            // xprint("   Processing roster \(roster.rosterID):")
            // xprint("     ownerID: \(roster.ownerID ?? "nil")")
            // xprint("     draftSlot: \(roster.draftSlot ?? -1)")
            // xprint("     ownerDisplayName: \(roster.ownerDisplayName ?? "nil")")
            // xprint("     teamName: \(roster.metadata?.teamName ?? "nil")")
            // xprint("     ownerName: \(roster.metadata?.ownerName ?? "nil")")
            
            let displayName = await resolveRosterDisplayName(for: roster)
            
            info[roster.rosterID] = DraftRosterInfo(
                rosterID: roster.rosterID,
                ownerID: roster.ownerID,
                displayName: displayName
            )
            
            // xprint("     Final result: rosterID \(roster.rosterID) → '\(displayName)' (draftSlot: \(roster.draftSlot ?? -1))")
        }
        
        // xprint("🔍 Final draftRosters mapping:")
        for (rosterID, rosterInfo) in info.sorted(by: { $0.key < $1.key }) {
            // xprint("   RosterID \(rosterID): '\(rosterInfo.displayName)' (owner: \(rosterInfo.ownerID ?? "nil"))")
        }
        
        draftRosters = info
    }
    
    private func resolveRosterDisplayName(for roster: SleeperRoster) async -> String {
        var displayName: String? = nil

        // For ESPN leagues accessed through Sleeper, ALWAYS try Sleeper user lookup FIRST
        // Skip the generic ESPN team names and go straight to Sleeper user data
        if let ownerID = roster.ownerID, !ownerID.isEmpty {
            // xprint("     Trying Sleeper user lookup for ownerID: \(ownerID)")
            
            // Try cache first
            if let cached = userCache[ownerID] {
                displayName = cached.displayName ?? cached.username
                // xprint("     ✅ Using cached user: \(displayName ?? "nil")")
            } else {
                // Fetch and store in cache
                do {
                    let fetched = try await sleeperClient.fetchUserByID(userID: ownerID)
                    userCache[ownerID] = fetched
                    displayName = fetched.displayName ?? fetched.username
                    // xprint("     ✅ Fetched user: \(displayName ?? "nil") (username: \(fetched.username))")
                } catch {
                    // xprint("     ❌ Could not fetch user for ownerID \(ownerID): \(error)")
                    displayName = nil
                }
            }
        }
        
        // Only fall back to roster metadata if Sleeper lookup failed
        if displayName == nil || displayName!.isEmpty {
            if let name = roster.metadata?.teamName, !name.isEmpty, !name.hasPrefix("Team ") {
                displayName = name
                // xprint("     Using non-generic teamName: \(name)")
            } else if let ownerName = roster.metadata?.ownerName, !ownerName.isEmpty {
                displayName = ownerName
                // xprint("     Using ownerName: \(ownerName)")
            } else if let ownerDisplayName = roster.ownerDisplayName, !ownerDisplayName.isEmpty, !ownerDisplayName.hasPrefix("Team ") {
                displayName = ownerDisplayName
                // xprint("     Using non-generic ownerDisplayName: \(ownerDisplayName)")
            }
        }

        if displayName == nil || displayName!.isEmpty {
            displayName = "Team \(roster.rosterID)"
            // xprint("     Using fallback: \(displayName!)")
        }
        
        return displayName!
    }
    
    private func startDraftPolling(leagueWrapper: UnifiedLeagueManager.LeagueWrapper) async {
        // Start polling the actual draft
        if let draftID = leagueWrapper.league.draftID {
            // xprint("🏈 Checking draft status before starting polling...")
            
            // For ESPN leagues, check if draft is actually live before polling
            if leagueWrapper.source == .espn {
                await handleESPNDraftPolling(draftID: draftID, apiClient: leagueWrapper.client)
            } else {
                // For Sleeper leagues, always start polling (they handle it well)
                // xprint("🏈 Sleeper league - starting polling for draftID: \(draftID)")
                polling.startPolling(draftID: draftID, apiClient: leagueWrapper.client)
            }
        } else {
            // xprint("🏈 No draftID found for league: \(leagueWrapper.league.name)")
            // For ESPN leagues, try using the league ID as draft ID
            if leagueWrapper.source == .espn {
                // xprint("🏈 ESPN league - trying to use leagueID as draftID: \(leagueWrapper.league.leagueID)")
                await handleESPNDraftPolling(draftID: leagueWrapper.league.leagueID, apiClient: leagueWrapper.client)
            }
        }
    }
    
    private func handleESPNDraftPolling(draftID: String, apiClient: DraftAPIClient) async {
        // Try to get draft status first
        do {
            let draft = try await apiClient.fetchDraft(draftID: draftID)
            
            // xprint("🏈 ESPN Draft Status: \(draft.status.rawValue)")
            // xprint("🏈 Draft Type: \(draft.type.rawValue)")
            
            // FIXED: Be more liberal about when to poll - poll for any active/upcoming status
            if draft.status.isActiveOrUpcoming {
                // xprint("🏈 ✅ ESPN draft is ACTIVE/UPCOMING (status: \(draft.status.rawValue)) - starting polling")
                polling.startPolling(draftID: draftID, apiClient: apiClient)
            } else {
                // xprint("🏈 🚫 ESPN draft is COMPLETED (status: \(draft.status.rawValue)) - fetching final picks only")
                
                // Fetch picks once for display but don't start continuous polling
                do {
                    let picks = try await apiClient.fetchDraftPicks(draftID: draftID)
                    // xprint("🏈 ✅ Fetched \(picks.count) completed draft picks for display")
                    
                    // Update polling service with the completed data without starting timer
                    await polling.setCompletedDraftData(draft: draft, picks: picks)
                } catch {
                    // xprint("🏈 ⚠️ Could not fetch completed draft picks: \(error)")
                }
            }
        } catch {
            // xprint("🏈 ⚠️ Could not check ESPN draft status: \(error)")
            // xprint("    Defaulting to polling (might be necessary for some ESPN leagues)")
            polling.startPolling(draftID: draftID, apiClient: apiClient)
        }
    }
    
    /// Handle ESPN draft pick selection
    func setESPNDraftPosition(_ position: Int) async {
        guard let pendingWrapper = pendingESPNLeagueWrapper else {
            // xprint("🏈 No pending ESPN league to configure")
            return
        }
        
        // xprint("🏈 ESPN draft pick selected: \(position)")
        
        // Set the position first
        myDraftSlot = position
        
        // Clear pending state
        pendingESPNLeagueWrapper = nil
        showingESPNPickPrompt = false
        
        // Now complete the league selection with position set
        await completeLeagueSelection(pendingWrapper)
        
        // FIXED: Auto-navigate to Fantasy tab for ANY draft position confirmation as requested by Gp
        DispatchQueue.main.async {
            NSLog("🏈 Position \(position) selected - auto-navigating to Fantasy tab")
            // Use notification to communicate with parent view
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
        // xprint("🏈 ESPN league selection cancelled")
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
                        _myRosterID = myRoster.rosterID
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
                lastMyPickCount = polling.allPicks.filter { $0.rosterID == _myRosterID }.count
                
            } catch {
                draftRosters = [:]
                _myRosterID = nil
                myDraftSlot = nil
            }
        }
        
        if let draftID = league.draftID {
            polling.startPolling(draftID: draftID)
        }
        
        await refreshSuggestions()
    }
}