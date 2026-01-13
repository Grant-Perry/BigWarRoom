//
//  FieldPositionView.swift
//  BigWarRoom
//
//  Visual representation of football field with ball position
//

import SwiftUI

/// Displays a football field with team endzones and ball position
struct FieldPositionView: View {
    @Environment(TeamAssetManager.self) private var teamAssets
    
    let yardLine: String  // e.g., "HOU 30" or "50"
    let awayTeam: String  // Team code for left endzone
    let homeTeam: String  // Team code for right endzone
    
    var body: some View {
        VStack(spacing: 6) {
            // Field visualization
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Field background
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(red: 0.2, green: 0.5, blue: 0.2))  // Dark green
                        .overlay {
                            // Yard line markers
                            HStack(spacing: 0) {
                                ForEach(0..<11) { index in
                                    Rectangle()
                                        .fill(Color.white.opacity(0.3))
                                        .frame(width: 1)
                                    
                                    if index < 10 {
                                        Spacer()
                                    }
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                    
                    // Left endzone (away team)
                    HStack(spacing: 0) {
                        endzoneView(for: awayTeam)
                            .frame(width: 30)
                        
                        Spacer()
                        
                        // Right endzone (home team)
                        endzoneView(for: homeTeam)
                            .frame(width: 30)
                    }
                    
                    // 50 yard line marker
                    Rectangle()
                        .fill(Color.yellow.opacity(0.4))
                        .frame(width: 2)
                        .offset(x: calculateFieldPosition(for: "50", in: geometry.size.width))
                    
                    // Yard line numbers ON the field
                    HStack(spacing: 0) {
                        ForEach([10, 20, 30, 40], id: \.self) { yard in
                            Text("\(yard)")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white.opacity(0.5))
                                .frame(maxWidth: .infinity)
                        }
                        
                        Text("50")
                            .font(.system(size: 16, weight: .black))
                            .foregroundStyle(.yellow.opacity(0.8))
                            .frame(maxWidth: .infinity)
                        
                        ForEach([40, 30, 20, 10], id: \.self) { yard in
                            Text("\(yard)")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white.opacity(0.5))
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 30)
                    
                    // Football position
                    footballIcon
                        .offset(x: calculateBallPosition(in: geometry.size.width) - 15)  // Center the larger icon
                }
            }
            .frame(height: 50)
            
            // Yard markers below field
            HStack(spacing: 0) {
                Text("0")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, alignment: .center)
                
                Spacer()
                
                Text("50")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text("0")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, alignment: .center)
            }
        }
        .frame(height: 70)  // Total height including markers
    }
    
    private func endzoneView(for team: String) -> some View {
        ZStack {
            // Endzone background color (use team colors)
            if let teamObj = NFLTeam.team(for: team) {
                teamObj.primaryColor
                    .opacity(0.8)
            } else {
                Color.blue.opacity(0.8)
            }
            
            // Team logo
            if let logo = teamAssets.logo(for: team) {
                logo
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                    .opacity(0.7)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
    
    private var footballIcon: some View {
        Text("🏈")
            .font(.system(size: 20))
            .shadow(color: .white.opacity(0.6), radius: 8, x: 0, y: 0)
            .shadow(color: .white.opacity(0.4), radius: 12, x: 0, y: 0)
    }
    
    /// Calculate horizontal position of ball on the field
    private func calculateBallPosition(in width: CGFloat) -> CGFloat {
        guard let position = parseFieldPosition() else {
            return 30  // Default to left endzone if parsing fails
        }
        
        return calculateFieldPosition(for: String(position), in: width)
    }
    
    /// Parse field position from yardLine string
    /// Returns absolute yard line from away team's perspective (0-100)
    private func parseFieldPosition() -> Int? {
        // Handle 50-yard line
        if yardLine.trimmingCharacters(in: .whitespaces) == "50" {
            return 50
        }
        
        // Parse format: "HOU 30" or "PIT 45"
        let components = yardLine.split(separator: " ")
        guard components.count == 2,
              let yards = Int(components[1]) else {
            return nil
        }
        
        let teamCode = String(components[0])
        
        // Determine if ball is on away team's side or home team's side
        if teamCode == awayTeam {
            // Ball is on away team's side (left endzone)
            return yards
        } else if teamCode == homeTeam {
            // Ball is on home team's side (right endzone)
            return 100 - yards
        }
        
        return nil
    }
    
    /// Calculate pixel position based on yard line
    private func calculateFieldPosition(for yardLineString: String, in totalWidth: CGFloat) -> CGFloat {
        guard let yards = Int(yardLineString) else { return 30 }
        
        // Endzone width
        let endzoneWidth: CGFloat = 30
        let playableWidth = totalWidth - (endzoneWidth * 2)
        
        // Convert yard line to percentage (0-100)
        let percentage = CGFloat(yards) / 100.0
        
        // Calculate position (add endzone offset)
        return endzoneWidth + (playableWidth * percentage)
    }
}

#Preview {
    VStack(spacing: 20) {
        Text("Ball at HOU 30")
            .font(.caption)
        FieldPositionView(yardLine: "HOU 30", awayTeam: "HOU", homeTeam: "PIT")
        
        Text("Ball at 50")
            .font(.caption)
        FieldPositionView(yardLine: "50", awayTeam: "HOU", homeTeam: "PIT")
        
        Text("Ball at PIT 20")
            .font(.caption)
        FieldPositionView(yardLine: "PIT 20", awayTeam: "HOU", homeTeam: "PIT")
    }
    .padding()
    .environment(TeamAssetManager())
}