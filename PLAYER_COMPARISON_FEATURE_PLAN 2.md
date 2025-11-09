# Player Comparison Feature - Understanding & Implementation Plan

## #understanding

### Current State Analysis

#### Data Sources Available:
1. **Sleeper API** ✅
   - Player directory via `PlayerDirectoryStore`
   - Player stats (current week + historical)
   - Projected points for fantasy scoring
   - Player injury status
   - Team information
   - **NO betting odds** ❌

2. **ESPN API** ✅
   - NFL game data (scores, status, schedules) via `NFLGameDataService`
   - Fantasy league data
   - Player statistics
   - **NO player betting props/odds** ❌

3. **Existing Services:**
   - `PlayerDirectoryStore` - Fast in-memory player search
   - `PlayerStatsCache` - Cached player stats
   - `AllLivePlayersViewModel` - Live player data
   - `NFLGameDataService` - Game schedules and status
   - `WeekSelectionManager` - Current NFL week management

#### UI Patterns in BigWarRoom:
- Dark theme with vibrant colored accents
- Player cards with headshots, names, jersey numbers
- Search functionality in `PlayerSearchView` with autocomplete
- Sheets/modals for detailed views
- Navigation with custom headers

### Research Findings: Betting Odds Integration

#### ESPN & Sleeper APIs:
- ❌ **Neither ESPN nor Sleeper APIs provide betting odds directly**
- ESPN API provides game-level data but not player props
- Sleeper focuses on fantasy data, not betting markets

#### Third-Party Betting Odds APIs Available:

1. **The Odds API** (Recommended - Most Accessible)
   - **URL:** https://the-odds-api.com/
   - **Features:**
     - Free tier available (500 requests/month)
     - Covers major US sportsbooks (FanDuel, DraftKings, BetMGM, etc.)
     - Player props support
     - Real-time odds updates
   - **Pricing:** Free tier, then paid plans
   - **Documentation:** Well-documented JSON API

2. **OpticOdds API**
   - **URL:** https://opticodds.com/
   - **Features:**
     - Real-time odds from 100+ sportsbooks
     - Player props specific focus
     - Integration examples available
   - **Pricing:** Paid service
   - **Note:** Has Sleeper integration mentions but separate service

3. **MetaBet API**
   - **URL:** https://www.metabet.io/
   - **Features:**
     - Aggregated odds data
     - Player props support
   - **Pricing:** Paid service

4. **Sportsbook API**
   - **URL:** https://sportsbookapi.com/
   - **Features:**
     - Multiple sportsbooks aggregated
   - **Pricing:** Paid service

#### Recommendation:
**Use The Odds API** because:
- Free tier for development/testing
- Good documentation
- Covers player props we need (TDs, yards, receptions)
- Can aggregate multiple sportsbooks
- Simple JSON REST API

### Feature Requirements

1. **Player Selection:**
   - Search bar with autocomplete (reuse `PlayerSearchView` pattern)
   - Display selected players with ability to delete
   - Sequential selection (Player 1 → Player 2)

2. **Data Display for Each Player:**
   - Player info (name, team, position, headshot)
   - Current week matchup (opponent)
   - Vegas betting odds for key props:
     - Rushing yards (RB)
     - Receiving yards (WR/TE)
     - Passing yards/TDs (QB)
     - Anytime TD scorer
     - Touchdown props
   - Projected fantasy points
   - Recent performance trends
   - Injury status
   - Game status (pregame/live/post)

3. **Comparison Algorithm:**
   - **Grade Calculation Factors:**
     - Betting odds confidence (lower odds = higher likelihood)
     - Projected points comparison
     - Matchup difficulty (opponent defense ranking)
     - Recent form (last 3 games average)
     - Injury concerns
     - Game script (expected game flow)
   - **Output:**
     - Clear "START" or "SIT" recommendation
     - Grade (A-F or numeric 0-100)
     - Reasoning text explaining the decision

