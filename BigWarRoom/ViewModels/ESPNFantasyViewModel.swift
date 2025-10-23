//
//  ESPNFantasyViewModel.swift
//  BigWarRoom
//
//  ESPN Fantasy ViewModel based on working SleepThis implementation
//

import SwiftUI
import Combine

@MainActor
final class ESPNFantasyViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var espnFantasyModel: ESPNFantasyLeagueModel?
    @Published var selectedLeagueID: String = ""
    @Published var selectedYear: String = String(Calendar.current.component(.year, from: Date())) // FIXED: Use current year dynamically
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var availableLeagues: [ESPNLeagueResponse] = []
    
    // MARK: -> Week Management (SSOT)
    /// The week selection manager - SINGLE SOURCE OF TRUTH for all week data
    private let weekManager = WeekSelectionManager.shared
    
    /// Public getter for selectedWeek - always use WeekSelectionManager
    var selectedWeek: Int {
        return weekManager.selectedWeek
    }
    
    // MARK: - Dependencies
    private let nflWeekService = NFLWeekService.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {
        // Set initial league if available
        if let firstLeagueID = AppConstants.ESPNLeagueID.first {
            selectedLeagueID = firstLeagueID
        }
        
        subscribeToWeekManager()
        subscribeToNFLWeekService()
        fetchESPNManagerLeagues()
    }
    
    /// Subscribe to WeekSelectionManager for centralized week management
    private func subscribeToWeekManager() {
        weekManager.$selectedWeek
            .removeDuplicates()
            .sink { [weak self] newWeek in
                guard let self = self else { return }
                
                print("📺 ESPNFantasyViewModel: Week changed to \(newWeek), refreshing data...")
                self.fetchFantasyData(forWeek: newWeek)
            }
            .store(in: &cancellables)
    }
    
    /// Subscribe to NFL Week Service updates (for year changes)
    private func subscribeToNFLWeekService() {
        // Update selectedYear when NFL week service updates  
        nflWeekService.$currentYear
            .sink { [weak self] newYear in
                if self?.selectedYear != newYear {
                    // x// x Print("🏈 ESPN: NFL Week Service updated year to \(newYear)")
                    self?.selectedYear = newYear
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// Fetch fantasy data for current selection
    func fetchFantasyData() {
        fetchFantasyData(forWeek: selectedWeek)
    }
    
    /// Fetch fantasy data for specific week
    func fetchFantasyData(forWeek week: Int) {
        guard !selectedLeagueID.isEmpty else {
            errorMessage = "No league selected"
            return
        }
        
        // Use proper ESPN API URL from SleepThis
        guard let url = URL(string: "https://lm-api-reads.fantasy.espn.com/apis/v3/games/ffl/seasons/\(selectedYear)/segments/0/leagues/\(selectedLeagueID)?view=mMatchupScore&view=mLiveScoring&view=mRoster&scoringPeriodId=\(week)") else {
            errorMessage = "Invalid ESPN API URL"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        var request = URLRequest(url: url)
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        // Use correct ESPN tokens based on year
        let espnToken = selectedYear == "2025" ? AppConstants.ESPN_S2_2025 : AppConstants.ESPN_S2
        request.addValue("SWID=\(AppConstants.SWID); espn_s2=\(espnToken)", forHTTPHeaderField: "Cookie")
        
        // x// x Print("🏈 ESPN API Request: \(url)")
        // x// x Print("🔑 Using ESPN year: \(selectedYear)")
        
        URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: ESPNFantasyLeagueModel.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                switch completion {
                case .failure(let error):
                    self?.errorMessage = "Error fetching ESPN data: \(error.localizedDescription)"
                    // x// x Print("❌ ESPN API Error: \(error)")
                case .finished:
                    break
                }
            }, receiveValue: { [weak self] model in
                self?.espnFantasyModel = model
            })
            .store(in: &cancellables)
    }
    
    /// Get team by ID
    func getTeam(for teamId: Int) -> ESPNFantasyTeamModel? {
        return espnFantasyModel?.teams.first(where: { $0.id == teamId })
    }
    
    /// Get matchup for specific week and team - FIXED: Handle optional away field
    func getMatchup(for week: Int, teamId: Int) -> ESPNFantasyMatchupModel? {
        return espnFantasyModel?.schedule.first(where: { matchup in
            guard matchup.matchupPeriodId == week else { return false }
            
            // Check if team is home team
            if matchup.home.teamId == teamId {
                return true
            }
            
            // Check if team is away team (if away team exists)
            if let awayTeam = matchup.away, awayTeam.teamId == teamId {
                return true
            }
            
            return false
        })
    }
    
    /// Get all matchups for specific week
    func getMatchups(for week: Int) -> [ESPNFantasyMatchupModel] {
        return espnFantasyModel?.schedule.filter { $0.matchupPeriodId == week } ?? []
    }
    
    /// Update selected week - NOW USES WeekSelectionManager
    func selectWeek(_ week: Int) {
        weekManager.selectWeek(week)
        // No need to manually refresh - the subscription will handle it
    }
    
    /// Update selected year and refetch data
    func selectYear(_ year: String) {
        selectedYear = year
        fetchFantasyData()
    }
    
    /// Update selected league and refetch data
    func selectLeague(_ leagueID: String) {
        selectedLeagueID = leagueID
        fetchFantasyData()
    }
    
    // MARK: - ESPN Manager League Fetching (from SleepThis)
    
    /// Fetch ESPN leagues for the manager
    private func fetchESPNManagerLeagues() {
        guard let url = URL(string: "https://fan.api.espn.com/apis/v2/fans/\(AppConstants.GpESPNID)?configuration=SITE_DEFAULT&displayEvents=true&displayNow=true&displayRecs=true&displayHiddenPrefs=true&featureFlags=expandAthlete&featureFlags=isolateEvents&featureFlags=challengeEntries&platform=web&recLimit=5&coreData=logos&showAirings=buy%2Clive%2Creplay&authorizedNetworks=espn3&entitlements=ESPN_PLUS&zipcode=23607") else {
            // x// x Print("❌ Invalid ESPN manager leagues URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("SWID=\(AppConstants.SWID); espn_s2=\(AppConstants.ESPN_S2)", forHTTPHeaderField: "Cookie")
        
        URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    // x// x Print("❌ Error fetching ESPN manager leagues: \(error)")
                }
            }, receiveValue: { [weak self] data in
                let leagues = self?.parseESPNLeagues(from: data) ?? []
                self?.availableLeagues = leagues
                // x// x Print("✅ Fetched \(leagues.count) ESPN leagues")
            })
            .store(in: &cancellables)
    }
    
    /// Parse ESPN leagues from response data (from SleepThis)
    private func parseESPNLeagues(from data: Data) -> [ESPNLeagueResponse] {
        var leagues: [ESPNLeagueResponse] = []
        
        do {
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                if let preferences = json["preferences"] as? [[String: Any]] {
                    for preference in preferences {
                        if let metaData = preference["metaData"] as? [String: Any],
                           let entry = metaData["entry"] as? [String: Any],
                           let entryId = entry["entryId"] as? Int,
                           let entryMetadata = entry["entryMetadata"] as? [String: Any],
                           let teamName = entryMetadata["teamName"] as? String,
                           let groups = entry["groups"] as? [[String: Any]] {
                            
                            for group in groups {
                                if let groupId = group["groupId"] as? Int,
                                   let groupName = group["groupName"] as? String {
                                    let league = ESPNLeagueResponse(
                                        id: String(groupId),
                                        name: teamName, // Use team name for better identification
                                        teamName: teamName
                                    )
                                    leagues.append(league)
                                    // x// x Print("📺 Found ESPN league: \(teamName) (ID: \(groupId))")
                                }
                            }
                        }
                    }
                }
            }
        } catch {
            // x// x Print("❌ Error parsing ESPN leagues: \(error)")
        }
        
        return leagues
    }
}

// MARK: - ESPN League Response Model

struct ESPNLeagueResponse: Codable, Identifiable {
    let id: String
    let name: String
    let teamName: String?
}

// MARK: - Helper Functions - REMOVED: Now using centralized NFLWeekCalculator
