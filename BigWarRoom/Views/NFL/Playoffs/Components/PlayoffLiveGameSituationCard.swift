//
//  PlayoffLiveGameSituationCard.swift
//  BigWarRoom
//
//  Displays live game situation with down/distance and field position
//

import SwiftUI

struct PlayoffLiveGameSituationCard: View {
    @Environment(TeamAssetManager.self) private var teamAssets
    
    let situation: LiveGameSituation
    let game: PlayoffGame
    let onLastPlayTap: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow
            lastPlayAndDriveRow
            
            if shouldShowDownDistance {
                downDistanceRow
                
                if let yardLine = situation.yardLine {
                    fieldPositionView(yardLine: yardLine)
                }
            } else {
                betweenPlaysState
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
    
    private var headerRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "football.circle")
                .font(.title3)
                .foregroundStyle(.red)
                .frame(width: 24)
            
            Text("Live Game Situation")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
            
            Spacer()
        }
    }
    
    @ViewBuilder
    private var lastPlayAndDriveRow: some View {
        HStack(alignment: .top, spacing: 12) {
            if let lastPlay = situation.lastPlay {
                Button {
                    onLastPlayTap(lastPlay)
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Last Play")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text(lastPlay)
                            .font(.caption2)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .cornerRadius(8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            
            if situation.drivePlayCount != nil || situation.driveYards != nil || situation.timeOfPossession != nil {
                currentDriveStats
            }
        }
    }
    
    private var currentDriveStats: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Current Drive")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 12) {
                if let yards = situation.driveYards {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(yards)")
                            .font(.title3)
                            .fontWeight(.bold)
                        Text("Yards")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                
                if let top = situation.timeOfPossession {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(top)
                            .font(.title3)
                            .fontWeight(.bold)
                        Text("TOP")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(8)
        .overlay(alignment: .topTrailing) {
            RefreshCountdownTimerView()
                .scaleEffect(1.2)
                .padding(8)
        }
    }
    
    private var shouldShowDownDistance: Bool {
        guard let down = situation.down,
              let distance = situation.distance,
              down > 0, down <= 4, distance >= 0 else {
            return false
        }
        
        let isTimeout = situation.lastPlay?.lowercased().contains("timeout") ?? false
        let isTwoMinuteWarning = situation.lastPlay?.lowercased().contains("two-minute warning") ?? false
        let isHalftime = (situation.lastPlay?.lowercased().contains("end quarter 2") ?? false) ||
                        (situation.lastPlay?.lowercased().contains("end of quarter 2") ?? false)
        
        return !(isTimeout || isTwoMinuteWarning || isHalftime)
    }
    
    @ViewBuilder
    private var downDistanceRow: some View {
        if let down = situation.down, let distance = situation.distance {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Down & Distance")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    let suffix: String = {
                        switch down {
                        case 1: return "st"
                        case 2: return "nd"
                        case 3: return "rd"
                        default: return "th"
                        }
                    }()
                    
                    HStack(spacing: 10) {
                        Text("\(down)\(suffix) & \(distance)")
                            .font(.title3)
                            .fontWeight(.black)
                            .foregroundStyle(.primary)
                        
                        if !clockInfo.isEmpty {
                            Text("(\(clockInfo))")
                                .font(.callout)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                if let yardLine = situation.yardLine {
                    fieldPositionText(yardLine: yardLine)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.tertiarySystemGroupedBackground))
            .cornerRadius(8)
        }
    }
    
    @ViewBuilder
    private func fieldPositionText(yardLine: String) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("Field Position")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 4) {
                if let teamCode = PlayoffBracketHelpers.extractTeamCode(from: yardLine),
                   let logo = teamAssets.logo(for: teamCode) {
                    logo
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                        .clipShape(Circle())
                }
                
                Text(yardLine)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
            }
        }
    }
    
    @ViewBuilder
    private func fieldPositionView(yardLine: String) -> some View {
        FieldPositionView(
            yardLine: yardLine,
            awayTeam: game.awayTeam.abbreviation,
            homeTeam: game.homeTeam.abbreviation,
            possession: situation.possession,
            quarter: currentQuarter
        )
        .opacity(isStoppage ? 0.6 : 1.0)
        .overlay(stoppageOverlay)
        .padding(.top, 4)
    }
    
    @ViewBuilder
    private var betweenPlaysState: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Game Status")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 10) {
                    if let possession = situation.possession,
                       (stoppageType.lowercased().contains("touchdown") ||
                        stoppageType.lowercased().contains("field goal")),
                       let logo = teamAssets.logo(for: possession) {
                        logo
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 28, height: 28)
                            .clipShape(Circle())
                    }
                    
                    Text(stoppageType)
                        .font(.title3)
                        .fontWeight(.black)
                        .foregroundStyle(.orange)
                    
                    if !clockInfo.isEmpty {
                        Text("(\(clockInfo))")
                            .font(.callout)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
            
            if let yardLine = situation.yardLine {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Last Position")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 4) {
                        if let teamCode = PlayoffBracketHelpers.extractTeamCode(from: yardLine),
                           let logo = teamAssets.logo(for: teamCode) {
                            logo
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 20, height: 20)
                                .clipShape(Circle())
                                .opacity(0.6)
                        }
                        
                        Text(yardLine)
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(8)
        
        if let yardLine = situation.yardLine {
            FieldPositionView(
                yardLine: yardLine,
                awayTeam: game.awayTeam.abbreviation,
                homeTeam: game.homeTeam.abbreviation,
                possession: situation.possession,
                quarter: currentQuarter
            )
            .opacity(0.6)
            .overlay(betweenPlaysOverlay)
            .padding(.top, 4)
        }
    }
    
    @ViewBuilder
    private var stoppageOverlay: some View {
        Group {
            if isHalftime {
                stoppageLabel(text: "HALFTIME", colors: [Color.gpYellow.opacity(0.85), Color.gpYellow.opacity(0.6)], textColor: .black)
            } else if isEndOfQuarter1 {
                stoppageLabel(text: "End of Quarter 1", colors: [Color.gpBlue.opacity(0.85), Color.gpBlue.opacity(0.6)], textColor: .white)
            } else if isEndOfQuarter3 {
                stoppageLabel(text: "End of Quarter 3", colors: [Color.gpGreen.opacity(0.85), Color.gpGreen.opacity(0.6)], textColor: .white)
            } else if isTimeout {
                stoppageLabel(text: "Commercial Break", colors: [Color.gpOrange.opacity(0.85), Color.gpOrange.opacity(0.6)], textColor: .white)
            } else if isTwoMinuteWarning {
                stoppageLabel(text: "Two-Minute Warning", colors: [Color.gpBlue.opacity(0.85), Color.gpBlue.opacity(0.6)], textColor: .white)
            }
        }
    }
    
    @ViewBuilder
    private var betweenPlaysOverlay: some View {
        let teamColor: Color = {
            if let possession = situation.possession,
               (stoppageType.lowercased().contains("touchdown") ||
                stoppageType.lowercased().contains("field goal")),
               let team = teamAssets.team(for: possession) {
                return team.primaryColor
            }
            return .orange
        }()
        
        HStack(spacing: 8) {
            if let possession = situation.possession,
               (stoppageType.lowercased().contains("touchdown") ||
                stoppageType.lowercased().contains("field goal")),
               let logo = teamAssets.logo(for: possession) {
                logo
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                    .clipShape(Circle())
            }
            
            Text(stoppageType == "Official Timeout" ? "Commercial Break" : stoppageType)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            LinearGradient(
                colors: stoppageType == "HALFTIME" ?
                    [Color.gpYellow.opacity(0.85), Color.gpYellow.opacity(0.6)] :
                    stoppageType == "Official Timeout" ?
                    [Color.gpOrange.opacity(0.85), Color.gpOrange.opacity(0.6)] :
                    stoppageType == "Two-Minute Warning" ?
                    [Color.gpPink.opacity(0.85), Color.gpPink.opacity(0.6)] :
                    [teamColor.opacity(0.85), teamColor.opacity(0.6)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(8)
    }
    
    private func stoppageLabel(text: String, colors: [Color], textColor: Color) -> some View {
        Text(text)
            .font(.caption)
            .fontWeight(.bold)
            .foregroundStyle(textColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                LinearGradient(
                    colors: colors,
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(8)
    }
    
    private var currentQuarter: Int {
        if case .inProgress(let quarterStr, _) = game.status {
            let q = quarterStr
                .replacingOccurrences(of: "Q", with: "")
                .replacingOccurrences(of: "ST", with: "")
                .replacingOccurrences(of: "ND", with: "")
                .replacingOccurrences(of: "RD", with: "")
                .replacingOccurrences(of: "TH", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let intQ = Int(q.prefix(1)), intQ >= 1, intQ <= 4 { return intQ }
        }
        return 1
    }
    
    private var clockInfo: String {
        if case .inProgress(let quarter, let time) = game.status {
            return "\(quarter) \(time)"
        }
        return ""
    }
    
    private var isTimeout: Bool {
        situation.lastPlay?.lowercased().contains("timeout") ?? false
    }
    
    private var isTwoMinuteWarning: Bool {
        situation.lastPlay?.lowercased().contains("two-minute warning") ?? false
    }
    
    private var isHalftime: Bool {
        (situation.lastPlay?.lowercased().contains("end quarter 2") ?? false) ||
        (situation.lastPlay?.lowercased().contains("end of quarter 2") ?? false)
    }
    
    private var isEndOfQuarter1: Bool {
        (situation.lastPlay?.lowercased().contains("end quarter 1") ?? false) ||
        (situation.lastPlay?.lowercased().contains("end of quarter 1") ?? false)
    }
    
    private var isEndOfQuarter3: Bool {
        (situation.lastPlay?.lowercased().contains("end quarter 3") ?? false) ||
        (situation.lastPlay?.lowercased().contains("end of quarter 3") ?? false)
    }
    
    private var isStoppage: Bool {
        isTimeout || isTwoMinuteWarning || isHalftime
    }
    
    private var stoppageType: String {
        if let lastPlay = situation.lastPlay?.lowercased() {
            if lastPlay.contains("end quarter 2") || lastPlay.contains("end of quarter 2") { return "HALFTIME" }
            if lastPlay.contains("end quarter 1") || lastPlay.contains("end of quarter 1") { return "End of Quarter 1" }
            if lastPlay.contains("end quarter 3") || lastPlay.contains("end of quarter 3") { return "End of Quarter 3" }
            if lastPlay.contains("timeout") { return "Official Timeout" }
            if lastPlay.contains("touchdown") { return "Touchdown - Awaiting Kickoff" }
            if lastPlay.contains("field goal") { return "Field Goal - Awaiting Kickoff" }
            if lastPlay.contains("penalty") { return "Penalty" }
            if lastPlay.contains("two-minute warning") { return "Two-Minute Warning" }
            if lastPlay.contains("end of") { return "End of Quarter" }
        }
        return "Between Plays"
    }
}