//
//  TeamRostersView.swift
//  BigWarRoom
//
//  🏈 TEAM ROSTERS - Clock-style team selection with full NFL team rosters
//

import SwiftUI

struct TeamRostersView: View {
    @State private var viewModel = TeamRostersViewModel()
    @State private var nflGameService = NFLGameDataService.shared
    @State private var weekManager = WeekSelectionManager.shared
    @State private var selectedTeam: String = "SF"
    @State private var hoveredTeam: String? = nil
    @State private var showingWeekPicker = false
    @State private var navigationPath = NavigationPath()
    
    private let nflTeams = [
        "ARI", "ATL", "BAL", "BUF", "CAR", "CHI", "CIN", "CLE",
        "DAL", "DEN", "DET", "GB", "HOU", "IND", "JAX", "KC",
        "LV", "LAC", "LAR", "MIA", "MIN", "NE", "NO", "NYG",
        "NYJ", "PHI", "PIT", "SEA", "SF", "TB", "TEN", "WSH"
    ]
    
    var body: some View {
        // 🔥 PROPER NAVIGATION: Use NavigationStack with path for programmatic navigation
        NavigationStack(path: $navigationPath) {
            ZStack {
                Image("BG2")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .opacity(0.3)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    headerSection
                        .padding(.top, 10)
                        .padding(.bottom, 20)
                    
                    // 🔥 NEW: Week header with picker
                    weekHeaderSection
                        .padding(.bottom, 16)
                    
                    clockInterface
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, -30)
                    
                    Spacer()
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingWeekPicker) {
                WeekPickerView(
                    weekManager: weekManager,
                    isPresented: $showingWeekPicker
                )
            }
            // 🔥 ADD: Proper hierarchical navigation destination for team rosters
            .navigationDestination(for: String.self) { teamCode in
                EnhancedNFLTeamRosterView(teamCode: teamCode)
            }
            // 🔥 ADD: Navigation destination for player stats using SleeperPlayer directly
            .navigationDestination(for: SleeperPlayer.self) { player in
                PlayerStatsCardView(
                    player: player,
                    team: NFLTeam.team(for: player.team ?? "")
                )
            }
            .onChange(of: weekManager.selectedWeek) { _, _ in
                // 🔥 NEW: Refresh NFL game data when week changes
                nflGameService.fetchGameData(forWeek: weekManager.selectedWeek, forceRefresh: true)
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("TEAM ROSTERS")
                .font(.system(size: 36, weight: .bold, design: .default))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 4)
            
            Text("Select any NFL team to view their complete active roster")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 2)
        }
        .padding(.horizontal, 20)
    }
    
    // 🔥 NEW: Week header section - using reusable TheWeekPicker
    private var weekHeaderSection: some View {
        HStack {
            Spacer()
            TheWeekPicker(showingWeekPicker: $showingWeekPicker)
            Spacer()
        }
        .padding(.horizontal, 20)
    }
    
    private var clockInterface: some View {
        GeometryReader { geometry in
            let availableSize = min(geometry.size.width, geometry.size.height)
            let teamSize: CGFloat = 58
            let maxScale: CGFloat = 1.3
            let expandedTeamSize = teamSize * maxScale
            let clockRadius = (availableSize / 2) - expandedTeamSize / 2 - 20
            let centerSize = clockRadius * 1.6
            let displayTeam = hoveredTeam ?? selectedTeam
            
            ZStack {
                CenterCircleCoordinatorView(
                    size: centerSize,
                    displayTeamCode: displayTeam,
                    gameInfo: getGameInfo(for: displayTeam),
                    onTeamTap: { teamCode in
                        navigationPath.append(teamCode)
                    }
                )
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                .zIndex(200)
                
                ForEach(Array(nflTeams.enumerated()), id: \.offset) { index, team in
                    let angle = Double(index) * (360.0 / Double(nflTeams.count)) - 90.0
                    let radian = angle * .pi / 180.0
                    let x = geometry.size.width / 2 + clockRadius * cos(radian)
                    let y = geometry.size.height / 2 + clockRadius * sin(radian)
                    
                    teamCircleVisual(team: team, size: teamSize, isSelected: team == selectedTeam)
                        .scaleEffect(getSickScaleForTeam(team))
                        .rotationEffect(.degrees(getRotationForTeam(team)))
                        .shadow(
                            color: getShadowColorForTeam(team),
                            radius: getShadowRadiusForTeam(team),
                            x: 0, y: 2
                        )
                        .animation(.interpolatingSpring(stiffness: 350, damping: 25), value: selectedTeam)
                        .animation(.interpolatingSpring(stiffness: 400, damping: 20), value: hoveredTeam)
                        .allowsHitTesting(false)
                        .position(x: x, y: y)
                        .zIndex(team == selectedTeam ? 10 : (team == hoveredTeam ? 5 : 0))
                }
                
                RingGestureOverlay(
                    innerRadius: centerSize / 2,
                    outerRadius: clockRadius + (teamSize + 20) / 2,
                    onChanged: { point in
                        if let team = findTeamAtPoint(
                            point: pointInGeometrySpace(point, in: geometry),
                            geometry: geometry,
                            clockRadius: clockRadius,
                            teamSize: teamSize + 20
                        ) {
                            if hoveredTeam != team {
                                let fb = UISelectionFeedbackGenerator()
                                fb.selectionChanged()
                                withAnimation(.interpolatingSpring(stiffness: 400, damping: 25)) {
                                    hoveredTeam = team
                                }
                            }
                        } else if hoveredTeam != nil {
                            withAnimation(.interpolatingSpring(stiffness: 350, damping: 30)) {
                                hoveredTeam = nil
                            }
                        }
                    },
                    onEnded: { point in
                        if let team = findTeamAtPoint(
                            point: pointInGeometrySpace(point, in: geometry),
                            geometry: geometry,
                            clockRadius: clockRadius,
                            teamSize: teamSize + 20
                        ) {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                                selectedTeam = team
                            }
                            // Team roster navigation will be handled by NavigationLink logic
                        }
                        withAnimation(.interpolatingSpring(stiffness: 350, damping: 30)) {
                            hoveredTeam = nil
                        }
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(true)
                .zIndex(50)
            }
        }
        .padding(10)
    }
    
    private func findTeamAtPoint(point: CGPoint, geometry: GeometryProxy, clockRadius: CGFloat, teamSize: CGFloat) -> String? {
        let centerX = geometry.size.width / 2
        let centerY = geometry.size.height / 2
        
        for (index, team) in nflTeams.enumerated() {
            let angle = Double(index) * (360.0 / Double(nflTeams.count)) - 90.0
            let radian = angle * .pi / 180.0
            let teamX = centerX + clockRadius * cos(radian)
            let teamY = centerY + clockRadius * sin(radian)
            let distance = sqrt(pow(point.x - teamX, 2) + pow(point.y - teamY, 2))
            let hitRadius = teamSize / 2
            if distance <= hitRadius { return team }
        }
        return nil
    }
    
    private func getSickScaleForTeam(_ team: String) -> CGFloat {
        if team == selectedTeam { return 1.3 }
        else if team == hoveredTeam { return 1.25 }
        else { return 1.0 }
    }
    
    private func getRotationForTeam(_ team: String) -> Double {
        if team == selectedTeam { return 2.0 }
        else if team == hoveredTeam { return 1.0 }
        else { return 0.0 }
    }
    
    private func getShadowColorForTeam(_ team: String) -> Color {
        if team == selectedTeam { return getTeamColor(for: team).opacity(0.8) }
        else if team == hoveredTeam { return getTeamColor(for: team).opacity(0.5) }
        else { return Color.clear }
    }
    
    private func getShadowRadiusForTeam(_ team: String) -> CGFloat {
        if team == selectedTeam { return 16 }
        else if team == hoveredTeam { return 10 }
        else { return 0 }
    }
    
    private func teamCircleVisual(team: String, size: CGFloat, isSelected: Bool) -> some View {
        ZStack {
            if isSelected {
                Circle()
                    .stroke(getTeamColor(for: team).opacity(0.4), lineWidth: 5)
                    .frame(width: size + 12, height: size + 12)
                    .scaleEffect(1.1)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isSelected)
            }
            
            if isSelected {
                Circle()
                    .stroke(getTeamColor(for: team), lineWidth: 4)
                    .frame(width: size + 6, height: size + 6)
            }
            
            if team == hoveredTeam && team != selectedTeam {
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.8),
                                getTeamColor(for: team).opacity(0.6),
                                Color.white.opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: size + 4, height: size + 4)
            }
            
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            getTeamColor(for: team).opacity(team == selectedTeam ? 0.4 : 0.2),
                            Color.black.opacity(0.8),
                            getTeamColor(for: team).opacity(0.1)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size / 2
                    )
                )
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(team == hoveredTeam ? 0.3 : 0.15), lineWidth: 0.5)
                )
            
            TeamLogoView(teamCode: team, size: getSickLogoSize(team: team, baseSize: size))
                .scaleEffect(team == selectedTeam ? 1.05 : 1.0)
                .animation(
                    team == selectedTeam ?
                    .easeInOut(duration: 2.0).repeatForever(autoreverses: true) :
                    .spring(response: 0.4, dampingFraction: 0.7),
                    value: selectedTeam
                )
        }
    }
    
    private func getSickLogoSize(team: String, baseSize: CGFloat) -> CGFloat {
        let baseLogo = baseSize * 0.55
        if team == selectedTeam { return baseSize * 0.85 }
        else if team == hoveredTeam { return baseSize * 0.75 }
        else { return baseLogo }
    }
    
    private func getTeamColor(for teamCode: String) -> Color {
        return TeamAssetManager.shared.team(for: teamCode)?.primaryColor ?? Color.white
    }
    
    private func getTeamName(for teamCode: String) -> String {
        return NFLTeam.team(for: teamCode)?.city ?? teamCode
    }
    
    private func getGameInfo(for teamCode: String) -> GameDisplayInfo? {
        if let gameInfo = nflGameService.getGameInfo(for: teamCode) {
            let isWinning = isTeamWinning(teamCode, gameInfo: gameInfo)
            let teamScore: String
            let opponentScore: String
            let opponent = getOpponentTeam(teamCode, gameInfo: gameInfo)
            
            if teamCode == gameInfo.awayTeam {
                teamScore = "\(gameInfo.awayScore)"
                opponentScore = "\(gameInfo.homeScore)"
            } else {
                teamScore = "\(gameInfo.homeScore)"
                opponentScore = "\(gameInfo.awayScore)"
            }
            
            return GameDisplayInfo(
                opponent: opponent,
                scoreDisplay: "\(gameInfo.awayScore) - \(gameInfo.homeScore)",
                teamScore: teamScore,
                opponentScore: opponentScore,
                gameTime: gameInfo.displayTime,
                isLive: gameInfo.isLive,
                hasStarted: gameInfo.awayScore > 0 || gameInfo.homeScore > 0,
                isWinning: isWinning,
                isLosing: !isWinning && (gameInfo.awayScore > 0 || gameInfo.homeScore > 0),
                isByeWeek: false,
                isHome: teamCode == gameInfo.homeTeam,
                actualAwayTeam: gameInfo.awayTeam,
                actualHomeTeam: gameInfo.homeTeam,
                actualAwayScore: gameInfo.awayScore,
                actualHomeScore: gameInfo.homeScore
            )
        } else {
            return GameDisplayInfo(
                opponent: "",
                scoreDisplay: "",
                teamScore: "",
                opponentScore: "",
                gameTime: "",
                isLive: false,
                hasStarted: false,
                isWinning: false,
                isLosing: false,
                isByeWeek: true,
                isHome: false,
                actualAwayTeam: "",
                actualHomeTeam: "",
                actualAwayScore: 0,
                actualHomeScore: 0
            )
        }
    }
    
    private func getOpponentTeam(_ teamCode: String, gameInfo: NFLGameInfo) -> String {
        return teamCode == gameInfo.awayTeam ? gameInfo.homeTeam : gameInfo.awayTeam
    }
    
    private func isTeamWinning(_ teamCode: String, gameInfo: NFLGameInfo) -> Bool {
        if teamCode == gameInfo.awayTeam {
            return gameInfo.awayScore > gameInfo.homeScore
        } else {
            return gameInfo.homeScore > gameInfo.awayScore
        }
    }
    
    private func isTeamLosing(_ teamCode: String, gameInfo: NFLGameInfo) -> Bool {
        if teamCode == gameInfo.awayTeam {
            return gameInfo.awayScore < gameInfo.homeScore
        } else {
            return gameInfo.homeScore < gameInfo.awayScore
        }
    }
}

