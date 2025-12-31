//
//  BettingOddsTestView.swift
//  BigWarRoom
//
//  Simple test view to verify betting odds API integration
//

import SwiftUI

struct BettingOddsTestView: View {
    @State private var bettingService = BettingOddsService.shared
    @State private var playerDirectory = PlayerDirectoryStore.shared
    @State private var testPlayer: SleeperPlayer?
    @State private var odds: PlayerBettingOdds?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var searchText = ""
    
    var currentWeek: Int {
        WeekSelectionManager.shared.currentNFLWeek
    }
    
    var filteredPlayers: [SleeperPlayer] {
        guard !searchText.isEmpty else { return [] }
        
        let searchTerms = searchText.lowercased().components(separatedBy: " ").filter { !$0.isEmpty }
        
        return Array(playerDirectory.players.values)
            .filter { player in
                let fullName = player.fullName.lowercased()
                let firstName = player.firstName?.lowercased() ?? ""
                let lastName = player.lastName?.lowercased() ?? ""
                
                return searchTerms.allSatisfy { term in
                    fullName.contains(term) ||
                    firstName.contains(term) ||
                    lastName.contains(term)
                }
            }
            .filter { $0.position != nil && !$0.fullName.trimmingCharacters(in: .whitespaces).isEmpty }
            .sorted { $0.searchRank ?? 999 < $1.searchRank ?? 999 }
            .prefix(20)
            .map { $0 }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Image("BG1")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .opacity(0.25)
                    .ignoresSafeArea(.all)
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Betting Odds Test")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Test The Odds API integration")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                        
                        // API Key Status
                        apiKeyStatusCard
                            .padding(.horizontal, 4)
                        
                        // Player Search
                        playerSearchSection
                            .padding(.horizontal, 4)
                        
                        // Selected Player
                        if let player = testPlayer {
                            selectedPlayerCard(player: player)
                                .padding(.horizontal, 4)
                        }
                        
                        // Odds Results
                        if let odds = odds {
                            oddsResultsCard(odds: odds)
                                .padding(.horizontal, 4)
                        }
                        
                        // Loading/Error States
                        if isLoading {
                            ProgressView()
                                .padding()
                        }
                        
