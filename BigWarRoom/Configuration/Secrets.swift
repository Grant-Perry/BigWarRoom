//
//  Secrets.swift
//  BigWarRoom
//
//  Loads API secrets from Secrets.plist (not committed)
//

import Foundation

enum Secrets {
    /// OpenAI API Key. Create Resources/Secrets.plist with key: OPENAI_API_KEY
    static var openAIAPIKey: String? {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let obj = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dict = obj as? [String: Any],
              let key = dict["OPENAI_API_KEY"] as? String,
              !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return key
    }
    
    /// Optional: OpenAI Organization (if you use it)
    static var openAIOrganization: String? {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let obj = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dict = obj as? [String: Any],
              let org = dict["OPENAI_ORG"] as? String,
              !org.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return org
    }
    
    /// The Odds API Key for betting odds data
    static var theOddsAPIKey: String? {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let obj = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dict = obj as? [String: Any],
              let key = dict["THE_ODDS_API_KEY"] as? String,
              !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return key
    }
}