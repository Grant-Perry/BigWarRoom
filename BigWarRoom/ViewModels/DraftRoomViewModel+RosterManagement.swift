import Foundation

// MARK: - Roster Management & Enhanced Picks
extension DraftRoomViewModel {
    
    /// Load the user's actual roster from the selected league
    internal func loadMyActualRoster() async {
        guard let myRosterID = _myRosterID,
              let myRoster = allLeagueRosters.first(where: { $0.rosterID == myRosterID }),
              let playerIDs = myRoster.playerIDs else {
            return
        }
        
        // Convert Sleeper player IDs to our internal Player objects
        var newRoster = Roster()
        
        for playerID in playerIDs {
            if let sleeperPlayer = playerDirectory.player(for: playerID),
               let internalPlayer = playerDirectory.convertToInternalPlayer(sleeperPlayer) {
                newRoster.add(internalPlayer)
            }
        }
        
        // Update the roster
        roster = newRoster
    }
    
    /// Update my roster based on draft picks
    internal func updateMyRosterFromPicks(_ picks: [SleeperPick]) async {
        var newRoster = Roster()
        
        // Strategy 1: Use roster ID correlation (for real Sleeper leagues)
        if let myRosterID = _myRosterID {
            let myPicks = picks.filter { $0.rosterID == myRosterID }
            
            for pick in myPicks {
                // Try to convert pick to internal Player format
                if let internalPlayer = convertPickToInternalPlayer(pick) {
                    newRoster.add(internalPlayer)
                }
            }
        }
        // Strategy 2: Use PURE POSITIONAL logic (for ESPN leagues and mock drafts)
        else if let myDraftSlot = myDraftSlot {
            // Calculate which pick numbers belong to this draft position using snake draft
            let teamCount = selectedDraft?.totalRosters ?? 10
            var myPickNumbers: [Int] = []
            
            // Generate all pick numbers for this position across all rounds
            for round in 1...16 { // Assume max 16 rounds
                let pickNumber = calculateSnakeDraftPickNumber(
                    draftPosition: myDraftSlot,
                    round: round,
                    teamCount: teamCount
                )
                if pickNumber <= picks.count { // Only include picks that exist
                    myPickNumbers.append(pickNumber)
                }
            }
            
            print("🏈 Positional Logic: Slot \(myDraftSlot) owns pick numbers: \(myPickNumbers.prefix(10))")
            
            // Find all picks with these pick numbers
            let myPicks = picks.filter { myPickNumbers.contains($0.pickNo) }
            
            for pick in myPicks {
                if let internalPlayer = convertPickToInternalPlayer(pick) {
                    newRoster.add(internalPlayer)
                }
            }
            
            print("🏈 Updated roster using positional logic: \(myPicks.count) picks for slot \(myDraftSlot)")
        }
        
        // Update roster if it's different
        if !rostersAreEqual(newRoster, roster) {
            roster = newRoster
            print("🏈 MyRoster updated with \(totalPlayersInRoster(newRoster)) players")
        }
    }
    
    /// Convert a SleeperPick (which might contain ESPN data) to internal Player format
    private func convertPickToInternalPlayer(_ pick: SleeperPick) -> Player? {
        // Strategy 1: Use Sleeper player directory (for Sleeper leagues)
        if let playerID = pick.playerID,
           !playerID.hasPrefix("espn_"),
           let sleeperPlayer = playerDirectory.player(for: playerID),
           let internalPlayer = playerDirectory.convertToInternalPlayer(sleeperPlayer) {
            return internalPlayer
        }
        
        // Strategy 2: Convert from ESPN data (for ESPN leagues)
        if let espnInfo = pick.espnPlayerInfo,
           let position = espnInfo.position,
           let team = espnInfo.team,
           let pos = Position(rawValue: position.uppercased()) {
            
            return Player(
                id: "espn_\(espnInfo.espnPlayerID)",
                firstInitial: String(espnInfo.firstName?.prefix(1) ?? ""),
                lastName: espnInfo.lastName ?? "Unknown",
                position: pos,
                team: team,
                tier: 4 // Default tier for ESPN players since we don't have rankings
            )
        }
        
        // Strategy 3: Convert from metadata (fallback)
        if let metadata = pick.metadata,
           let firstName = metadata.firstName,
           let lastName = metadata.lastName,
           let position = metadata.position,
           let team = metadata.team,
           let pos = Position(rawValue: position.uppercased()) {
            
            return Player(
                id: pick.playerID ?? "unknown_\(pick.pickNo)",
                firstInitial: String(firstName.prefix(1)),
                lastName: lastName,
                position: pos,
                team: team,
                tier: 4 // Default tier
            )
        }
        
        print("🏈 Could not convert pick \(pick.pickNo) to internal Player format")
        return nil
    }
    
