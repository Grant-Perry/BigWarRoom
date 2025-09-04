import Foundation

// MARK: - Manual Draft Entry & Position Selection
extension DraftRoomViewModel {
    
    func connectToManualDraft(draftID: String) async {
        // Start polling immediately to show picks
        polling.startPolling(draftID: draftID)
        connectionStatus = .connected
        isConnectedToManualDraft = true
        
        // DON'T auto-close the manual draft entry yet - user still needs to select position
        // showManualDraftEntry = false
        
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
                season: "2024",
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
                    isChopped: nil
                ),
                scoringSettings: nil,
                rosterPositions: nil
            )
            selectedDraft = draftLeague
            
        } catch {
            // xprint("🏈 Could not fetch draft info: \(error)")
            // Create fallback league for display
            selectedDraft = SleeperLeague(
                leagueID: "manual_\(draftID)",
                name: "Manual Draft",
                status: .drafting,
                sport: "nfl",
                season: "2024", 
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
                    selectedManualPosition = 1 // Reset to valid position
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
                selectedManualPosition = 1 // Reset to valid position
            }
        }
        
        await refreshSuggestions()
    }

    /// Enhanced manual draft connection with full roster correlation
    /// Returns true if roster was found, false if manual position needed
    private func enhanceManualDraftWithRosterCorrelation(draftID: String, userID: String) async -> Bool {
        do {
            // Step 1: Fetch draft info to get league ID
            // xprint("🏈 Fetching draft info for manual draft: \(draftID)")
            let draft = try await sleeperClient.fetchDraft(draftID: draftID)
            
            guard let leagueID = draft.leagueID else {
                // xprint("🏈 Draft \(draftID) has no league ID - likely a mock draft")
                return false
            }
            
            // xprint("🏈 Found league ID: \(leagueID)")
            
            // Step 2: Fetch league info to create a SleeperLeague object
            let league = try await sleeperClient.fetchLeague(leagueID: leagueID)
            // xprint("🏈 Fetched league: \(league.name)")
            
            // Step 3: Fetch league rosters
            let rosters = try await sleeperClient.fetchRosters(leagueID: leagueID)
            allLeagueRosters = rosters
            
            // Step 4: Find MY roster by matching owner ID with current user ID
            if let myRoster = rosters.first(where: { $0.ownerID == userID }) {
                _myRosterID = myRoster.rosterID
                myDraftSlot = myRoster.draftSlot
                
                // xprint("🏈 Found your roster! ID: \(myRoster.rosterID), DraftSlot: \(myRoster.draftSlot ?? -1)")
                
                // Step 5: Set up draft roster info for display
                var info: [Int: DraftRosterInfo] = [:]
                
                // xprint("🔍 DEBUG: Building draftRosters dictionary...")
                // xprint("   Found \(rosters.count) rosters in league")
                
                for roster in rosters {
                    // xprint("   Processing roster \(roster.rosterID):")
                    // xprint("     ownerID: \(roster.ownerID ?? "nil")")
                    // xprint("     draftSlot: \(roster.draftSlot ?? -1)")
                    // xprint("     ownerDisplayName: \(roster.ownerDisplayName ?? "nil")")
                    // xprint("     teamName: \(roster.metadata?.teamName ?? "nil")")
                    // xprint("     ownerName: \(roster.metadata?.ownerName ?? "nil")")
                    
                    let displayName = await resolveDisplayNameForManualDraft(roster: roster)
                    
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
                
                // Step 6: Update selectedDraft with real league info
                selectedDraft = league
                
                // Step 7: Load your actual roster from the league
                await loadMyActualRoster()
                
                // Step 8: Initialize pick tracking for alerts
                lastPickCount = polling.allPicks.count
                lastMyPickCount = polling.allPicks.filter { $0.rosterID == _myRosterID }.count
                
                // xprint("🏈 Manual draft enhanced! Pick alerts and roster correlation enabled.")
                return true
                
            } else {
                // xprint("🏈 Could not find your roster in league \(leagueID)")
                // xprint("🏈 Available rosters: \(rosters.map { "\($0.rosterID): \($0.ownerID ?? "no owner")" })")
                return false
            }
            
        } catch {
            // xprint("🏈 Failed to enhance manual draft: \(error)")
            // xprint("🏈 Manual draft will work but without roster correlation")
            return false
        }
    }
    
    private func resolveDisplayNameForManualDraft(roster: SleeperRoster) async -> String {
        var displayName: String? = nil

        // Team name from roster metadata (usually blank unless user set it)
        if let name = roster.metadata?.teamName, !name.isEmpty {
            displayName = name
            // xprint("     Using teamName: \(name)")
        } else if let ownerName = roster.metadata?.ownerName, !ownerName.isEmpty {
            displayName = ownerName
            // xprint("     Using ownerName: \(ownerName)")
        } else if let ownerDisplayName = roster.ownerDisplayName, !ownerDisplayName.isEmpty {
            displayName = ownerDisplayName
            // xprint("     Using ownerDisplayName: \(ownerDisplayName)")
        } else if let ownerID = roster.ownerID, !ownerID.isEmpty {
            // ALWAYS try Sleeper user lookup for both Sleeper AND ESPN leagues
            // ESPN leagues still have Sleeper owner IDs if they're connected via Sleeper
            
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

        if displayName == nil || displayName!.isEmpty {
            displayName = "Team \(roster.rosterID)"
            // xprint("     Using fallback: \(displayName!)")
        }
        
        return displayName!
    }

    /// Set manual draft position when auto-detection fails or for ESPN leagues
    func setManualDraftPosition(_ position: Int) {
        myDraftSlot = position
        manualDraftNeedsPosition = false
        
        // For ESPN leagues, we need to find the roster ID that corresponds to this draft pick
        if let leagueWrapper = selectedLeagueWrapper, leagueWrapper.source == .espn {
            // Find the roster with this roster ID (ESPN roster ID = draft pick number)
            if let matchingRoster = allLeagueRosters.first(where: { $0.rosterID == position }) {
                _myRosterID = matchingRoster.rosterID
                // xprint("🏈 ESPN: Set roster ID \(matchingRoster.rosterID) for draft pick \(position)")
                
                // Load the actual roster now that we know which one is mine
                Task {
                    await loadMyActualRoster()
                }
            } else {
                // xprint("🏈 ESPN: Could not find roster with ID \(position)")
            }
        }
        
        // Now that position is set, we can close any manual draft entry UI
        showManualDraftEntry = false
        
        // Initialize pick tracking with manual position - count existing picks for this slot
        lastPickCount = polling.allPicks.count
        
        // Count picks already made for this draft slot
        let existingMyPicks = polling.allPicks.filter { $0.draftSlot == position }
        lastMyPickCount = existingMyPicks.count
        
        // xprint("🏈 Draft pick set to: \(position)")
        // xprint("🏈 Found \(existingMyPicks.count) existing picks for slot \(position)")
        
        // Update roster immediately with any existing picks for this position
        Task {
            await updateMyRosterFromPicks(polling.allPicks)
            await checkForTurnChange()
        }
    }

    func dismissManualPositionPrompt() {
        manualDraftNeedsPosition = false
        
        // Close the manual draft entry when they skip position selection
        showManualDraftEntry = false
    }
}