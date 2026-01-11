//
//  BettingOddsAPIClient.swift
//  BigWarRoom
//
//  API client for The Odds API - handles all network communication
//

import Foundation

@MainActor
final class BettingOddsAPIClient {
    
    private let baseURL = "https://api.the-odds-api.com/v4"
    private let session = URLSession.shared
    
    var apiKey: String {
        guard let key = Secrets.theOddsAPIKey else {
            return ""
        }
        return key
    }
    
    // MARK: - Public API
    
    /// Fetch NFL games with specific markets (e.g. h2h/spreads/totals)
    func fetchNFLGamesWithMarkets(_ markets: [String]) async throws -> [TheOddsGame] {
        var components = URLComponents(string: "\(baseURL)/sports/americanfootball_nfl/odds")
        components?.queryItems = [
            URLQueryItem(name: "apiKey", value: apiKey),
            URLQueryItem(name: "regions", value: "us"),
            URLQueryItem(name: "oddsFormat", value: "american"),
            URLQueryItem(name: "markets", value: markets.joined(separator: ","))
        ]
        
        guard let url = components?.url else {
            DebugPrint(mode: .bettingOdds, "❌ [ODDS API] Failed to build URL")
            throw BettingOddsError.invalidURL
        }
        
        DebugPrint(mode: .bettingOdds, "🌐 [ODDS API] Requesting: \(url.absoluteString)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await session.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            DebugPrint(mode: .bettingOdds, "📡 [ODDS API] Response status: \(httpResponse.statusCode)")
            
            if let remainingRequests = httpResponse.value(forHTTPHeaderField: "x-requests-remaining") {
                DebugPrint(mode: .bettingOdds, "📊 [ODDS API] Requests remaining: \(remainingRequests)")
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                DebugPrint(mode: .bettingOdds, "❌ [ODDS API] HTTP error \(httpResponse.statusCode)")
                throw BettingOddsError.httpError(httpResponse.statusCode)
            }
        }
        
        let decodedGames = try JSONDecoder().decode([TheOddsGame].self, from: data)
        DebugPrint(mode: .bettingOdds, "✅ [ODDS API] Successfully decoded \(decodedGames.count) games")
        
        return decodedGames
    }
    
    /// Fetch all available markets (fallback for player props exploration)
    func fetchAllNFLGames() async throws -> [TheOddsGame] {
        var components = URLComponents(string: "\(baseURL)/sports/americanfootball_nfl/odds")
        components?.queryItems = [
            URLQueryItem(name: "apiKey", value: apiKey),
            URLQueryItem(name: "regions", value: "us"),
            URLQueryItem(name: "oddsFormat", value: "american")
        ]
        
        guard let url = components?.url else {
            throw BettingOddsError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await session.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            guard (200...299).contains(httpResponse.statusCode) else {
                throw BettingOddsError.httpError(httpResponse.statusCode)
            }
        }
        
        let games = try JSONDecoder().decode([TheOddsGame].self, from: data)
        
        // Debug: Print available markets for analysis
        var allMarketKeys = Set<String>()
        for game in games.prefix(3) {
            for bookmaker in game.bookmakers.prefix(2) {
                for market in bookmaker.markets {
                    allMarketKeys.insert(market.key)
                }
            }
        }
        
        // Check if player props are available
        let hasPlayerProps = allMarketKeys.contains { key in
            key.lowercased().contains("player") ||
            key.lowercased().contains("touchdown") ||
            key.lowercased().contains("yards") ||
            key.lowercased().contains("reception")
        }
        
        if !hasPlayerProps {
            DebugPrint(mode: .bettingOdds, "⚠️ [ODDS API] No player props available in free tier")
        }
        
        return games
    }
}