4. **UI/UX:**
   - Side-by-side player comparison layout
   - Visual indicators for start/sit decision
   - Color coding (green for START, red for SIT)
   - Expandable sections for detailed stats
   - Clear visual hierarchy

---

## Implementation Plan

### Phase 1: Foundation - Models & Services

#### 1.1 Create Player Comparison Models
**File:** `BigWarRoom/Models/PlayerComparisonModels.swift`

```swift
// Models for player comparison feature
struct PlayerComparisonData {
    let player1: ComparisonPlayer
    let player2: ComparisonPlayer
    let recommendation: ComparisonRecommendation
}

struct ComparisonPlayer {
    let sleeperPlayer: SleeperPlayer
    let fantasyPlayer: FantasyPlayer? // If available
    let bettingOdds: PlayerBettingOdds?
    let projectedPoints: Double?
    let currentWeek: Int
    let matchup: NFLGameInfo?
    let recentStats: [PlayerWeekStats]
    let injuryStatus: String?
}

struct PlayerBettingOdds {
    let playerID: String
    let week: Int
    // Key props based on position
    let rushingYards: PropOdds?
    let receivingYards: PropOdds?
    let passingYards: PropOdds?
    let passingTDs: PropOdds?
    let anytimeTD: PropOdds?
    let receptions: PropOdds? // For PPR leagues
    let lastUpdated: Date
}

struct PropOdds {
    let overUnder: String // "125.5"
    let overOdds: Int // American odds format
    let underOdds: Int
    let sportsbook: String? // "DraftKings", "FanDuel", etc.
}

struct ComparisonRecommendation {
    let winner: Winner // .player1 or .player2
    let confidence: Double // 0.0 - 1.0
    let grade: String // "A", "B", "C", "D", "F"
    let reasoning: String // Detailed explanation
    let keyFactors: [ComparisonFactor]
}

enum Winner {
    case player1
    case player2
    case tie
}

struct ComparisonFactor {
    let title: String // "Matchup Advantage"
    let player1Value: String // "vs. #1 Defense"
    let player2Value: String // "vs. #28 Defense"
    let advantage: Winner?
}

struct PlayerWeekStats {
    let week: Int
    let fantasyPoints: Double
    let stats: [String: Double]
}
```

#### 1.2 Create Betting Odds Service
**File:** `BigWarRoom/Services/PlayerBettingOddsService.swift`

```swift
// Service to fetch betting odds from The Odds API (or chosen provider)
@Observable
@MainActor
class PlayerBettingOddsService {
    static let shared = PlayerBettingOddsService()
    
    // Cache to avoid excessive API calls
    private var oddsCache: [String: (PlayerBettingOdds, Date)] = [:]
    private let cacheExpiration: TimeInterval = 3600 // 1 hour
    
    // API Configuration (to be stored in Secrets.plist)
    private var apiKey: String {
        // TODO: Load from Secrets.plist
        return "" // Will be configured
    }
    
    private let baseURL = "https://api.the-odds-api.com/v4"
    
    /// Fetch betting odds for a player for current week
    func fetchOdds(
        for player: SleeperPlayer,
        week: Int,
        year: Int = AppConstants.currentSeasonYearInt
    ) async throws -> PlayerBettingOdds? {
        // Implementation details:
        // 1. Check cache first
        // 2. Map Sleeper player to The Odds API player name/ID
        // 3. Fetch relevant props based on position
        // 4. Parse and return PlayerBettingOdds
        // 5. Cache result
    }
    
    /// Map player position to relevant betting props
    private func getRelevantProps(for position: String) -> [String] {
        switch position.uppercased() {
        case "QB":
            return ["passing_yards", "passing_tds"]
        case "RB":
            return ["rushing_yards", "rushing_tds", "anytime_td"]
        case "WR", "TE":
            return ["receiving_yards", "receptions", "receiving_tds", "anytime_td"]
        default:
            return ["anytime_td"]
        }
    }
}
```

#### 1.3 Create Player Comparison Service
**File:** `BigWarRoom/Services/PlayerComparisonService.swift`

