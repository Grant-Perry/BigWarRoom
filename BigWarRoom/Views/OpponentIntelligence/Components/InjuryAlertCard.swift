//
//  InjuryAlertCard.swift
//  BigWarRoom
//
//  Critical Threat Alert card for injured/BYE players
//

import SwiftUI

/// Card displaying injury status alerts for my rostered players
struct InjuryAlertCard: View {
    let recommendation: StrategicRecommendation
    
    // Extract player info from recommendation description (temporary until we pass InjuryAlert directly)
    private var playerName: String {
        // Parse player name from description (e.g., "Josh Allen is on BYE Week...")
        let components = recommendation.description.components(separatedBy: " is ")
        return components.first ?? "Unknown Player"
    }
    
    private var statusType: InjuryStatusType {
        let description = recommendation.description.lowercased()
        if description.contains("bye") {
            return .bye
        } else if description.contains("injured reserve") || description.contains("ir") {
            return .injuredReserve
        } else if description.contains("status is o") || description.contains("out") {
            return .out
        } else if description.contains("questionable") {
            return .questionable
        }
        return .questionable // fallback
    }
    
    private var priorityBadge: String {
        switch statusType {
        case .bye, .injuredReserve, .out:
            return "URGENT"
        case .questionable:
            return "ATTENTION"
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Status icon with priority-based styling
            ZStack {
                Circle()
                    .fill(statusType.color)
                    .frame(width: 50, height: 50)
                
                Image(systemName: statusType.sfSymbol)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                // Priority indicator (for critical alerts)
                if recommendation.priority == .critical {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Circle()
                                .fill(Color.red)
                                .frame(width: 16, height: 16)
                                .overlay(
                                    Image(systemName: "exclamationmark")
                                        .font(.system(size: 10, weight: .black))
                                        .foregroundColor(.white)
                                )
                        }
                    }
                    .frame(width: 50, height: 50)
                }
            }
            
            // Alert content
            VStack(alignment: .leading, spacing: 6) {
                // Alert title with status
                HStack {
                    Text(statusType.alertTitle)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Priority badge
                    Text(priorityBadge)
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(statusType.color)
                        )
                }
                
                // Player name and position (extracted from description)
                Text(playerName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                
                // Action description
                Text(getActionText())
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(2)
            }
            
            // Action button
            Button(action: {
                handleActionTap()
            }) {
                VStack(spacing: 4) {
                    Image(systemName: getActionIcon())
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("FIX")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(statusType.color.opacity(0.8))
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(statusType.color, lineWidth: 2)
                )
        )
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            statusType.color.opacity(0.2),
                            statusType.color.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }
    
    // MARK: - Helper Methods
    
    private func getActionText() -> String {
        switch statusType {
        case .bye:
            return "Replace immediately - won't play this week"
        case .injuredReserve:
            return "Move to IR slot or find replacement"
        case .out:
            return "Replace before games start - confirmed out"
        case .questionable:
            return "Monitor status and prepare backup plan"
        }
    }
    
    private func getActionIcon() -> String {
        switch statusType {
        case .bye, .out:
            return "person.crop.circle.fill.badge.minus" // Replace player
        case .injuredReserve:
            return "cross.case.fill" // Medical/IR
        case .questionable:
            return "eye.fill" // Monitor
        }
    }
    
    private func handleActionTap() {
        // TODO: Implement navigation to roster management
        // Could navigate to specific league's lineup page
        // Or show quick-fix options
        print("Fix \(statusType.displayName) for \(playerName)")
    }
}

// MARK: - Preview

#Preview("Injury Alert Cards") {
    VStack(spacing: 16) {
        // BYE Week Alert
        InjuryAlertCard(recommendation: StrategicRecommendation(
            type: .injuryAlert,
            title: "🛌 Player on BYE Week", 
            description: "Josh Allen is on BYE Week in Main League. Replace in your starting lineup immediately.",
            priority: .critical,
            actionable: true,
            opponentTeam: nil
        ))
        
        // Injured Reserve Alert  
        InjuryAlertCard(recommendation: StrategicRecommendation(
            type: .injuryAlert,
            title: "🏥 Player on Injured Reserve",
            description: "Christian McCaffrey is on Injured Reserve (IR) in Dynasty League. Move to IR slot or replace.",
            priority: .high,
            actionable: true,
            opponentTeam: nil
        ))
        
        // OUT Alert
        InjuryAlertCard(recommendation: StrategicRecommendation(
            type: .injuryAlert,
            title: "❌ Player OUT",
            description: "Cooper Kupp is OUT in Redraft League. Replace in your starting lineup before games start.",
            priority: .critical,
            actionable: true,
            opponentTeam: nil
        ))
        
        // Questionable Alert
        InjuryAlertCard(recommendation: StrategicRecommendation(
            type: .injuryAlert,
            title: "⚠️ Player QUESTIONABLE", 
            description: "Travis Kelce is QUESTIONABLE in Work League. Monitor closely and have backup ready.",
            priority: .high,
            actionable: true,
            opponentTeam: nil
        ))
    }
    .padding()
    .background(Color.black)
    .preferredColorScheme(.dark)
}