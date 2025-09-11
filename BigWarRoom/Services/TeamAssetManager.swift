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
    
    /// Team-branded background - FAST PATH using direct color lookup
    func teamBackground(for teamCode: String) -> some View {
        // FAST PATH: Skip slow NFLTeam lookup, use direct color mapping
        let teamColor = getTeamColorFast(for: teamCode)
        
        return AnyView(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [teamColor.opacity(0.8), teamColor],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ).opacity(0.1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(teamColor.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    /// FAST team color lookup - no dictionary lookups, no NFLTeam objects
    private func getTeamColorFast(for teamCode: String) -> Color {
        switch teamCode.uppercased() {
        // AFC East
        case "BUF": return Color(red: 0/255, green: 51/255, blue: 141/255)
        case "MIA": return Color(red: 0/255, green: 142/255, blue: 151/255)
        case "NE": return Color(red: 0/255, green: 34/255, blue: 68/255)
        case "NYJ": return Color(red: 18/255, green: 87/255, blue: 64/255)
            
        // AFC North
        case "BAL": return Color(red: 26/255, green: 25/255, blue: 95/255)
        case "CIN": return Color(red: 251/255, green: 79/255, blue: 20/255)
        case "CLE": return Color(red: 49/255, green: 29/255, blue: 0/255)
        case "PIT": return Color.black
            
        // AFC South
        case "HOU": return Color(red: 3/255, green: 32/255, blue: 47/255)
        case "IND": return Color(red: 0/255, green: 44/255, blue: 95/255)
        case "JAX", "JAC": return Color(red: 0/255, green: 103/255, blue: 120/255)
        case "TEN": return Color(red: 0/255, green: 34/255, blue: 68/255)
            
        // AFC West
        case "DEN": return Color(red: 251/255, green: 79/255, blue: 20/255)
        case "KC": return Color(red: 227/255, green: 24/255, blue: 55/255)
        case "LV": return Color.black
        case "LAC": return Color(red: 0/255, green: 128/255, blue: 198/255)
            
        // NFC East
        case "DAL": return Color(red: 0/255, green: 34/255, blue: 68/255)
        case "NYG": return Color(red: 1/255, green: 35/255, blue: 82/255)
        case "PHI": return Color(red: 0/255, green: 76/255, blue: 84/255)
        case "WAS", "WSH": return Color(red: 90/255, green: 20/255, blue: 20/255)
            
        // NFC North
        case "CHI": return Color(red: 11/255, green: 22/255, blue: 42/255)
        case "DET": return Color(red: 0/255, green: 118/255, blue: 182/255)
        case "GB": return Color(red: 24/255, green: 48/255, blue: 40/255)
        case "MIN": return Color(red: 79/255, green: 38/255, blue: 131/255)
            
        // NFC South
        case "ATL": return Color(red: 167/255, green: 25/255, blue: 48/255)
        case "CAR": return Color(red: 0/255, green: 133/255, blue: 202/255)
        case "NO": return Color(red: 211/255, green: 188/255, blue: 141/255)
        case "TB": return Color(red: 213/255, green: 10/255, blue: 10/255)
            
        // NFC West
        case "ARI": return Color(red: 151/255, green: 35/255, blue: 63/255)
        case "LAR": return Color(red: 0/255, green: 53/255, blue: 148/255)
        case "SF": return Color(red: 170/255, green: 0/255, blue: 0/255)
        case "SEA": return Color(red: 0/255, green: 34/255, blue: 68/255)
            
        default:
            return Color.gray
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
                    // x// x Print("📥 Downloaded logo for \(teamCode)")
                    return
                }
            } catch {
                // x// x Print("❌ Failed to download logo for \(teamCode) from \(urlString): \(error)")
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
        // Use fast color lookup instead of slow NFLTeam lookup
        let teamColor = getTeamColorFast(for: teamCode)
        let initials = teamCode.prefix(2).uppercased()
        
        return Circle()
            .fill(teamColor)
            .overlay(
                Text(initials)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
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