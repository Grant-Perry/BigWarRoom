//
//  AIService.swift
//  BigWarRoom
//
//  Service to communicate with AI for draft suggestions
//

import Foundation

// MARK: -> AI Suggestion Models
struct AISuggestion: Codable {
    let playerID: String
    let reasoning: String
    
    private enum CodingKeys: String, CodingKey {
        case playerID = "player_id"
        case reasoning
    }
}

struct AITop25Response: Codable {
    let suggestions: [AISuggestion]
}

// MARK: -> AI Service
final class AIService {
    static let shared = AIService()
    
    private let openAIURL = URL(string: "https://api.openai.com/v1/chat/completions")!
    private let openAIModel = "gpt-4o-mini"
    private let session = URLSession.shared
    
    private init() {}
    
    // MARK: -> Fetch AI Top 25
    func fetchTop25Suggestions(
        league: SleeperLeague,
        draft: SleeperDraft,
        picks: [SleeperPick],
        roster: SleeperRoster,
        availablePlayers: [String: SleeperPlayer]
    ) async throws -> [AISuggestion] {
        guard let apiKey = AppSecrets.openAIAPIKey else {
            throw AIError.missingAPIKey
        }
        
        // Build compact context payload to minimize tokens
        let context: [String: Any] = [
            "league": [
                "league_id": league.leagueID,
                "name": league.name,
                "season": league.season,
                "settings": league.scoringSettings ?? [:],
                "roster_positions": league.rosterPositions ?? []
            ],
            "draft": [
                "draft_id": draft.draftID,
                "status": draft.status.rawValue,
                "type": draft.type.rawValue,
                "settings": [
                    "teams": draft.settings?.teams ?? 12,
                    "rounds": draft.settings?.rounds ?? 15
                ]
            ],
            "current_picks": picks.map { p in
                [
                    "pick_no": p.pickNo,
                    "round": p.round,
                    "roster_id": p.rosterID ?? -1,
                    "player_id": p.playerID ?? ""
                ]
            },
            "my_roster": [
                "players": roster.playerIDs ?? []
            ],
            "available_players": availablePlayers.mapValues { player in
                [
                    "player_id": player.playerID,
                    "first_name": player.firstName ?? "",
                    "last_name": player.lastName ?? "",
                    "position": player.position ?? "",
                    "team": player.team ?? "",
                    "fantasy_positions": player.fantasyPositions ?? [],
                    "age": player.age ?? 0,
                    "years_exp": player.yearsExp ?? 0,
                    "search_rank": player.searchRank ?? 999
                ] as [String : Any]
            },
            "target_limit": 25
        ]
        
        // Serialize user content JSON
        let userContentData = try JSONSerialization.data(withJSONObject: context, options: [])
        let userContentString = String(data: userContentData, encoding: .utf8) ?? "{}"
        
        // System instructions to force strict JSON output
        let systemPrompt = """
        You are a fantasy football draft assistant. Given the draft context and available players, return the BEST draft targets now.
        Requirements:
        - ONLY output valid JSON matching this schema: {"suggestions":[{"player_id":"<string>","reasoning":"<string>"}]}
        - suggestions must be at most target_limit long.
        - player_id MUST be from available_players keys.
        - reasoning: 1-2 short sentences about value, team need, and draft context.
        - Prefer filling RB/WR early, QBs round 7-10 unless elite and roster needs it, TE only if top tier falls, K/DST last rounds.
        """
        
        let requestBody: [String: Any] = [
            "model": openAIModel,
            "temperature": 0.3,
            "response_format": ["type": "json_object"],
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userContentString]
            ]
        ]
        
        var request = URLRequest(url: openAIURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  200..<300 ~= httpResponse.statusCode else {
                if let body = String(data: data, encoding: .utf8) {
                    // x// x Print("❌ OpenAI error \( (response as? HTTPURLResponse)?.statusCode ?? -1 ): \(body)")
                }
                throw AIError.invalidResponse
            }
            
            // Decode the chat completion and then parse the JSON content
            let chat = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
            guard let content = chat.choices.first?.message.content.data(using: .utf8) else {
                throw AIError.invalidResponse
            }
            
            let aiResponse = try JSONDecoder().decode(AITop25Response.self, from: content)
            return aiResponse.suggestions
        } catch let err as DecodingError {
            throw AIError.decodingError(err)
        } catch {
            throw AIError.networkError(error)
        }
    }
}

private struct OpenAIChatResponse: Codable {
    struct Choice: Codable {
        struct Message: Codable {
            let role: String
            let content: String
        }
        let index: Int
        let message: Message
        let finish_reason: String?
    }
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [Choice]
}

// MARK: -> AI Errors
enum AIError: Error, LocalizedError {
    case invalidResponse
    case networkError(Error)
    case decodingError(Error)
    case missingAPIKey
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid AI response"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        case .missingAPIKey:
            return "Missing OpenAI API Key. Add it to Secrets.plist as OPENAI_API_KEY."
        }
    }
}