                        if let error = errorMessage {
                            errorCard(message: error)
                                .padding(.horizontal, 4)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical)
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
        }
    }
    
    // MARK: - View Components
    
    private var apiKeyStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: Secrets.theOddsAPIKey != nil ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(Secrets.theOddsAPIKey != nil ? .green : .red)
                
                Text("API Key Status")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            if let key = Secrets.theOddsAPIKey {
                Text("✅ API Key Loaded")
                    .font(.system(size: 14))
                    .foregroundColor(.green)
                
                Text("Key: \(String(key.prefix(8)))...")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
            } else {
                Text("❌ API Key Not Found")
                    .font(.system(size: 14))
                    .foregroundColor(.red)
                
                Text("Add THE_ODDS_API_KEY to Secrets.plist")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1))
        )
    }
    
    private var playerSearchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Search Player")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.white.opacity(0.7))
                
                TextField("Enter player name...", text: $searchText)
                    .foregroundColor(.white)
                    .autocorrectionDisabled()
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.12))
            )
            
            // Search results
            if !filteredPlayers.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(filteredPlayers) { player in
                            Button(action: {
                                testPlayer = player
                                searchText = ""
                                fetchOdds(for: player)
                            }) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(player.fullName)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white)
                                    
                                    HStack {
                                        if let pos = player.position {
                                            Text(pos)
                                                .font(.system(size: 12))
                                                .foregroundColor(.white.opacity(0.7))
                                        }
                                        
                                        if let team = player.team {
                                            Text("•")
                                                .foregroundColor(.white.opacity(0.5))
                                            Text(team)
                                                .font(.system(size: 12))
                                                .foregroundColor(.white.opacity(0.7))
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.15))
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
    }
    
    private func selectedPlayerCard(player: SleeperPlayer) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Selected Player")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: {
                    testPlayer = nil
                    odds = nil
                    errorMessage = nil
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(player.fullName)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                HStack {
                    if let pos = player.position {
                        Text(pos)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    if let team = player.team {
                        Text("•")
                            .foregroundColor(.white.opacity(0.5))
                        Text(team)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                
                Text("Week \(currentWeek)")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Button(action: {
                fetchOdds(for: player)
            }) {
                HStack {
                    Image(systemName: "arrow.down.circle.fill")
                    Text("Fetch Betting Odds")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue.opacity(0.3))
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1))
        )
    }
    
    private func oddsResultsCard(odds: PlayerBettingOdds) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Betting Odds Results")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("✅ Success")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.green)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.green.opacity(0.2))
                    )
            }
            
            // Anytime TD
            if let anytimeTD = odds.anytimeTD {
                propCard(title: "Anytime TD", prop: anytimeTD)
            }
            
            // Rushing Yards
            if let rushingYds = odds.rushingYards {
                propCard(title: "Rushing Yards", prop: rushingYds)
            }
            
            // Receiving Yards
            if let receivingYds = odds.receivingYards {
                propCard(title: "Receiving Yards", prop: receivingYds)
            }
            
            // Passing Yards
            if let passingYds = odds.passingYards {
                propCard(title: "Passing Yards", prop: passingYds)
            }
            
            // Passing TDs
            if let passingTDs = odds.passingTDs {
                propCard(title: "Passing TDs", prop: passingTDs)
            }
            
            // Receptions
            if let receptions = odds.receptions {
                propCard(title: "Receptions", prop: receptions)
            }
            
            if odds.anytimeTD == nil && odds.rushingYards == nil && odds.receivingYards == nil &&
               odds.passingYards == nil && odds.passingTDs == nil && odds.receptions == nil {
                Text("No betting props found for this player")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
                    .padding()
            }
            
            Divider()
                .background(Color.white.opacity(0.3))
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Sportsbook: \(odds.anytimeTD?.sportsbook ?? odds.rushingYards?.sportsbook ?? odds.receivingYards?.sportsbook ?? "N/A")")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
                
                Text("Last Updated: \(odds.lastUpdated, style: .relative)")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.green.opacity(0.15))
        )
    }
    
    private func propCard(title: String, prop: PropOdds) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
            
            HStack {
                if let overUnder = prop.overUnder {
                    Text(overUnder)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.gpYellow)
                }
                
                if let yesOdds = prop.yesOdds {
                    Text(yesOdds > 0 ? "+\(yesOdds)" : "\(yesOdds)")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.blue.opacity(0.3))
                        )
                }
                
                if let overOdds = prop.overOdds, let underOdds = prop.underOdds {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Over")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.7))
                            Text(overOdds > 0 ? "+\(overOdds)" : "\(overOdds)")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.green.opacity(0.3))
                        )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Under")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.7))
                            Text(underOdds > 0 ? "+\(underOdds)" : "\(underOdds)")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.red.opacity(0.3))
                        )
                    }
                }
            }
            
            Text("Implied Probability: \(Int(prop.impliedProbability * 100))%")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.6))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
        )
    }
    
    private func errorCard(message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                
                Text("No Player Props Available")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.8))
            
            Divider()
                .background(Color.white.opacity(0.3))
            
            VStack(alignment: .leading, spacing: 6) {
                Text("The Odds API Free Tier includes:")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                
                Text("✓ Game moneylines (h2h)")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
                
                Text("✗ Player props (requires paid plan)")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Text("💡 Recommendation: Build MVP with projected points + matchup analysis first, then add betting odds when ready for paid API.")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.6))
                .italic()
                .padding(.top, 4)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.orange.opacity(0.2))
        )
    }
    
    // MARK: - Actions
    
    private func fetchOdds(for player: SleeperPlayer) {
        Task {
            await MainActor.run {
                isLoading = true
                errorMessage = nil
                odds = nil
            }
            
            let fetchedOdds = await bettingService.fetchPlayerOdds(
                for: player,
                week: currentWeek
            )
            
            await MainActor.run {
                isLoading = false
                
                if let fetchedOdds = fetchedOdds {
                    odds = fetchedOdds
                    errorMessage = nil
                } else {
                    errorMessage = bettingService.errorMessage ?? "No betting odds available for \(player.fullName)"
                }
            }
        }
    }
}

#Preview {
    BettingOddsTestView()
}

