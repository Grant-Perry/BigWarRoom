//
//  AIPickSuggestionsContentView.swift
//  BigWarRoom
//
//  Content section component for AIPickSuggestionsView
//

import SwiftUI

/// Content section with smart recommendations
struct AIPickSuggestionsContentView: View {
    let viewModel: DraftRoomViewModel
    let onPlayerTap: ((Player) -> Void)? // 🔥 DEATH TO SHEETS: Made optional for NavigationLink usage
    let onLockPick: (Suggestion) -> Void
    let onAddToFeed: (Suggestion) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Smart Recommendations")
                    .font(.headline)
                
                Spacer()
                
                if !viewModel.suggestions.isEmpty {
                    Text("\(viewModel.suggestions.count) players")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if viewModel.suggestions.isEmpty {
                // Loading state
                VStack(spacing: 16) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 50))
                        .foregroundColor(.purple)
                    
                    ProgressView()
                        .scaleEffect(1.2)
                    
                    Text("AI is analyzing the best picks for you...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
            } else {
                // Choose display method based on sort method
                if viewModel.selectedSortMethod == .all {
                    // LazyVStack for "All" - can handle thousands of players
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.suggestions) { suggestion in
                            AIPickSuggestionCardView(
                                suggestion: suggestion,
                                viewModel: viewModel,
                                displayMode: .all,
                                onPlayerTap: onPlayerTap, // 🔥 DEATH TO SHEETS: Pass nil for NavigationLink
                                onLockPick: onLockPick,
                                onAddToFeed: onAddToFeed
                            )
                        }
                    }
                } else {
                    // List with swipe actions for Wizard and Rankings
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.suggestions) { suggestion in
                            AIPickSuggestionCardView(
                                suggestion: suggestion,
                                viewModel: viewModel,
                                displayMode: .standard,
                                onPlayerTap: onPlayerTap, // 🔥 DEATH TO SHEETS: Pass nil for NavigationLink
                                onLockPick: onLockPick,
                                onAddToFeed: onAddToFeed
                            )
                        }
                    }
                }
            }
        }
    }
}

/// Individual suggestion card component
struct AIPickSuggestionCardView: View {
    let suggestion: Suggestion
    let viewModel: DraftRoomViewModel
    let displayMode: DisplayMode
    let onPlayerTap: ((Player) -> Void)? // 🔥 DEATH TO SHEETS: Made optional for NavigationLink usage
    let onLockPick: (Suggestion) -> Void
    let onAddToFeed: (Suggestion) -> Void
    
    enum DisplayMode {
        case standard, all
    }
    
    var body: some View {
        if displayMode == .all {
            buildEnhancedCardForAll()
        } else {
            buildEnhancedCard()
        }
    }
    