```swift
// Core logic for comparing players and generating recommendations
class PlayerComparisonService {
    static let shared = PlayerComparisonService()
    
    /// Compare two players and generate recommendation
    func comparePlayers(
        player1: ComparisonPlayer,
        player2: ComparisonPlayer
    ) -> ComparisonRecommendation {
        // Algorithm:
        // 1. Calculate matchup advantage
        // 2. Analyze betting odds (implied probabilities)
        // 3. Compare projected points
        // 4. Evaluate recent form
        // 5. Consider injury status
        // 6. Generate grade and reasoning
        
        var factors: [ComparisonFactor] = []
        var player1Score = 0.0
        var player2Score = 0.0
        
        // Factor 1: Projected Points
        let pointsAdvantage = compareProjectedPoints(player1, player2)
        factors.append(pointsAdvantage.factor)
        
        // Factor 2: Betting Odds Analysis
        let oddsAdvantage = compareBettingOdds(player1, player2)
        factors.append(oddsAdvantage.factor)
        
        // Factor 3: Matchup Difficulty
        let matchupAdvantage = compareMatchups(player1, player2)
        factors.append(matchupAdvantage.factor)
        
        // Factor 4: Recent Form
        let formAdvantage = compareRecentForm(player1, player2)
        factors.append(formAdvantage.factor)
        
        // Factor 5: Injury Status
        let injuryImpact = compareInjuryStatus(player1, player2)
        factors.append(injuryImpact.factor)
        
        // Calculate final recommendation
        let totalScore = player1Score - player2Score
        let winner: Winner = totalScore > 0.3 ? .player1 : 
                            totalScore < -0.3 ? .player2 : .tie
        let confidence = min(abs(totalScore), 1.0)
        let grade = calculateGrade(totalScore, confidence)
        let reasoning = generateReasoning(factors, winner)
        
        return ComparisonRecommendation(
            winner: winner,
            confidence: confidence,
            grade: grade,
            reasoning: reasoning,
            keyFactors: factors
        )
    }
    
    // Private helper methods for each comparison factor
    private func compareProjectedPoints(...) -> (factor: ComparisonFactor, score: Double)
    private func compareBettingOdds(...) -> (factor: ComparisonFactor, score: Double)
    private func compareMatchups(...) -> (factor: ComparisonFactor, score: Double)
    private func compareRecentForm(...) -> (factor: ComparisonFactor, score: Double)
    private func compareInjuryStatus(...) -> (factor: ComparisonFactor, score: Double)
    private func calculateGrade(_ score: Double, _ confidence: Double) -> String
    private func generateReasoning(_ factors: [ComparisonFactor], _ winner: Winner) -> String
}
```

### Phase 2: ViewModel

#### 2.1 Create Player Comparison ViewModel
**File:** `BigWarRoom/ViewModels/PlayerComparisonViewModel.swift`

