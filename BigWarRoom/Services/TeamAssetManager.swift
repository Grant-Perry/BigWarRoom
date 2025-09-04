//
//  TeamAssetManager.swift
//  BigWarRoom
//
//  Manages team logos, colors, and visual assets
//
// MARK: -> Team Asset Manager

import SwiftUI
import Foundation
import Combine

@MainActor
final class TeamAssetManager: ObservableObject {
    static let shared = TeamAssetManager()
    
    @Published private var logoCache: [String: UIImage] = [:]
    private let fileManager = FileManager.default
    
    private init() {
        preloadCommonLogos()
    }
    
    // MARK: -> Team Logo Access
    
    /// Get team logo image (cached)
    func logo(for teamCode: String) -> Image? {
        // Try cache first
        if let cachedImage = logoCache[teamCode.uppercased()] {
            return Image(uiImage: cachedImage)
        }
        
        // Try bundled asset
        if let bundledImage = loadBundledLogo(teamCode: teamCode) {
            logoCache[teamCode.uppercased()] = bundledImage
            return Image(uiImage: bundledImage)
        }
        
        // Try downloading from CDN
        Task {
            await downloadLogo(teamCode: teamCode)
        }
        
        return nil
    }
    
    /// Get team logo as UIImage for caching
    func logoUIImage(for teamCode: String) -> UIImage? {
        return logoCache[teamCode.uppercased()] ?? loadBundledLogo(teamCode: teamCode)
    }
    
    /// Team logo with fallback to initials
    func logoOrFallback(for teamCode: String) -> some View {
        Group {
            if let logoImage = logo(for: teamCode) {
                logoImage
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                // Fallback: Team initials with team colors
                teamInitialsFallback(teamCode: teamCode)
            }
        }
    }
    
    // MARK: -> Team Colors & Branding
    
    /// Get team colors and branding
    func team(for code: String) -> NFLTeam? {
        return NFLTeam.team(for: code)
    }
    
    /// Team-branded background
    func teamBackground(for teamCode: String) -> some View {
        if let team = NFLTeam.team(for: teamCode) {
            return AnyView(
                RoundedRectangle(cornerRadius: 12)
                    .fill(team.gradient.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(team.primaryColor.opacity(0.3), lineWidth: 1)
                    )
            )
        } else {
            return AnyView(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }
    
    // MARK: -> Logo Loading
    
    private func loadBundledLogo(teamCode: String) -> UIImage? {
        let assetName = "logo_\(teamCode.lowercased())"
        return UIImage(named: assetName)
    }
    
    private func downloadLogo(teamCode: String) async {
        // ESPN logo CDN
        let logoURLs = [
            "https://a.espncdn.com/i/teamlogos/nfl/500/\(teamCode.lowercased()).png",
            "https://a.espncdn.com/combiner/i?img=/i/teamlogos/nfl/500/\(teamCode.lowercased()).png&h=100&w=100",
            "https://logoeps.com/wp-content/uploads/2013/03/\(teamCode.lowercased())-vector-logo.png"
        ]
        
        for urlString in logoURLs {
            guard let url = URL(string: urlString) else { continue }
            
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    await MainActor.run {
                        logoCache[teamCode.uppercased()] = image
                        objectWillChange.send()
                    }
                    // xprint("📥 Downloaded logo for \(teamCode)")
                    return
                }
            } catch {
                // xprint("❌ Failed to download logo for \(teamCode) from \(urlString): \(error)")
            }
        }
    }
    
    private func preloadCommonLogos() {
        // Preload logos for popular teams
        let popularTeams = ["KC", "BUF", "CIN", "LAR", "SF", "GB", "DAL", "NE"]
        
        for teamCode in popularTeams {
            if let image = loadBundledLogo(teamCode: teamCode) {
                logoCache[teamCode] = image
            }
        }
    }
    
    // MARK: -> Fallback Views
    
    private func teamInitialsFallback(teamCode: String) -> some View {
        let team = NFLTeam.team(for: teamCode)
        let initials = teamCode.prefix(2).uppercased()
        
        return Circle()
            .fill(team?.primaryColor ?? Color.gray)
            .overlay(
                Text(initials)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(team?.accentColor ?? Color.white)
            )
    }
}

// MARK: -> Asset Bundle Extensions
extension Bundle {
    /// Check if team logo asset exists
    func hasTeamLogo(for teamCode: String) -> Bool {
        let assetName = "logo_\(teamCode.lowercased())"
        return path(forResource: assetName, ofType: "png") != nil ||
               path(forResource: assetName, ofType: "svg") != nil
    }
}
