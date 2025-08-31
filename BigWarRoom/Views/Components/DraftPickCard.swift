//
//  DraftPickCard.swift
//  BigWarRoom
//
//  Individual draft pick card for live draft feed
//
// MARK: -> Draft Pick Card

import SwiftUI

struct DraftPickCard: View {
    let pick: EnhancedPick
    let isRecent: Bool // Highlight recent picks
    let myRosterID: Int? // To identify my picks
    let isUsingPositionalLogic: Bool // NEW: Whether to use positional logic
    let teamCount: Int // NEW: Team count for positional calculations
    let viewModel: DraftRoomViewModel // Add viewModel to get manager names
    
    // Computed property to check if this is my pick
    private var isMyPick: Bool {
        guard let myRosterID = myRosterID else { return false }
        
        // For ESPN leagues and mock drafts: FORCE positional logic
        if isUsingPositionalLogic {
            let draftSlot = myRosterID // myRosterID represents draft slot for positional logic
            
            // Calculate if this pick number belongs to our draft position using snake draft math
            let round = ((pick.pickNumber - 1) / teamCount) + 1
            
            if round % 2 == 1 {
                // Odd rounds: normal order (1, 2, 3, ..., teamCount)
                let expectedSlot = ((pick.pickNumber - 1) % teamCount) + 1
                return expectedSlot == draftSlot
            } else {
                // Even rounds: snake order (teamCount, ..., 3, 2, 1)
                let expectedSlot = teamCount - ((pick.pickNumber - 1) % teamCount)
                return expectedSlot == draftSlot
            }
        }
        
        // For Sleeper leagues with roster correlation: Use direct roster ID match
        if let rosterInfo = pick.rosterInfo {
            return rosterInfo.rosterID == myRosterID
        }
        
        // No roster info and not using positional logic - can't determine ownership
        return false
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Compact header: Pick number, position, and positional rank
            HStack(spacing: 6) {
                // Pick number (smaller)
                Text(pick.pickDescription)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Show positional rank badge (RB1, WR2, etc.) with position colors if available,
                // otherwise show basic position badge as fallback
                if let positionRank = pick.player.positionalRank {
                    Text(positionRank)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(positionColor(pick.position))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                } else {
                    // Fallback to basic position badge if no positional rank
                    Text(pick.position)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(positionColor(pick.position))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
            
            // Player section: smaller image + prominent name + fantasy rank
            HStack(spacing: 6) {
                // Smaller player image
                PlayerImageView(
                    player: pick.player,
                    size: 32,
                    team: pick.team
                )
                
                VStack(alignment: .leading, spacing: 2) {
                    // Prominent player name with scaling
                    Text(pick.displayName)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    
                    // Fantasy rank (if available)
                    if let searchRank = pick.player.searchRank {
                        Text("FR: \(searchRank)")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.orange)
                    }
                    
                    // Team info with logo and manager name
                    VStack(spacing: 2) {
                        HStack(spacing: 2) {
                            TeamAssetManager.shared.logoOrFallback(for: pick.teamCode)
                                .frame(width: 12, height: 12)
                            
                            Text(pick.teamCode)
                                .font(.system(size: 8, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        
                        // Manager first name
                        Text(managerFirstName(for: pick.draftSlot))
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                
                Spacer(minLength: 0)
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    isMyPick ? 
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.gpGreen.opacity(0.3),
                            Color.gpGreen.opacity(0.1)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ) :
                    LinearGradient(
                        gradient: Gradient(colors: [
                            isRecent ? Color.blue.opacity(0.15) : Color(.systemGray6),
                            isRecent ? Color.blue.opacity(0.05) : Color(.systemGray6)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            isMyPick ? Color.gpGreen : 
                            (isRecent ? Color.blue.opacity(0.4) : Color.clear), 
                            lineWidth: isMyPick ? 2.0 : 1.5
                        )
                )
        )
        .frame(width: 125, height: 110)
        .scaleEffect(isRecent ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isRecent)
    }
    
    private func positionColor(_ position: String) -> Color {
        switch position.uppercased() {
        case "QB": return .purple
        case "RB": return .green
        case "WR": return .blue
        case "TE": return .orange
        case "K": return .gray
        case "DEF", "DST": return .red
        default: return .gray
        }
    }
    
    /// Extract first name from manager display name
    private func managerFirstName(for draftSlot: Int) -> String {
        let fullName = viewModel.teamDisplayName(for: draftSlot)
        
        // Extract first name from the full manager name
        let components = fullName.components(separatedBy: " ")
        if let firstName = components.first, !firstName.isEmpty {
            // Check if it's a meaningful first name (not generic like "Team" or "Manager")
            if !firstName.lowercased().hasPrefix("team") && 
               !firstName.lowercased().hasPrefix("manager") && 
               firstName.count > 1 {
                return firstName
            }
        }
        
        // Fallback to full name if we can't extract a meaningful first name
        return fullName
    }
}