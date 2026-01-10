//
//  OpenAIChatModels.swift
//  BigWarRoom
//
//  OpenAI Chat API response models
//  Used by AIService for draft suggestions
//

import Foundation

/// OpenAI Chat Completion API response structure
struct OpenAIChatResponse: Codable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [Choice]
    
    struct Choice: Codable {
        let index: Int
        let message: Message
        let finish_reason: String?
        
        struct Message: Codable {
            let role: String
            let content: String
        }
    }
}