    internal func myRosterPlayerIDs() -> [String] {
        var ids: [String] = []
        if let qb = roster.qb { ids.append(qb.id) }
        if let rb1 = roster.rb1 { ids.append(rb1.id) }
        if let rb2 = roster.rb2 { ids.append(rb2.id) }
        if let wr1 = roster.wr1 { ids.append(wr1.id) }
        if let wr2 = roster.wr2 { ids.append(wr2.id) }
        if let wr3 = roster.wr3 { ids.append(wr3.id) }
        if let te = roster.te { ids.append(te.id) }
        if let flex = roster.flex { ids.append(flex.id) }
        if let k = roster.k { ids.append(k.id) }
        if let dst = roster.dst { ids.append(dst.id) }
        ids.append(contentsOf: roster.bench.map { $0.id })
        return ids
    }
    
    /// Helper to count total players in roster
    private func totalPlayersInRoster(_ roster: Roster) -> Int {
        let starters = [roster.qb, roster.rb1, roster.rb2, roster.wr1, roster.wr2, roster.wr3,
                       roster.te, roster.flex, roster.k, roster.dst].compactMap { $0 }.count
        return starters + roster.bench.count
    }
    
    /// Helper to compare rosters to avoid unnecessary updates
    internal func rostersAreEqual(_ r1: Roster, _ r2: Roster) -> Bool {
        // Get all player IDs from both rosters
        let r1IDs = Set([
            r1.qb?.id, r1.rb1?.id, r1.rb2?.id, r1.wr1?.id, r1.wr2?.id, r1.wr3?.id,
            r1.te?.id, r1.flex?.id, r1.k?.id, r1.dst?.id
        ].compactMap { $0 } + r1.bench.map { $0.id })
        
        let r2IDs = Set([
            r2.qb?.id, r2.rb1?.id, r2.rb2?.id, r2.wr1?.id, r2.wr2?.id, r2.wr3?.id,
            r2.te?.id, r2.flex?.id, r2.k?.id, r2.dst?.id
        ].compactMap { $0 } + r2.bench.map { $0.id })
        
        return r1IDs == r2IDs
    }
    
    // MARK: - Enhanced Picks Building
    