    private func buildEnhancedCard() -> some View {
        // 🔥 DEATH TO SHEETS: Use NavigationLink instead of onTapGesture
        Group {
            if let sleeperPlayer = findSleeperPlayerForSuggestion() {
                NavigationLink(
                    destination: PlayerStatsCardView(
                        player: sleeperPlayer,
                        team: NFLTeam.team(for: suggestion.player.team)
                    )
                ) {
                    cardContent
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                cardContent // No navigation if can't find player
            }
        }
        .contextMenu {
            Button("Lock as My Pick") {
                onLockPick(suggestion)
            }
            
            Button("Add to Feed") {
                onAddToFeed(suggestion)
            }
            
            if findSleeperPlayerForSuggestion() != nil {
                Button("View Stats") {
                    onPlayerTap?(suggestion.player)
                }
            }
        }
    }
    
    private func buildEnhancedCardForAll() -> some View {
        // 🔥 DEATH TO SHEETS: Use NavigationLink instead of onTapGesture
        Group {
            if let sleeperPlayer = findSleeperPlayerForSuggestion() {
                NavigationLink(
                    destination: PlayerStatsCardView(
                        player: sleeperPlayer,
                        team: NFLTeam.team(for: suggestion.player.team)
                    )
                ) {
                    cardContentForAll
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                cardContentForAll // No navigation if can't find player
            }
        }
        .onLongPressGesture(minimumDuration: 0.5) {
            onLockPick(suggestion)
            
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
        }
        .contextMenu {
            Button("Lock as My Pick") {
                onLockPick(suggestion)
            }
            
            Button("Add to Feed") {
                onAddToFeed(suggestion)
            }
            
            if findSleeperPlayerForSuggestion() != nil {
                Button("View Stats") {
                    onPlayerTap?(suggestion.player)
                }
            }
        }
    }
    
    // 🔥 DEATH TO SHEETS: Extract card content to reusable computed properties
    private var cardContent: some View {
        HStack(spacing: 12) {
            // Player headshot - improved lookup logic
            playerImageForSuggestion()
            
            // Player info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    // Custom player name and position display
                    playerNameAndPositionView()
                    
                    // Tier badge (T1 = Elite, T2 = Very Good, etc.)
                    tierBadge()
                    
                    Spacer()
                    
                    // Team logo (much larger size)
                    TeamAssetManager.shared.logoOrFallback(for: suggestion.player.team)
                        .frame(width: 42, height: 42)
                }
                
                // Player details: fantasy rank, jersey, years, injury status all on one line
                playerDetailsRow()
            }
        }
        .padding(12)
        .background(
            TeamAssetManager.shared.teamBackground(for: suggestion.player.team)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var cardContentForAll: some View {
        HStack(spacing: 16) {  
            // Player headshot with position number badge overlay
            ZStack(alignment: .topTrailing) {
                playerImageForSuggestion()
                
                // Sequential position number in blue gradient circle
                if let index = viewModel.suggestions.firstIndex(where: { $0.id == suggestion.id }) {
                    Text("\(index + 1)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 24, height: 24)
                        .background(
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.purple, .blue],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                        .offset(x: 4, y: -4)
                }
            }
            
            // Player info - expanded to fill more space
            VStack(alignment: .leading, spacing: 6) {  
                HStack(spacing: 8) {
                    playerNameAndPositionView()
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        tierBadge()
                        
                        TeamAssetManager.shared.logoOrFallback(for: suggestion.player.team)
                            .frame(width: 42, height: 42)
                    }
                }
                
                playerDetailsRowForAll()
            }
        }
        .padding(.horizontal, 16)  
        .padding(.vertical, 14)    
        .background(
            TeamAssetManager.shared.teamBackground(for: suggestion.player.team)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Helper Components
    
    @ViewBuilder
    private func playerImageForSuggestion() -> some View {
        if let sleeperPlayer = findSleeperPlayerForSuggestion() {
            PlayerImageView(
                player: sleeperPlayer,
                size: 60,
                team: NFLTeam.team(for: suggestion.player.team)
            )
        } else {
            Circle()
                .fill(NFLTeam.team(for: suggestion.player.team)?.gradient ?? LinearGradient(colors: [.gray], startPoint: .top, endPoint: .bottom))
                .overlay(
                    Text(suggestion.player.firstInitial)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(NFLTeam.team(for: suggestion.player.team)?.accentColor ?? .white)
                )
                .frame(width: 60, height: 60)
        }
    }
    
    private func playerNameAndPositionView() -> some View {
        HStack(spacing: 6) {
            Text("\(suggestion.player.firstInitial) \(suggestion.player.lastName)")
                .font(.callout)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            if let sleeperPlayer = findSleeperPlayerForSuggestion(),
               let positionRank = sleeperPlayer.positionalRank {
                Text("- \(positionRank)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.cyan)
            } else {
                Text("- \(suggestion.player.position.rawValue)")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func tierBadge() -> some View {
        Text("T\(suggestion.player.tier)")
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(tierColor())
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }
    
    private func playerDetailsRow() -> some View {
        HStack(spacing: 8) {
            if let sleeperPlayer = findSleeperPlayerForSuggestion() {
                if let searchRank = sleeperPlayer.searchRank {
                    Text("FantRnk: \(searchRank)")
                        .font(.caption2)
                        .foregroundColor(.blue)
                        .fontWeight(.medium)
                }
                
                if let yearsExp = sleeperPlayer.yearsExp {
                    Text("Yrs: \(yearsExp)")
                        .font(.caption2)
                        .foregroundColor(.blue)
                        .fontWeight(.medium)
                }
                
                if let injuryStatus = sleeperPlayer.injuryStatus, !injuryStatus.isEmpty {
                   Text(String(injuryStatus.prefix(5)))
                        .font(.caption2)
                        .foregroundColor(.red)
                        .fontWeight(.medium)
                }
            } else {
                Text("Tier \(suggestion.player.tier) • \(suggestion.player.team)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    private func playerDetailsRowForAll() -> some View {
        HStack(spacing: 8) {
            if let sleeperPlayer = findSleeperPlayerForSuggestion() {
                if let searchRank = sleeperPlayer.searchRank {
                    Text("FantRnk: \(searchRank)")
                        .font(.caption2)
                        .foregroundColor(.blue)
                        .fontWeight(.medium)
                }
                
                if let number = sleeperPlayer.number {
                    Text("#: \(number)")
                        .font(.caption2)
                        .foregroundColor(.blue)
                        .fontWeight(.medium)
                }
                
                if let yearsExp = sleeperPlayer.yearsExp {
                    Text("Yrs: \(yearsExp)")
                        .font(.caption2)
                        .foregroundColor(.blue)
                        .fontWeight(.medium)
                }
                
                if let injuryStatus = sleeperPlayer.injuryStatus, !injuryStatus.isEmpty {
                   Text(String(injuryStatus.prefix(5)))
                        .font(.caption2)
                        .foregroundColor(.red)
                        .fontWeight(.medium)
                }
            } else {
                Text("Tier \(suggestion.player.tier) • \(suggestion.player.team)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Helper Methods
    
    private func findSleeperPlayerForSuggestion() -> SleeperPlayer? {
        let allSleeperPlayers = PlayerDirectoryStore.shared.players.values
        
        if let directMatch = PlayerDirectoryStore.shared.players[suggestion.player.id] {
            return directMatch
        }
        
        let nameMatch = allSleeperPlayers.first { sleeperPlayer in
            let nameMatches = sleeperPlayer.shortName.lowercased() == "\(suggestion.player.firstInitial) \(suggestion.player.lastName)".lowercased()
            let positionMatches = sleeperPlayer.position?.uppercased() == suggestion.player.position.rawValue
            let teamMatches = sleeperPlayer.team?.uppercased() == suggestion.player.team.uppercased()
            
            return nameMatches && positionMatches && teamMatches
        }
        
        if let nameMatch = nameMatch {
            return nameMatch
        }
        
        let fuzzyMatch = allSleeperPlayers.first { sleeperPlayer in
            guard let sleeperFirst = sleeperPlayer.firstName,
                  let sleeperLast = sleeperPlayer.lastName else { return false }
            
            let firstInitialMatches = sleeperFirst.prefix(1).uppercased() == suggestion.player.firstInitial.uppercased()
            let lastNameMatches = sleeperLast.lowercased().contains(suggestion.player.lastName.lowercased()) || 
                                   suggestion.player.lastName.lowercased().contains(sleeperLast.lowercased())
            let teamMatches = sleeperPlayer.team?.uppercased() == suggestion.player.team.uppercased()
            
            return firstInitialMatches && lastNameMatches && teamMatches
        }
        
        return fuzzyMatch
    }
    
    private func tierColor() -> Color {
        switch suggestion.player.tier {
        case 1: return .purple
        case 2: return .blue
        case 3: return .orange
        default: return .gray
        }
    }
}