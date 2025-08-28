//
//  AppSecrets.swift
//  BigWarRoom
//
//  Loads secrets from Secrets.plist at runtime.
//

import Foundation

/// Secrets loader for API keys and org IDs.
/// Create a file named "Secrets.plist" in the app bundle by copying Resources/Secrets.example.plist.
enum AppSecrets {
    /// OpenAI API Key (from Secrets.plist key: OPENAI_API_KEY)
    static var openAIAPIKey: String? { value(for: "OPENAI_API_KEY") }
    /// OpenAI Org (optional, from Secrets.plist key: OPENAI_ORG)
    static var openAIOrg: String? { value(for: "OPENAI_ORG") }

    private static func value(for key: String) -> String? {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return nil }
        return dict[key] as? String
    }
}