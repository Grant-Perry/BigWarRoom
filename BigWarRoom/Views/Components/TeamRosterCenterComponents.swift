//
//  TeamRosterCenterComponents.swift
//  BigWarRoom
//
//  Center circle coordinator view + ring-only gesture overlay.
//

import SwiftUI
import UIKit

// MARK: - Center Circle Coordinator View

struct CenterCircleCoordinatorView: View {
    let size: CGFloat
    let displayTeamCode: String
    let gameInfo: GameDisplayInfo?
    let onTeamTap: (String) -> Void
    
    private var teamColor: Color {
        TeamAssetManager.shared.team(for: displayTeamCode)?.primaryColor ?? .white
    }
    
    var body: some View {
        ZStack {
            // Outer glow ring
            Circle()
                .stroke(teamColor, lineWidth: 2)
                .frame(width: size + 16, height: size + 16)
                .shadow(color: teamColor.opacity(0.8), radius: 25)
                .shadow(color: teamColor.opacity(0.6), radius: 35)
                .shadow(color: teamColor.opacity(0.4), radius: 45)
            
            // Main circle background
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.8),
                            Color.black.opacity(0.6),
                            teamColor.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
            
            // Massive logo
            TeamLogoView(teamCode: displayTeamCode, size: size * 1.4)
                .scaleEffect(1.1)
                .opacity(0.25)
                .clipShape(Circle())
                .frame(width: size, height: size)
            
            VStack(spacing: 20) {
                Spacer()
                
                // Mini schedule card: either BYE/LOADING or actual
                centerMiniCard
                
                Text("Tap either team's logo\nto view their full live roster")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .shadow(color: .black.opacity(0.8), radius: 4, x: 0, y: 2)
                    .padding(.top, 4)
                
                Spacer()
            }
            .frame(width: size, height: size)
        }
        .accessibilityIdentifier("CenterCircleCoordinatorView")
    }
    
    @ViewBuilder
    private var centerMiniCard: some View {
        if let info = gameInfo {
            if info.isByeWeek {
                MiniScheduleCard(
                    awayTeam: displayTeamCode,
                    homeTeam: "",
                    awayScore: 0,
                    homeScore: 0,
                    gameStatus: "BYE",
                    gameTime: "",
                    isLive: false,
                    isByeWeek: true,
                    onTeamTap: { _ in }
                )
            } else {
                MiniScheduleCard(
                    awayTeam: info.actualAwayTeam,
                    homeTeam: info.actualHomeTeam,
                    awayScore: info.actualAwayScore,
                    homeScore: info.actualHomeScore,
                    gameStatus: info.isLive ? "LIVE" : (info.hasStarted ? "FINAL" : "PRE"),
                    gameTime: info.gameTime,
                    isLive: info.isLive,
                    isByeWeek: false,
                    onTeamTap: { tapped in onTeamTap(tapped) }
                )
            }
        } else {
            MiniScheduleCard(
                awayTeam: displayTeamCode,
                homeTeam: "TBD",
                awayScore: 0,
                homeScore: 0,
                gameStatus: "LOADING",
                gameTime: "",
                isLive: false,
                isByeWeek: false,
                onTeamTap: { _ in }
            )
        }
    }
}

// MARK: - Ring Gesture Overlay (UIKit hit-testing)

struct RingGestureOverlay: UIViewRepresentable {
    let innerRadius: CGFloat
    let outerRadius: CGFloat
    let onChanged: (CGPoint) -> Void
    let onEnded: (CGPoint) -> Void
    
    func makeUIView(context: Context) -> RingHitTestControl {
        let view = RingHitTestControl()
        view.isOpaque = false
        view.backgroundColor = .clear
        view.innerRadius = innerRadius
        view.outerRadius = outerRadius
        view.onChanged = onChanged
        view.onEnded = onEnded
        
        let pan = UIPanGestureRecognizer(target: view, action: #selector(RingHitTestControl.handlePan(_:)))
        pan.minimumNumberOfTouches = 1
        pan.maximumNumberOfTouches = 1
        view.addGestureRecognizer(pan)
        return view
    }
    
    func updateUIView(_ uiView: RingHitTestControl, context: Context) {
        uiView.innerRadius = innerRadius
        uiView.outerRadius = outerRadius
        uiView.onChanged = onChanged
        uiView.onEnded = onEnded
        uiView.setNeedsDisplay()
    }
}

final class RingHitTestControl: UIControl {
    var innerRadius: CGFloat = 0
    var outerRadius: CGFloat = 0
    var onChanged: ((CGPoint) -> Void)?
    var onEnded: ((CGPoint) -> Void)?
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let dx = point.x - center.x
        let dy = point.y - center.y
        let distance = sqrt(dx*dx + dy*dy)
        return distance >= innerRadius && distance <= outerRadius
    }
    
    @objc func handlePan(_ recognizer: UIPanGestureRecognizer) {
        let point = recognizer.location(in: self)
        switch recognizer.state {
        case .began, .changed:
            onChanged?(point)
        case .ended, .cancelled, .failed:
            onEnded?(point)
        default:
            break
        }
    }
}