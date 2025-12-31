import Foundation

/// Service to test and validate API endpoints before building the full scoring engine
class EndpointValidationService {
    
    // MARK: - Test Results
    struct ValidationResult {
        let endpoint: String
        let success: Bool
        let data: Data?
        let error: String?
        let responseTime: TimeInterval?
    }
    
    // MARK: - Sleeper API Tests
    
    /// Test Sleeper league endpoint for scoring settings
    func testSleeperLeagueEndpoint(leagueId: String) async -> ValidationResult {
        let url = "https://api.sleeper.app/v1/league/\(leagueId)"
        return await makeRequest(to: url, method: "GET")
    }
    
    // MARK: - ESPN API Tests
    
    /// Test ESPN league endpoint with mSettings view
    func testESPNScoringSettings(leagueId: String, season: String? = nil, swid: String? = nil, espnS2: String? = nil) async -> ValidationResult {
        let seasonYear = season ?? SeasonYearManager.shared.selectedYear
        let baseUrl = "https://lm-api-reads.fantasy.espn.com/apis/v3/games/ffl/seasons/\(seasonYear)/segments/0/leagues/\(leagueId)"
        let url = "\(baseUrl)?view=mSettings"
        
        return await makeRequest(to: url, method: "GET", espnCookies: (swid: swid, espnS2: espnS2))
    }
    
    /// Test ESPN fantasy league general endpoint (without mSettings)
    func testESPNLeagueGeneral(leagueId: String, season: String? = nil, swid: String? = nil, espnS2: String? = nil) async -> ValidationResult {
        let seasonYear = season ?? SeasonYearManager.shared.selectedYear
        let url = "https://fantasy.espn.com/apis/v3/games/ffl/seasons/\(seasonYear)/segments/0/leagues/\(leagueId)"
        
        return await makeRequest(to: url, method: "GET", espnCookies: (swid: swid, espnS2: espnS2))
    }
    
    // MARK: - ESPN Site API Tests (for NFL stats)
    
    /// Test ESPN site API scoreboard
    func testESPNScoreboard(date: String? = nil, week: Int? = nil) async -> ValidationResult {
        var url = "https://site.api.espn.com/apis/site/v2/sports/football/nfl/scoreboard"
        
        var params: [String] = []
        if let date = date {
            params.append("dates=\(date)")
        }
        if let week = week {
            params.append("week=\(week)")
            params.append("seasontype=2") // Regular season
        }
        
        if !params.isEmpty {
            url += "?" + params.joined(separator: "&")
        }
        
        return await makeRequest(to: url, method: "GET")
    }
    
    /// Test ESPN site API game summary (boxscore)
    func testESPNGameSummary(eventId: String) async -> ValidationResult {
        let url = "https://site.api.espn.com/apis/site/v2/sports/football/nfl/summary?event=\(eventId)"
        return await makeRequest(to: url, method: "GET")
    }
    
    // MARK: - Helper Methods
    
    private func makeRequest(to urlString: String, method: String, espnCookies: (swid: String?, espnS2: String?)? = nil) async -> ValidationResult {
        
        guard let url = URL(string: urlString) else {
            return ValidationResult(endpoint: urlString, success: false, data: nil, error: "Invalid URL", responseTime: nil)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Add ESPN cookies if provided
        if let cookies = espnCookies, let swid = cookies.swid, let espnS2 = cookies.espnS2 {
            request.setValue("SWID=\(swid); ESPN_S2=\(espnS2)", forHTTPHeaderField: "Cookie")
        }
        
        let startTime = Date()
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let responseTime = Date().timeIntervalSince(startTime)
            
            if let httpResponse = response as? HTTPURLResponse {
                let success = (200...299).contains(httpResponse.statusCode)
                let error = success ? nil : "HTTP \(httpResponse.statusCode)"
                
                return ValidationResult(
                    endpoint: urlString,
                    success: success,
                    data: data,
                    error: error,
                    responseTime: responseTime
                )
            } else {
                return ValidationResult(endpoint: urlString, success: false, data: data, error: "Invalid response", responseTime: responseTime)
            }
            
        } catch {
            let responseTime = Date().timeIntervalSince(startTime)
            return ValidationResult(endpoint: urlString, success: false, data: nil, error: error.localizedDescription, responseTime: responseTime)
        }
    }
    
    // MARK: - JSON Parsing Helpers
    
    /// Parse Sleeper league response to extract scoring settings
    func parseSleeperScoringSettings(from data: Data) -> [String: Any]? {
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return json["scoring_settings"] as? [String: Any]
            }
        } catch {
        }
        return nil
    }
    
    /// Parse ESPN response to extract scoring settings
    func parseESPNScoringSettings(from data: Data) -> [String: Any]? {
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let settings = json["settings"] as? [String: Any] {
                return settings["scoringSettings"] as? [String: Any]
            }
        } catch {
        }
        return nil
    }
    
    /// Parse ESPN site API scoreboard to extract event IDs
    func parseESPNScoreboard(from data: Data) -> [String]? {
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let events = json["events"] as? [[String: Any]] {
                return events.compactMap { $0["id"] as? String }
            }
        } catch {
        }
        return nil
    }
}

// MARK: - Test Runner Extension

extension EndpointValidationService {
    
    /// Run comprehensive endpoint validation with your league IDs
    func runComprehensiveValidation(
        sleeperLeagueId: String?,
        espnLeagueId: String?,
        espnSeason: String = "2025",
        espnSWID: String? = nil,
        espnS2: String? = nil
    ) async -> [ValidationResult] {
        
        var results: [ValidationResult] = []
        
        // Test Sleeper if league ID provided
        if let sleeperLeagueId = sleeperLeagueId {
            let sleeperResult = await testSleeperLeagueEndpoint(leagueId: sleeperLeagueId)
            results.append(sleeperResult)
            
            if sleeperResult.success, let data = sleeperResult.data {
                let scoringSettings = parseSleeperScoringSettings(from: data)
            } else {
            }
        }
        
        // Test ESPN if league ID provided
        if let espnLeagueId = espnLeagueId {
            let espnSettingsResult = await testESPNScoringSettings(
                leagueId: espnLeagueId,
                season: espnSeason,
                swid: espnSWID,
                espnS2: espnS2
            )
            results.append(espnSettingsResult)
            
            if espnSettingsResult.success, let data = espnSettingsResult.data {
                let scoringSettings = parseESPNScoringSettings(from: data)
            } else {
            }
            
            // Also test general ESPN endpoint as fallback
            let espnGeneralResult = await testESPNLeagueGeneral(
                leagueId: espnLeagueId,
                season: espnSeason,
                swid: espnSWID,
                espnS2: espnS2
            )
            results.append(espnGeneralResult)
            
            if espnGeneralResult.success {
            } else {
            }
        }
        
        // Test ESPN site API (universal stats source)
        let scoreboardResult = await testESPNScoreboard(week: 15) // Current week
        results.append(scoreboardResult)
        
        if scoreboardResult.success, let data = scoreboardResult.data {
            if let eventIds = parseESPNScoreboard(from: data) {
                
                // Test game summary for first event
                if let firstEventId = eventIds.first {
                    let summaryResult = await testESPNGameSummary(eventId: firstEventId)
                    results.append(summaryResult)
                    
                    if summaryResult.success {
                    } else {
                    }
                }
            }
        } else {
        }
        
        return results
    }
}