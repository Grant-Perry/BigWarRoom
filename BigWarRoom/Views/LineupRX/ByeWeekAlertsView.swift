//
//  ByeWeekAlertsView.swift
//  BigWarRoom
//
//  Bye week and injury alerts section for Lineup RX
//

import SwiftUI

struct ByeWeekAlertsView: View {
    let alerts: [PlayerAlert]
    let sleeperPlayerCache: [String: SleeperPlayer]
    
    @State private var isExpanded: Bool = false
    
    // Important if there are any alerts
    private var hasImportantInfo: Bool {
        !alerts.isEmpty
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    SectionHeader(icon: "exclamationmark.triangle.fill", title: "BYE Week & Injury Alerts", color: .orange)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.orange)
                }
            }
            
            if isExpanded {
                if alerts.isEmpty {
                    Text("No bye week or injury alerts this week")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .padding()
                } else {
                    ForEach(alerts, id: \.player.id) { alert in
                        ByeInjuryAlertRow(alert: alert, sleeperPlayerCache: sleeperPlayerCache)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(hasImportantInfo ? Color.gpRedPink : Color.orange.opacity(0.3), lineWidth: hasImportantInfo ? 2 : 1)
                )
        )
        .shadow(color: hasImportantInfo ? Color.gpRedPink.opacity(0.6) : Color.clear, radius: 8, x: 0, y: 0)
    }
}

struct ByeInjuryAlertRow: View {
    let alert: PlayerAlert
    let sleeperPlayerCache: [String: SleeperPlayer]
    
    // Get SleeperPlayer for navigation
    private var sleeperPlayer: SleeperPlayer? {
        guard let sleeperID = alert.player.sleeperID else { return nil }
        return sleeperPlayerCache[sleeperID] ?? PlayerDirectoryStore.shared.player(for: sleeperID)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Player image - CLICKABLE to player stats
            ClickablePlayerImage(
                sleeperPlayer: sleeperPlayer,
                size: 44,
                borderColor: alert.type == .bye ? .orange : .gpRedPink
            )
            
            // Player info
            VStack(alignment: .leading, spacing: 4) {
                Text(alert.player.fullName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                
                HStack(spacing: 6) {
                    Text(alert.player.position)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.gray)
                    
                    if let team = alert.player.team {
                        TeamLogoView(teamCode: team, size: 18)
                    }
                }
            }
            
            Spacer()
            
            // Alert message
            Text(alert.message)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(alert.type == .bye ? .orange : .gpRedPink)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill((alert.type == .bye ? Color.orange : Color.gpRedPink).opacity(0.2))
                )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.4))
        )
    }
}

struct PlayerAlert {
    let player: FantasyPlayer
    let type: AlertType
    let message: String
    
    enum AlertType {
        case bye
        case injury
    }
}
