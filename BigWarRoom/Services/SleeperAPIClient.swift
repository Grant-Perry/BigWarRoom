//
//  SleeperAPIClient.swift
//  BigWarRoom
//
//  Sleeper API networking client for live draft integration
//
// MARK: -> Sleeper API Client

import Foundation

/// Protocol for draft API clients (future ESPN support)
protocol DraftAPIClient {
    func fetchUser(username: String) async throws -> SleeperUser
    func fetchUserByID(userID: String) async throws -> SleeperUser
    func fetchLeagues(userID: String, season: String) async throws -> [SleeperLeague]
    func fetchLeague(leagueID: String) async throws -> SleeperLeague  // Added this
    func fetchDraft(draftID: String) async throws -> SleeperDraft
    func fetchDraftPicks(draftID: String) async throws -> [SleeperPick]
    func fetchRosters(leagueID: String) async throws -> [SleeperRoster]
    func fetchAllPlayers() async throws -> [String: SleeperPlayer]
    func fetchNFLState() async throws -> SleeperNFLState
}

final class SleeperAPIClient: DraftAPIClient {
    static let shared = SleeperAPIClient()
    
    private let baseURL = "https://api.sleeper.app/v1"
    private let session = URLSession.shared
    
    private init() {}
    
    // MARK: -> User
    func fetchUser(username: String) async throws -> SleeperUser {
        let url = URL(string: "\(baseURL)/user/\(username)")!
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw SleeperAPIError.invalidResponse
        }
        
        return try JSONDecoder().decode(SleeperUser.self, from: data)
    }
    
    func fetchUserByID(userID: String) async throws -> SleeperUser {
        let url = URL(string: "\(baseURL)/user/\(userID)")!
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw SleeperAPIError.invalidResponse
        }
        
        return try JSONDecoder().decode(SleeperUser.self, from: data)
    }
    
    // MARK: -> League Endpoints
    
    /// Fetch leagues for a specific user (season parameter for protocol compliance)
    func fetchLeagues(userID: String, season: String) async throws -> [SleeperLeague] {
        let url = URL(string: "\(baseURL)/user/\(userID)/leagues/nfl/\(season)")!
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw SleeperAPIError.invalidResponse
        }
        
        let leagues = try JSONDecoder().decode([SleeperLeague].self, from: data)
        print("✅ Fetched \(leagues.count) leagues for user \(userID)")
        return leagues
    }
    
    /// Fetch leagues for a specific user (convenience method with default season)
    func fetchLeagues(userID: String) async throws -> [SleeperLeague] {
        return try await fetchLeagues(userID: userID, season: "2024")
    }
    
    /// Fetch a specific league by ID
    func fetchLeague(leagueID: String) async throws -> SleeperLeague {
        let url = URL(string: "\(baseURL)/league/\(leagueID)")!
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw SleeperAPIError.invalidResponse
        }
        
        let league = try JSONDecoder().decode(SleeperLeague.self, from: data)
        print("✅ Fetched league: \(league.name)")
        return league
    }
    
    /// Fetch rosters for a league
    func fetchRosters(leagueID: String) async throws -> [SleeperRoster] {
        let url = URL(string: "\(baseURL)/league/\(leagueID)/rosters")!
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw SleeperAPIError.invalidResponse
        }
        
        let rosters = try JSONDecoder().decode([SleeperRoster].self, from: data)
        print("✅ Fetched \(rosters.count) rosters for league \(leagueID)")
        return rosters
    }
    
    // MARK: -> Draft
    func fetchDraft(draftID: String) async throws -> SleeperDraft {
        let url = URL(string: "\(baseURL)/draft/\(draftID)")!
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw SleeperAPIError.invalidResponse
        }
        
        return try JSONDecoder().decode(SleeperDraft.self, from: data)
    }
    
    // MARK: -> Draft Picks
    func fetchDraftPicks(draftID: String) async throws -> [SleeperPick] {
        let url = URL(string: "\(baseURL)/draft/\(draftID)/picks")!
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw SleeperAPIError.invalidResponse
        }
        
        return try JSONDecoder().decode([SleeperPick].self, from: data)
    }
    
    // MARK: -> Players (5MB JSON - Cache This!)
    func fetchAllPlayers() async throws -> [String: SleeperPlayer] {
        let url = URL(string: "\(baseURL)/players/nfl")!
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw SleeperAPIError.invalidResponse
        }
        
        return try JSONDecoder().decode([String: SleeperPlayer].self, from: data)
    }
    
    // MARK: -> NFL State
    func fetchNFLState() async throws -> SleeperNFLState {
        let url = URL(string: "\(baseURL)/state/nfl")!
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw SleeperAPIError.invalidResponse
        }
        
        return try JSONDecoder().decode(SleeperNFLState.self, from: data)
    }
}

// MARK: -> API Errors
enum SleeperAPIError: Error, LocalizedError {
    case invalidResponse
    case networkError(Error)
    case decodingError(Error)
    case rateLimited
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid API response"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        case .rateLimited:
            return "API rate limit exceeded"
        }
    }
}