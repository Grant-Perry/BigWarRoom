//
//  APIEndpointService.swift
//  BigWarRoom
//
//  🔥 DRY SERVICE: Centralized URL construction for all API endpoints
//  Eliminates hardcoded URL strings scattered across the codebase
//

import Foundation

/// Centralized service for building API endpoint URLs
/// Ensures consistency and eliminates duplicate URL construction logic
struct APIEndpointService {
    
    // MARK: - Sleeper API Endpoints
    
    /// Get Sleeper league details
    static func sleeperLeague(leagueID: String) -> URL? {
        return URL(string: "https://api.sleeper.app/v1/league/\(leagueID)")
    }
    
    /// Get Sleeper matchups for a specific week
    static func sleeperMatchups(leagueID: String, week: Int) -> URL? {
        return URL(string: "https://api.sleeper.app/v1/league/\(leagueID)/matchups/\(week)")
    }
    
    /// Get Sleeper rosters for a league
    static func sleeperRosters(leagueID: String) -> URL? {
        return URL(string: "https://api.sleeper.app/v1/league/\(leagueID)/rosters")
    }
    
    /// Get Sleeper users for a league
    static func sleeperUsers(leagueID: String) -> URL? {
        return URL(string: "https://api.sleeper.app/v1/league/\(leagueID)/users")
    }
    
    /// Get Sleeper winners bracket for playoffs
    static func sleeperWinnersBracket(leagueID: String) -> URL? {
        return URL(string: "https://api.sleeper.app/v1/league/\(leagueID)/winners_bracket")
    }
    
    /// Get Sleeper losers bracket for playoffs
    static func sleeperLosersBracket(leagueID: String) -> URL? {
        return URL(string: "https://api.sleeper.app/v1/league/\(leagueID)/losers_bracket")
    }
    
    /// Get Sleeper user by username
    static func sleeperUser(username: String) -> URL? {
        return URL(string: "https://api.sleeper.app/v1/user/\(username)")
    }
    
    /// Get Sleeper weekly stats
    static func sleeperWeeklyStats(year: String, week: Int) -> URL? {
        return URL(string: "https://api.sleeper.app/v1/stats/nfl/regular/\(year)/\(week)")
    }
    
    /// Get Sleeper projections
    static func sleeperProjections(year: String, week: Int) -> URL? {
        return URL(string: "https://api.sleeper.app/v1/projections/nfl/regular/\(year)/\(week)")
    }
    
    /// Get Sleeper player data
    static func sleeperPlayers() -> URL? {
        return URL(string: "https://api.sleeper.app/v1/players/nfl")
    }
    
    // MARK: - Sleeper CDN Endpoints
    
    /// Get Sleeper avatar URL
    static func sleeperAvatar(avatarID: String) -> URL? {
        return URL(string: "https://sleepercdn.com/avatars/\(avatarID)")
    }
    
    /// Get Sleeper thumbnail avatar URL
    static func sleeperAvatarThumbnail(avatarID: String) -> URL? {
        return URL(string: "https://sleepercdn.com/avatars/thumbs/\(avatarID)")
    }
    
    // MARK: - ESPN API Endpoints
    
    /// Get ESPN league data with views
    static func espnLeague(
        leagueID: String,
        year: String,
        week: Int,
        views: [String] = ["mMatchupScore", "mLiveScoring", "mRoster", "mPositionalRatings"]
    ) -> URL? {
        let viewParams = views.map { "view=\($0)" }.joined(separator: "&")
        let urlString = "https://lm-api-reads.fantasy.espn.com/apis/v3/games/ffl/seasons/\(year)/segments/0/leagues/\(leagueID)?\(viewParams)&scoringPeriodId=\(week)"
        return URL(string: urlString)
    }
    
    /// Get ESPN manager leagues (fan profile)
    static func espnManagerProfile(
        managerID: String,
        configuration: String = "SITE_DEFAULT",
        zipcode: String? = nil
    ) -> URL? {
        var urlString = "https://fan.api.espn.com/apis/v2/fans/\(managerID)?configuration=\(configuration)&displayEvents=true&displayNow=true&displayRecs=true&displayHiddenPrefs=true&featureFlags=expandAthlete&featureFlags=isolateEvents&featureFlags=challengeEntries&platform=web&recLimit=5&coreData=logos&showAirings=buy%2Clive%2Creplay&authorizedNetworks=espn3&entitlements=ESPN_PLUS"
        
        if let zip = zipcode {
            urlString += "&zipcode=\(zip)"
        }
        
        return URL(string: urlString)
    }
    
    // MARK: - URL Request Builders
    
    /// Build authenticated ESPN URLRequest
    static func espnAuthenticatedRequest(
        url: URL,
        year: String,
        swid: String = AppConstants.SWID,
        espnS2_2024: String = AppConstants.ESPN_S2,
        espnS2_2025: String = AppConstants.ESPN_S2_2025
    ) -> URLRequest {
        var request = URLRequest(url: url)
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let espnToken = year == "2025" ? espnS2_2025 : espnS2_2024
        request.addValue("SWID=\(swid); espn_s2=\(espnToken)", forHTTPHeaderField: "Cookie")
        
        return request
    }
    
    /// Build standard JSON URLRequest
    static func jsonRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }
}

// MARK: - Convenience Extensions

extension APIEndpointService {
    
    /// Build complete ESPN league request (URL + auth)
    static func espnLeagueRequest(
        leagueID: String,
        year: String,
        week: Int,
        views: [String] = ["mMatchupScore", "mLiveScoring", "mRoster", "mPositionalRatings"]
    ) -> URLRequest? {
        guard let url = espnLeague(leagueID: leagueID, year: year, week: week, views: views) else {
            return nil
        }
        return espnAuthenticatedRequest(url: url, year: year)
    }
    
    /// Build complete ESPN manager profile request (URL + auth)
    static func espnManagerProfileRequest(
        managerID: String,
        year: String,
        configuration: String = "SITE_DEFAULT",
        zipcode: String? = nil
    ) -> URLRequest? {
        guard let url = espnManagerProfile(managerID: managerID, configuration: configuration, zipcode: zipcode) else {
            return nil
        }
        return espnAuthenticatedRequest(url: url, year: year)
    }
}