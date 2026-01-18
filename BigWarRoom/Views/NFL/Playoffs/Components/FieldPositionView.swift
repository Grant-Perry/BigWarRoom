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
                    // Left/right endzones per quarter swap - BEHIND everything
                    HStack(spacing: 0) {
                        endzoneView(for: leftTeam, isActive: ballIsInThisEndzone(leftTeam))
                            .frame(width: 34)
                        
                        Spacer()
                        
                        endzoneView(for: rightTeam, isActive: ballIsInThisEndzone(rightTeam))
                            .frame(width: 34)
                    }
                    
                    // Field background - sits ON TOP of endzones
                    RoundedRectangle(cornerRadius: 0)
                        .fill(Color(red: 0.2, green: 0.5, blue: 0.2))
                        .padding(.horizontal, 34)
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
                            .padding(.horizontal, 34)
                        }
                    
                    // 50 yard line marker
                    Rectangle()
                        .fill(Color.yellow.opacity(0.4))
                        .frame(width: 2)
                        .offset(x: calculateFieldPosition(for: "50", in: geometry.size.width))
                    
                    // Yard line numbers ON the field - centered on vertical lines
                    ZStack {
                        // Left side: 10, 20, 30, 40
                        ForEach(Array([10, 20, 30, 40].enumerated()), id: \.offset) { index, yard in
                            Text("\(yard)")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white.opacity(0.3))
                                .position(
                                    x: calculateFieldPosition(for: String(yard), in: geometry.size.width),
                                    y: 25
                                )
                        }
                        
                        // 50 yard line
                        Text("50")
                            .font(.system(size: 16, weight: .black))
                            .foregroundStyle(.yellow.opacity(0.45))
                            .position(
                                x: calculateFieldPosition(for: "50", in: geometry.size.width),
                                y: 25
                            )
                        
                        // Right side: 40, 30, 20, 10
                        ForEach(Array([40, 30, 20, 10].enumerated()), id: \.offset) { index, yard in
                            Text("\(yard)")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white.opacity(0.3))
                                .position(
                                    x: calculateFieldPosition(for: String(100 - yard), in: geometry.size.width),
                                    y: 25
                                )
                        }
                    }
                    
                    // Football position - only show if we have a valid position
                    if parseFieldYards() != nil {
                        footballIcon
                            .offset(x: calculateBallPosition(in: geometry.size.width) - 15)
                    }
                }
            }
            .frame(height: 50)
        }
        .frame(height: 70)
        .onAppear {
            DebugPrint(mode: .fieldPosition, "🖼️ [FIELD POS VIEW] onAppear - yardLine='\(yardLine)', awayTeam=\(awayTeam), homeTeam=\(homeTeam), possession=\(possession ?? "nil"), quarter=\(quarter)")
            
            if let yards = parseFieldYards() {
                DebugPrint(mode: .fieldPosition, "   ✅ parseFieldYards() = \(yards) - football WILL show")
            } else {
                DebugPrint(mode: .fieldPosition, "   ❌ parseFieldYards() = NIL - football will NOT show!")
                DebugPrint(mode: .fieldPosition, "   yardLine string analysis: '\(yardLine)'")
                let components = yardLine.split(separator: " ")
                DebugPrint(mode: .fieldPosition, "   split by space: [\(components.map { "'\($0)'" }.joined(separator: ", "))]")
            }
        }
    }
    
    private func endzoneView(for team: String, isActive: Bool = false) -> some View {
        ZStack {
            if let teamObj = NFLTeam.team(for: team) {
                // Gradient fade: left endzone fades left-to-right, right endzone fades right-to-left
                let isLeftEndzone = (team == leftTeam)
                LinearGradient(
                    colors: isLeftEndzone 
                        ? [teamObj.primaryColor.opacity(0.8), .clear]
                        : [.clear, teamObj.primaryColor.opacity(0.8)],
                    startPoint: isLeftEndzone ? .leading : .trailing,
                    endPoint: isLeftEndzone ? .trailing : .leading
                )
            } else {
                Color.blue.opacity(0.8)
            }
            if let logo = teamAssets.logo(for: team) {
                logo
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .opacity(0.7)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isActive ? Color.gpGreen : Color.secondary, lineWidth: isActive ? 3 : 1)
                .padding(2)
        )
    }
    
    private var footballIcon: some View {
        HStack(spacing: -2) {
            // Chevron now based on per-quarter orientation!
            if ballIsMovingRight {
                Text("🏈")
                    .font(.system(size: 20))
                    .shadow(color: .white.opacity(0.9), radius: 4, x: 0, y: 0)
                    .shadow(color: .white.opacity(0.7), radius: 8, x: 0, y: 0)
                    .shadow(color: .white.opacity(0.5), radius: 12, x: 0, y: 0)
				  // I'm gonna comment out the chevron for now
				  // the ball should point in the direction of the play
//                Image(systemName: "chevron.right")
//                    .font(.system(size: 24, weight: .bold))
//                    .foregroundStyle(.white.opacity(0.35))
//					.offset(x: -7) // push it closer to the ball

            } else {
//                Image(systemName: "chevron.left")
//                    .font(.system(size: 12, weight: .bold))
//                    .foregroundStyle(.white.opacity(0.5))
//					.offset(x: -3)
                Text("🏈")
                    .font(.system(size: 20))
					.scaleEffect(x: -1)
                    .shadow(color: .white.opacity(0.9), radius: 4, x: 0, y: 0)
                    .shadow(color: .white.opacity(0.7), radius: 8, x: 0, y: 0)
                    .shadow(color: .white.opacity(0.5), radius: 12, x: 0, y: 0)
            }
        }
    }

    // CHEVRON LOGIC: If possession == leftTeam, they attack right (towards right endzone), otherwise attack left
    private var ballIsMovingRight: Bool {
        guard let possession = possession else { return true }
        return possession == leftTeam
    }
    
    /// Determine if this team has possession (highlights their endzone)
    private func ballIsInThisEndzone(_ team: String) -> Bool {
        guard let possession = possession else { return false }
        return possession == team
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
        
        if yardLine.trimmingCharacters(in: .whitespaces) == "50" { 
            return 50 
        }
        
        guard components.count == 2, let yards = Int(components[1]) else { 
            return nil 
        }
        
        return yards
    }
    
    private func parseFieldTeam() -> String? {
        let components = yardLine.split(separator: " ")
        if components.count == 2 { return String(components[0]) }
        return nil
    }
    
    /// Calculate pixel position based on yard line (per quarter orientation)
    private func calculateFieldPosition(for yardLineString: String, in totalWidth: CGFloat) -> CGFloat {
        guard let yards = Int(yardLineString) else { return 34 }
        let endzoneWidth: CGFloat = 34
        let playableWidth = totalWidth - (endzoneWidth * 2)
        let percentage = CGFloat(yards) / 100.0
        return endzoneWidth + (playableWidth * percentage)
    }
}

// MARK: - Helper

@ViewBuilder
private func testCase(
    title: String,
    expected: String,
    yardLine: String,
    awayTeam: String,
    homeTeam: String,
    possession: String?,
    quarter: Int
) -> some View {
    VStack(alignment: .leading, spacing: 8) {
        if !title.isEmpty {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
        }
        
        if !expected.isEmpty {
            Text(expected)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .italic()
        }
        
        FieldPositionView(
            yardLine: yardLine,
            awayTeam: awayTeam,
            homeTeam: homeTeam,
            possession: possession,
            quarter: quarter
        )
    }
}