    internal func buildEnhancedPicks(from picks: [SleeperPick]) -> [EnhancedPick] {
        let teams = polling.currentDraft?.settings?.teams ?? selectedDraft?.settings?.teams ?? 12
        return picks.compactMap { pick -> EnhancedPick? in
            
            // Strategy 1: Use embedded ESPN player data (for ESPN leagues) - CHECK THIS FIRST
            if let espnInfo = pick.espnPlayerInfo {
                let teamCode = espnInfo.team ?? ""
                let rosterInfo = pick.rosterID.flatMap { draftRosters[$0] }
                
                print("🏈 Using ESPN data for pick \(pick.pickNo): \(espnInfo.fullName)")
                
                // Create a fake SleeperPlayer using JSON encoding/decoding trick
                let playerData: [String: Any] = [
                    "player_id": "espn_\(espnInfo.espnPlayerID)",
                    "first_name": espnInfo.firstName as Any,
                    "last_name": espnInfo.lastName as Any,
                    "position": espnInfo.position as Any,
                    "team": espnInfo.team as Any,
                    "number": espnInfo.jerseyNumber as Any,
                    "status": "Active",
                    "espn_id": String(espnInfo.espnPlayerID)
                ]
                
                // Try to create SleeperPlayer with fallbacks
                let fakeSleeperPlayer: SleeperPlayer?
                
                // First attempt: Full ESPN data
                if let jsonData = try? JSONSerialization.data(withJSONObject: playerData),
                   let player = try? JSONDecoder().decode(SleeperPlayer.self, from: jsonData) {
                    fakeSleeperPlayer = player
                } else {
                    print("⚠️ Failed to create fake SleeperPlayer from ESPN data")
                    
                    // Second attempt: Minimal fallback data  
                    let fallbackPlayerData: [String: Any] = [
                        "player_id": "espn_\(espnInfo.espnPlayerID)",
                        "first_name": espnInfo.firstName ?? "Unknown",
                        "last_name": espnInfo.lastName ?? "Player"
                    ]
                    
                    if let fallbackJsonData = try? JSONSerialization.data(withJSONObject: fallbackPlayerData),
                       let fallbackPlayer = try? JSONDecoder().decode(SleeperPlayer.self, from: fallbackJsonData) {
                        fakeSleeperPlayer = fallbackPlayer
                    } else {
                        print("💥 Failed to create minimal SleeperPlayer, skipping pick")
                        fakeSleeperPlayer = nil
                    }
                }
                
                // If we couldn't create a SleeperPlayer at all, skip this pick
                guard let finalPlayer = fakeSleeperPlayer else {
                    return nil
                }
                
                return EnhancedPick(
                    id: pick.id,
                    pickNumber: pick.pickNo,
                    round: pick.round,
                    draftSlot: pick.draftSlot,
                    position: espnInfo.position ?? "",
                    teamCode: teamCode,
                    team: NFLTeam.team(for: teamCode),
                    player: finalPlayer,
                    displayName: espnInfo.fullName,
                    rosterInfo: rosterInfo,
                    pickInRound: ((pick.pickNo - 1) % max(1, teams)) + 1
                )
            }
            
            // Strategy 2: Try Sleeper player lookup (for Sleeper leagues)
            else if let playerID = pick.playerID,
               !playerID.hasPrefix("espn_"), // Skip ESPN-prefixed IDs
               let sp = playerDirectory.player(for: playerID) {
                let teamCode = sp.team ?? ""
                let rosterInfo = pick.rosterID.flatMap { draftRosters[$0] }
                
                print("😴 Using Sleeper data for pick \(pick.pickNo): \(sp.shortName)")
                
                return EnhancedPick(
                    id: pick.id,
                    pickNumber: pick.pickNo,
                    round: pick.round,
                    draftSlot: pick.draftSlot,
                    position: sp.position ?? "",
                    teamCode: teamCode,
                    team: NFLTeam.team(for: teamCode),
                    player: sp,
                    displayName: sp.shortName,
                    rosterInfo: rosterInfo,
                    pickInRound: ((pick.pickNo - 1) % max(1, teams)) + 1
                )
            }
            
            // Strategy 3: Fallback - use metadata if available
            else if let metadata = pick.metadata {
                let displayName = [metadata.firstName, metadata.lastName].compactMap { $0 }.joined(separator: " ")
                let teamCode = metadata.team ?? ""
                let rosterInfo = pick.rosterID.flatMap { draftRosters[$0] }
                
                print("📝 Using metadata for pick \(pick.pickNo): \(displayName)")
                
                // Create minimal SleeperPlayer from metadata using similar approach
                let playerData: [String: Any] = [
                    "player_id": pick.playerID ?? "unknown_\(pick.pickNo)",
                    "first_name": metadata.firstName as Any,
                    "last_name": metadata.lastName as Any,
                    "position": metadata.position as Any,
                    "team": metadata.team as Any,
                    "number": metadata.number as Any,
                    "status": metadata.status ?? "Active"
                ]
                
                // Try to create SleeperPlayer with fallbacks
                let fallbackPlayer: SleeperPlayer?
                
                // First attempt: Full metadata
                if let jsonData = try? JSONSerialization.data(withJSONObject: playerData),
                   let player = try? JSONDecoder().decode(SleeperPlayer.self, from: jsonData) {
                    fallbackPlayer = player
                } else {
                    print("⚠️ Failed to create fallback SleeperPlayer from metadata")
                    
                    // Second attempt: Minimal data
                    let minimalPlayerData: [String: Any] = [
                        "player_id": pick.playerID ?? "unknown_\(pick.pickNo)",
                        "first_name": metadata.firstName ?? "Unknown",
                        "last_name": metadata.lastName ?? "Player"
                    ]
                    
                    if let minimalJsonData = try? JSONSerialization.data(withJSONObject: minimalPlayerData),
                       let minimalPlayer = try? JSONDecoder().decode(SleeperPlayer.self, from: minimalJsonData) {
                        fallbackPlayer = minimalPlayer
                    } else {
                        print("💥 Failed to create minimal SleeperPlayer from metadata, skipping pick")
                        fallbackPlayer = nil
                    }
                }
                
                // If we couldn't create a SleeperPlayer, skip this pick
                guard let finalPlayer = fallbackPlayer else {
                    return nil
                }
                
                return EnhancedPick(
                    id: pick.id,
                    pickNumber: pick.pickNo,
                    round: pick.round,
                    draftSlot: pick.draftSlot,
                    position: metadata.position ?? "",
                    teamCode: teamCode,
                    team: NFLTeam.team(for: teamCode),
                    player: finalPlayer,
                    displayName: displayName.isEmpty ? "Unknown Player" : displayName,
                    rosterInfo: rosterInfo,
                    pickInRound: ((pick.pickNo - 1) % max(1, teams)) + 1
                )
            }
            
            // If all else fails, return nil (skip this pick)
            else {
                print("❌ Could not build EnhancedPick for pick \(pick.pickNo) - no player data available")
                print("   PlayerID: \(pick.playerID ?? "nil")")
                print("   ESPN Info: \(pick.espnPlayerInfo != nil ? "present" : "nil")")
                print("   Metadata: \(pick.metadata != nil ? "present" : "nil")")
                return nil
            }
        }
        .sorted { $0.pickNumber < $1.pickNumber }
    }
    