```swift
@Observable
@MainActor
class PlayerComparisonViewModel {
    // Player Selection State
    var selectedPlayer1: SleeperPlayer?
    var selectedPlayer2: SleeperPlayer?
    var searchText: String = ""
    
    // Loading States
    var isLoadingPlayer1: Bool = false
    var isLoadingPlayer2: Bool = false
    var isLoadingComparison: Bool = false
    
    // Data
    var player1Data: ComparisonPlayer?
    var player2Data: ComparisonPlayer?
    var comparisonResult: ComparisonRecommendation?
    var errorMessage: String?
    
    // Search
    var filteredPlayers: [SleeperPlayer] = []
    
    // Services
    private let bettingOddsService = PlayerBettingOddsService.shared
    private let comparisonService = PlayerComparisonService.shared
    private let playerDirectory = PlayerDirectoryStore.shared
    private let gameDataService = NFLGameDataService.shared
    private let statsFacade = StatsFacade.self
    
    /// Search players (reuse existing logic)
    func updateSearchResults(query: String) {
        // Similar to PlayerSearchView filtering logic
    }
    
    /// Select player 1
    func selectPlayer1(_ player: SleeperPlayer) async {
        selectedPlayer1 = player
        isLoadingPlayer1 = true
        // Load full comparison data
        player1Data = await loadComparisonData(for: player)
        isLoadingPlayer1 = false
    }
    
    /// Select player 2
    func selectPlayer2(_ player: SleeperPlayer) async {
        selectedPlayer2 = player
        isLoadingPlayer2 = true
        player2Data = await loadComparisonData(for: player)
        isLoadingPlayer2 = false
        
        // Auto-generate comparison when both selected
        if player1Data != nil && player2Data != nil {
            await generateComparison()
        }
    }
    
    /// Remove selected player
    func removePlayer(_ playerNumber: Int) {
        if playerNumber == 1 {
            selectedPlayer1 = nil
            player1Data = nil
        } else {
            selectedPlayer2 = nil
            player2Data = nil
        }
        comparisonResult = nil
    }
    
    /// Load all data needed for comparison
    private func loadComparisonData(for player: SleeperPlayer) async -> ComparisonPlayer {
        let currentWeek = WeekSelectionManager.shared.currentNFLWeek
        
        // Parallel fetch of all data
        async let odds = bettingOddsService.fetchOdds(for: player, week: currentWeek)
        async let projectedPoints = getProjectedPoints(for: player)
        async let matchup = gameDataService.getGameInfo(for: player.team ?? "")
        async let recentStats = getRecentStats(for: player)
        async let injuryStatus = getInjuryStatus(for: player)
        
        return ComparisonPlayer(
            sleeperPlayer: player,
            fantasyPlayer: nil, // Could look up if available
            bettingOdds: try? await odds,
            projectedPoints: await projectedPoints,
            currentWeek: currentWeek,
            matchup: await matchup,
            recentStats: await recentStats,
            injuryStatus: await injuryStatus
        )
    }
    
    /// Generate comparison recommendation
    func generateComparison() async {
        guard let p1 = player1Data, let p2 = player2Data else { return }
        isLoadingComparison = true
        comparisonResult = comparisonService.comparePlayers(player1: p1, player2: p2)
        isLoadingComparison = false
    }
    
    // Helper methods to fetch various data points
    private func getProjectedPoints(for player: SleeperPlayer) async -> Double?
    private func getRecentStats(for player: SleeperPlayer) async -> [PlayerWeekStats]
    private func getInjuryStatus(for player: SleeperPlayer) async -> String?
}
```

### Phase 3: UI Components

#### 3.1 Main Comparison View
**File:** `BigWarRoom/Views/PlayerComparison/PlayerComparisonView.swift`

```swift
struct PlayerComparisonView: View {
    @State private var viewModel = PlayerComparisonViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background (similar to other views)
                Image("BG1")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .opacity(0.25)
                    .ignoresSafeArea(.all)
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        comparisonHeaderView
                        
                        // Player Selection Section
                        playerSelectionSection
                        
                        // Comparison Results (when both players selected)
                        if viewModel.player1Data != nil && viewModel.player2Data != nil {
                            comparisonResultsSection
                        } else {
                            // Empty state
                            emptyStateView
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Player Comparison")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // UI Components
    private var comparisonHeaderView: some View
    private var playerSelectionSection: some View
    private var playerSelectionCard(player: SleeperPlayer?, number: Int, isLoading: Bool) -> some View
    private var emptyStateView: some View
    private var comparisonResultsSection: some View
}
```

#### 3.2 Player Search Component
**File:** `BigWarRoom/Views/PlayerComparison/PlayerComparisonSearchView.swift`

```swift
// Reusable search bar component (extracted from PlayerSearchView pattern)
struct PlayerComparisonSearchView: View {
    @Binding var searchText: String
    @Binding var filteredPlayers: [SleeperPlayer]
    var onPlayerSelected: (SleeperPlayer) -> Void
    
    var body: some View {
        // Similar to PlayerSearchView search bar implementation
    }
}
```

