import Foundation

#if os(iOS)
import AudioToolbox
import UIKit
#endif

// MARK: - Pick Tracking, Turn Detection & Alerts
extension DraftRoomViewModel {
    
    /// Check for new picks I made and show confirmation
    internal func checkForMyNewPicks(_ picks: [SleeperPick]) async {
        var myPicks: [SleeperPick] = []
        var newMyPickCount = 0
        
        // Strategy 1: Use roster ID (for real Sleeper leagues)
        if let myRosterID = _myRosterID {
            myPicks = picks.filter { $0.rosterID == myRosterID }
            newMyPickCount = myPicks.count
        }
        // Strategy 2: Use PURE POSITIONAL logic (for ESPN leagues and mock drafts)
        else if let myDraftSlot = myDraftSlot {
            let teamCount = selectedDraft?.totalRosters ?? 10
            var myPickNumbers: [Int] = []
            
            // Generate all pick numbers for this position
            for round in 1...16 {
                let pickNumber = calculateSnakeDraftPickNumber(
                    draftPosition: myDraftSlot,
                    round: round,
                    teamCount: teamCount
                )
                if pickNumber <= picks.count {
                    myPickNumbers.append(pickNumber)
                }
            }
            
            myPicks = picks.filter { myPickNumbers.contains($0.pickNo) }
            newMyPickCount = myPicks.count
        } else {
            return // No way to identify my picks
        }
        
        // Did I just make a pick?
        if newMyPickCount > lastMyPickCount {
            let newPicks = myPicks.suffix(newMyPickCount - lastMyPickCount)
            
            for pick in newPicks {
                if let playerID = pick.playerID,
                   let player = playerDirectory.player(for: playerID) {
                    confirmationAlertMessage = "🎉 PICK CONFIRMED!\n\n\(player.fullName)\n\(player.position ?? "") • \(player.team ?? "")\n\nRound \(pick.round), Pick \(pick.pickNo)"
                    showingConfirmationAlert = true
                    
                    // x// x Print("🏈 Confirmed your pick: \(player.shortName) at position \(pick.draftSlot)")
                }
            }
        }
        
        lastMyPickCount = newMyPickCount
    }
    
    /// Check if it's the user's turn to pick
    internal func checkForTurnChange() async {
        guard let draft = polling.currentDraft,
              let myDraftSlot = myDraftSlot,
              let teams = draft.settings?.teams else {
            isMyTurn = false
            return
        }
        
        let currentPickNumber = polling.allPicks.count + 1
        let wasMyTurn = isMyTurn
        let newIsMyTurn = isMyTurnToPick(pickNumber: currentPickNumber, mySlot: myDraftSlot, totalTeams: teams)
        
        isMyTurn = newIsMyTurn
        
        // Show alert if it just became my turn
        if newIsMyTurn && !wasMyTurn {
            let round = ((currentPickNumber - 1) / teams) + 1
            let pickInRound = ((currentPickNumber - 1) % teams) + 1
            
            pickAlertMessage = "⚡ IT'S YOUR PICK! ⚡\n\nRound \(round), Pick \(pickInRound)\n(\(currentPickNumber) overall)\n\nTime to make your selection!"
            showingPickAlert = true
            
            // Haptic feedback
            await triggerPickAlert()
        }
    }
    
    /// Calculate if it's my turn based on snake draft logic
    internal func isMyTurnToPick(pickNumber: Int, mySlot: Int, totalTeams: Int) -> Bool {
        let round = ((pickNumber - 1) / totalTeams) + 1
        let pickInRound = ((pickNumber - 1) % totalTeams) + 1
        
        if round % 2 == 1 {
            // Odd rounds: normal order (1, 2, 3, ..., totalTeams)
            return pickInRound == mySlot
        } else {
            // Even rounds: snake/reverse order (totalTeams, ..., 3, 2, 1)
            return pickInRound == (totalTeams - mySlot + 1)
        }
    }
    
    /// Calculate the correct pick number for a snake draft (helper method)
    internal func calculateSnakeDraftPickNumber(draftPosition: Int, round: Int, teamCount: Int) -> Int {
        if round % 2 == 1 {
            // Odd rounds: normal order (1, 2, 3, ..., teamCount)
            return (round - 1) * teamCount + draftPosition
        } else {
            // Even rounds: snake/reverse order (teamCount, ..., 3, 2, 1)
            return (round - 1) * teamCount + (teamCount - draftPosition + 1)
        }
    }
    
    /// Trigger haptic and audio feedback for pick alerts
    private func triggerPickAlert() async {
        #if os(iOS)
        // Strong haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
        
        // System sound for notification
        AudioServicesPlaySystemSound(1007) // SMS received sound
        #endif
    }
    
    /// Dismiss pick alert
    func dismissPickAlert() {
        showingPickAlert = false
        pickAlertMessage = ""
    }
    
    /// Dismiss confirmation alert
    func dismissConfirmationAlert() {
        showingConfirmationAlert = false
        confirmationAlertMessage = ""
    }
    
    /// Public Team Name Helper with Debugging
    func teamDisplayName(for draftSlot: Int) -> String {
        // x// x Print("🔍 DEBUG teamDisplayName for draftSlot \(draftSlot):")
        // x// x Print("   draftRosters count: \(draftRosters.count)")
        
        // Strategy 1: Find the rosterID that corresponds to this draft slot
        // Look through picks to find which roster ID is associated with this draft slot
        let picksForSlot = allDraftPicks.filter { $0.draftSlot == draftSlot }
        // x// x Print("   Picks for slot \(draftSlot): \(picksForSlot.count)")
        
        // Get the roster ID from any pick in this draft slot
        var rosterIDForSlot: Int? = nil
        if let firstPick = picksForSlot.first {
            rosterIDForSlot = firstPick.rosterInfo?.rosterID
            // x// x Print("   Found rosterID \(rosterIDForSlot ?? -1) for draftSlot \(draftSlot)")
        }
        
        // Strategy 2: If we found a roster ID, lookup its display name
        if let rosterID = rosterIDForSlot,
           let rosterInfo = draftRosters[rosterID] {
            // x// x Print("   Found roster info for rosterID \(rosterID): '\(rosterInfo.displayName)'")
            
            // Check if this is a real name (not generic "Team X")
            if !rosterInfo.displayName.isEmpty,
               !rosterInfo.displayName.lowercased().hasPrefix("team "),
               rosterInfo.displayName != "Team \(draftSlot)",
               rosterInfo.displayName != "Team \(rosterID)",
               rosterInfo.displayName.count > 4 {
                // x// x Print("   ✅ Using real name: '\(rosterInfo.displayName)'")
                return rosterInfo.displayName
            } else {
                // x// x Print("   ❌ Name '\(rosterInfo.displayName)' appears to be generic")
            }
        }
        
        // Strategy 3: Direct roster lookup by draft slot (if rosters have draftSlot info)
        if let directRoster = draftRosters.values.first(where: { _ in
            // We don't have direct access to draftSlot in DraftRosterInfo
            // This would require adding draftSlot to DraftRosterInfo or another approach
            return false
        }) {
            return directRoster.displayName
        }
        
        // x// x Print("   ❌ No real name found, using fallback")
        return "Team \(draftSlot)"
    }
}
