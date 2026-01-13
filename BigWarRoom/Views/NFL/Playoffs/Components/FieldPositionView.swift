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
    let awayTeam: String  // Always away team ABR
    let homeTeam: String  // Always home team ABR
    let possession: String?  // Team ABR that has possession
    let quarter: Int  // 1-4 (NFL logic: swap endzones Q2/Q4)

    // Computed: which team is left/right endzone this quarter?
    private var leftTeam: String { (quarter % 2 == 1) ? awayTeam : homeTeam }
    private var rightTeam: String { (quarter % 2 == 1) ? homeTeam : awayTeam }
    
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
                    
                    // Left/right endzones per quarter swap!
                    HStack(spacing: 0) {
                        endzoneView(for: leftTeam, isActive: ballIsInThisEndzone(leftTeam))
                            .frame(width: 30)
                        
                        Spacer()
                        
                        endzoneView(for: rightTeam, isActive: ballIsInThisEndzone(rightTeam))
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
                    
                    // Football position - only show if we have a valid position
                    if parseFieldYards() != nil {
                        footballIcon
                            .offset(x: calculateBallPosition(in: geometry.size.width) - 15)
                    }
                }
            }
            .frame(height: 50)
        }
        .frame(height: 70)  // Total height including markers
    }
    
    private func endzoneView(for team: String, isActive: Bool = false) -> some View {
        ZStack {
            if let teamObj = NFLTeam.team(for: team) {
                teamObj.primaryColor.opacity(0.8)
            } else {
                Color.blue.opacity(0.8)
            }
            if let logo = teamAssets.logo(for: team) {
                logo
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                    .opacity(0.7)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.gpGreen, lineWidth: isActive ? 2 : 0)
        )
    }
    
    private var footballIcon: some View {
        HStack(spacing: -2) {
            // Chevron now based on per-quarter orientation!
            if ballIsMovingRight {
                Text("🏈")
                    .font(.system(size: 20))
                    .shadow(color: .white.opacity(0.6), radius: 8, x: 0, y: 0)
                    .shadow(color: .white.opacity(0.4), radius: 12, x: 0, y: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white.opacity(0.5))
            } else {
                Image(systemName: "chevron.left")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white.opacity(0.5))
                Text("🏈")
                    .font(.system(size: 20))
                    .shadow(color: .white.opacity(0.6), radius: 8, x: 0, y: 0)
                    .shadow(color: .white.opacity(0.4), radius: 12, x: 0, y: 0)
            }
        }
    }

    // CHEVRON LOGIC: If possession == leftTeam, they attack right (towards right endzone), otherwise attack left
    private var ballIsMovingRight: Bool {
        guard let possession = possession else { return true }
        return possession == leftTeam
    }
    
    /// Determine if the ball is currently in this team's endzone area (per quarter)
    private func ballIsInThisEndzone(_ team: String) -> Bool {
        guard let fieldTeam = parseFieldTeam() else { return false }
        return fieldTeam == team
    }
    
    /// Calculate football's horizontal position (per quarter orientation)
    private func calculateBallPosition(in width: CGFloat) -> CGFloat {
        guard let yards = parseFieldYards(), let side = parseFieldTeam() else { return 30 }
        // Always number 0-100 from leftEndzone to rightEndzone
        // "team X YY" means YY yards from team X's endzone
        // If team X == leftTeam:  XX from left
        // If team X == rightTeam: 100-XX from left
        let yardValue = (side == leftTeam) ? yards : (100 - yards)
        return calculateFieldPosition(for: String(yardValue), in: width)
    }
    
    /// Parse field position from yardLine string into (team, yards)
    private func parseFieldYards() -> Int? {
        let components = yardLine.split(separator: " ")
        if yardLine.trimmingCharacters(in: .whitespaces) == "50" { return 50 }
        guard components.count == 2, let yards = Int(components[1]) else { return nil }
        return yards
    }
    
    private func parseFieldTeam() -> String? {
        let components = yardLine.split(separator: " ")
        if components.count == 2 { return String(components[0]) }
        return nil
    }
    
    /// Calculate pixel position based on yard line (per quarter orientation)
    private func calculateFieldPosition(for yardLineString: String, in totalWidth: CGFloat) -> CGFloat {
        guard let yards = Int(yardLineString) else { return 30 }
        let endzoneWidth: CGFloat = 30
        let playableWidth = totalWidth - (endzoneWidth * 2)
        let percentage = CGFloat(yards) / 100.0
        return endzoneWidth + (playableWidth * percentage)
    }
}