#### 3.3 Comparison Result Card
**File:** `BigWarRoom/Views/PlayerComparison/ComparisonResultCard.swift`

```swift
struct ComparisonResultCard: View {
    let recommendation: ComparisonRecommendation
    let player1: ComparisonPlayer
    let player2: ComparisonPlayer
    
    var body: some View {
        VStack(spacing: 16) {
            // Winner indicator
            winnerBadge
            
            // Grade display
            gradeDisplay
            
            // Reasoning text
            reasoningText
            
            // Key factors comparison
            factorsComparison
        }
    }
    
    // Sub-components
    private var winnerBadge: some View
    private var gradeDisplay: some View
    private var reasoningText: some View
    private var factorsComparison: some View
}
```

#### 3.4 Player Comparison Card
**File:** `BigWarRoom/Views/PlayerComparison/PlayerComparisonCard.swift`

```swift
struct PlayerComparisonCard: View {
    let player: ComparisonPlayer
    let isWinner: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Player header (name, team, position)
            playerHeader
            
            // Betting odds section
            if let odds = player.bettingOdds {
                bettingOddsSection(odds)
            }
            
            // Projected points
            projectedPointsSection
            
            // Matchup info
            matchupSection
            
            // Recent performance
            recentPerformanceSection
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isWinner ? Color.green.opacity(0.2) : Color.gray.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isWinner ? Color.green : Color.clear, lineWidth: 2)
                )
        )
    }
    
    // Sub-components
    private var playerHeader: some View
    private func bettingOddsSection(_ odds: PlayerBettingOdds) -> some View
    private var projectedPointsSection: some View
    private var matchupSection: some View
    private var recentPerformanceSection: some View
}
```

### Phase 4: Integration & Navigation

#### 4.1 Add to App Navigation
- Add entry point in `MoreTabView.swift` or create new tab
- Consider adding shortcut in `MatchupsHubView` for quick access

#### 4.2 API Key Configuration
- Add `THE_ODDS_API_KEY` to `Secrets.example.plist`
- Update `Secrets.swift` to load the key
- Document setup in README

### Phase 5: Testing & Refinement

1. Test with various player combinations
2. Verify betting odds API integration
3. Refine grading algorithm based on real data
4. Optimize loading states and error handling
5. Add caching for better performance

---

## Technical Considerations

### API Rate Limits
- The Odds API free tier: 500 requests/month
- Implement caching aggressively (1 hour cache for odds)
- Only fetch when both players selected

### Data Mapping Challenges
- Sleeper player names → The Odds API player names
- May need manual mapping for edge cases
- Handle missing odds gracefully (show "N/A")

### Fallback Strategy
- If betting odds unavailable, still provide comparison using:
  - Projected points
  - Recent form
  - Matchup analysis
  - Injury status

### Performance
- Load betting odds in parallel with other data
- Cache comparison results
- Lazy load detailed stats

---

## Future Enhancements

1. **Historical Comparison Accuracy**
   - Track prediction accuracy over time
   - Improve algorithm based on results

2. **Multiple Scoring Formats**
   - PPR vs Standard
   - Custom league settings

3. **Machine Learning**
   - Learn from user start/sit decisions
   - Personalized recommendations

4. **Lineup Optimizer Integration**
   - Compare multiple players at once
   - Optimal lineup suggestions

---

## Next Steps

1. ✅ Research complete
2. ⏭️ Set up The Odds API account and get API key
3. ⏭️ Create model files
4. ⏭️ Implement betting odds service
5. ⏭️ Build comparison service logic
6. ⏭️ Create ViewModel
7. ⏭️ Build UI components
8. ⏭️ Integrate into app navigation
9. ⏭️ Test and refine

---

## Resources

- The Odds API Documentation: https://the-odds-api.com/liveapi/guides/v4/
- Sleeper API Docs: https://docs.sleeper.com/
- ESPN API (for reference): Used for NFL game data
- Existing BigWarRoom search pattern: `PlayerSearchView.swift`