struct MiniScheduleCard: View {
    let awayTeam: String
    let homeTeam: String
    let awayScore: Int
    let homeScore: Int
    let gameStatus: String
    let gameTime: String
    let isLive: Bool
    let isByeWeek: Bool
    let onTeamTap: (String) -> Void
    
    @State private var teamAssets = TeamAssetManager.shared
    @State private var standingsService = NFLStandingsService.shared
    
    var body: some View {
        if isByeWeek {
            ZStack {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.blue.opacity(0.8),
                                Color.blue.opacity(0.6),
                                Color.marlinsPrimary.opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 240, height: 60)
                
                Text("BYE WEEK")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.blue, lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
        } else if gameStatus == "LOADING" {
            ZStack {
                Rectangle()
                    .fill(Color.black.opacity(0.6))
                    .frame(width: 240, height: 60)
                
                Text("Loading...")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
        } else {
            HStack(spacing: 0) {
                HStack(spacing: 0) {
                    Button(action: { onTeamTap(awayTeam) }) {
                        ZStack {
                            TeamLogoView(teamCode: awayTeam, size: 70)
                                .scaleEffect(1.05)
                                .clipped()
                                .shadow(color: .black.opacity(0.6), radius: 4, x: 1, y: 2)
                        }
                        .frame(width: 55, height: 60)
                        .clipShape(Rectangle())
                        .overlay(
                            Rectangle()
                                .stroke(getTeamColor(for: awayTeam), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .allowsHitTesting(true)
                    .zIndex(30000)
                    
                    Rectangle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 15, height: 60)
                        .overlay(
                            Text(getTeamRecord(for: awayTeam))
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .kerning(1.2)
                                .rotationEffect(.degrees(90))
                                .fixedSize()
                        )
                }
                
                Spacer()
                
                VStack(spacing: 1) {
                    if isLive {
                        VStack(spacing: 0) {
                            Text("\(awayScore) - \(homeScore)")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                            
                            Text("LIVE")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(Color.red.opacity(0.8))
                                )
                        }
                    } else if gameStatus == "FINAL" || awayScore > 0 || homeScore > 0 {
                        VStack(spacing: 0) {
                            HStack(spacing: 4) {
                                Text("\(awayScore)")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundColor(awayScore > homeScore ? .gpGreen : .white)
                                    .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                                
                                Text("-")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                                
                                Text("\(homeScore)")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundColor(homeScore > awayScore ? .gpGreen : .white)
                                    .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                            }
                            
                            Text("FINAL")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    } else {
                        VStack(spacing: 0) {
                            if let dayName = getDayName() {
                                Text(dayName)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                    .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                            }
                            
                            Text(formatGameTime())
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                        }
                    }
                }
                
                Spacer()
                
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 15, height: 60)
                        .overlay(
                            Text(getTeamRecord(for: homeTeam))
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .kerning(1.2)
                                .rotationEffect(.degrees(90))
                                .fixedSize()
                        )
                    
                    Button(action: { onTeamTap(homeTeam) }) {
                        ZStack {
                            TeamLogoView(teamCode: homeTeam, size: 70)
                                .scaleEffect(1.05)
                                .clipped()
                                .shadow(color: .black.opacity(0.6), radius: 4, x: -1, y: 2)
                        }
                        .frame(width: 55, height: 60)
                        .clipShape(Rectangle())
                        .overlay(
                            Rectangle()
                                .stroke(getTeamColor(for: homeTeam), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .allowsHitTesting(true)
                    .zIndex(30000)
                }
            }
            .frame(width: 240, height: 60)
            .background(
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                getTeamColor(for: awayTeam).opacity(0.7),
                                getTeamColor(for: awayTeam).opacity(0.5),
                                getTeamColor(for: homeTeam).opacity(0.5),
                                getTeamColor(for: homeTeam).opacity(0.7)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .overlay(
                Rectangle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                getTeamColor(for: awayTeam),
                                getTeamColor(for: homeTeam)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 2
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
        }
    }
    
    private func getTeamColor(for teamCode: String) -> Color {
        return teamAssets.team(for: teamCode)?.primaryColor ?? Color.white
    }
    
    private func getTeamRecord(for teamCode: String) -> String {
        return standingsService.getTeamRecord(for: teamCode)
    }
    
    private func getDayName() -> String? {
        return nil
    }
    
    private func formatGameTime() -> String {
        return gameTime.isEmpty ? "TBD" : gameTime
    }
}

private func pointInGeometrySpace(_ point: CGPoint, in geometry: GeometryProxy) -> CGPoint {
    return point
}

private func isTouchInCenterArea(point: CGPoint, geometry: GeometryProxy, centerSize: CGFloat) -> Bool {
    let centerX = geometry.size.width / 2
    let centerY = geometry.size.height / 2
    let distance = sqrt(pow(point.x - centerX, 2) + pow(point.y - centerY, 2))
    let centerRadius = centerSize / 2
    return distance <= centerRadius
}

// MARK: - SleeperPlayer Hashable Conformance
extension SleeperPlayer: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(playerID)
    }
    
    static func == (lhs: SleeperPlayer, rhs: SleeperPlayer) -> Bool {
        return lhs.playerID == rhs.playerID
    }
}

#Preview("Team Rosters") {
    TeamRostersView()
        .preferredColorScheme(.dark)
}