    // MARK: - Picks Feed / My Pick
    
    func addFeedPick() {
        // This is a lightweight helper: parse the last entry and add to bench for context
        guard let last = picksFeed.split(separator: ",").last?.trimmingCharacters(in: .whitespacesAndNewlines),
              !last.isEmpty else { return }
        
        if let found = findInternalPlayer(matchingShortKey: String(last)) {
            roster.bench.append(found)
            Task { await refreshSuggestions() }
        }
    }
    
    func lockMyPick() {
        let input = myPickInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }
        if let found = findInternalPlayer(matchingShortKey: input) {
            var r = roster
            r.add(found)
            roster = r
            myPickInput = ""
            Task { await refreshSuggestions() }
        }
    }
    
    private func findInternalPlayer(matchingShortKey key: String) -> Player? {
        // Expected format: "J Chase"
        let comps = key.split(separator: " ")
        guard comps.count >= 2 else { return nil }
        let firstInitial = String(comps[0]).uppercased()
        let lastName = comps.dropFirst().joined(separator: " ").lowercased()
        
        // Match among directory players converted to internal
        for (_, sp) in playerDirectory.players {
            guard let spFirst = sp.firstName, let spLast = sp.lastName,
                  let posStr = sp.position, let team = sp.team,
                  let pos = Position(rawValue: posStr.uppercased()) else { continue }
            let candidate = Player(
                id: sp.playerID,
                firstInitial: String(spFirst.prefix(1)).uppercased(),
                lastName: spLast,
                position: pos,
                team: team,
                tier: playerDirectory.convertToInternalPlayer(sp)?.tier ?? 4
            )
            if candidate.firstInitial == firstInitial &&
               candidate.lastName.lowercased().hasPrefix(lastName) {
                return candidate
            }
        }
        return nil
    }
}