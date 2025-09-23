//
//  MatchupsHubLoadingIndicator.swift
//  BigWarRoom
//
//  Enhanced loading indicator for the Matchups Hub with league names - CLEAN ARCHITECTURE
//

import SwiftUI

struct MatchupsHubLoadingIndicator: View {
    @State private var rotation: Double = 0
    @State private var scale: Double = 1.0
    @State private var opacity: Double = 0.8
    @State private var pulseScale: Double = 1.0
    
    let currentLeague: String
    let progress: Double
    let loadingStates: [String: LeagueLoadingState]
    
    var body: some View {
        VStack(spacing: 32) {
            // Hero loading animation
            buildHeroLoadingAnimation()
            
            // League progress section
            buildLeagueProgressSection()
            
            // Overall progress
            buildOverallProgressBar()
        }
        .padding(.horizontal, 24)
        .onAppear {
            startAnimations()
        }
    }
    
    // MARK: - Builder Functions (NO COMPUTED VIEW PROPERTIES)
    
    func buildHeroLoadingAnimation() -> some View {
        MatchupsHubLoadingHeroAnimationView(
            rotation: rotation,
            scale: scale,
            opacity: opacity,
            pulseScale: pulseScale
        )
    }
    
    func buildLeagueProgressSection() -> some View {
        MatchupsHubLoadingProgressSectionView(
            currentLeague: currentLeague,
            loadingStates: loadingStates
        )
    }
    
    func buildOverallProgressBar() -> some View {
        MatchupsHubLoadingProgressBarView(progress: progress)
    }
    
    // MARK: - Animation Logic
    
    private func startAnimations() {
        // Continuous rotation
        withAnimation(.linear(duration: 8.0).repeatForever(autoreverses: false)) {
            rotation = 360
        }
        
        // Pulse animation
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            pulseScale = 1.3
            opacity = 1.0
        }
        
        // Scale breathing
        withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
            scale = 1.15
        }
    }
}

// MARK: -> Individual League Loading Row
struct LeagueLoadingRow: View {
    let state: LeagueLoadingState
    @State private var shimmerOffset: CGFloat = -1
    
    var body: some View {
        HStack(spacing: 12) {
            // Status icon
            Text(state.status.emoji)
                .font(.system(size: 16))
                .frame(width: 20)
                .animation(.easeInOut(duration: 0.3), value: state.status)
            
            // League name
            Text(state.name)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
            
            Spacer()
            
            // Progress indicator
            Group {
                switch state.status {
                case .pending:
                    Text("Waiting...")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                
                case .loading:
                    HStack(spacing: 8) {
                        // Mini progress bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(height: 4)

                                // Gradient fill!
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(
                                        LinearGradient(
                                            colors: [.gpGreen, .blue, .purple],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: max(2, geometry.size.width * state.progress), height: 4)
                                    .animation(.easeInOut(duration: 0.3), value: state.progress)
                            }
                        }
                        .frame(width: 40, height: 4)
                        
                        Text("\(Int(state.progress * 100))%")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(state.status.color)
                    }
                
                case .completed:
                    Text("Loaded")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(state.status.color)
                
                case .failed:
                    Text("Failed")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(state.status.color)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: state.status)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(state.status.color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: -> Preview
#Preview {
    MatchupsHubLoadingIndicator(
        currentLeague: "Loading ESPN Fantasy League...",
        progress: 0.65,
        loadingStates: [
            "espn_1": LeagueLoadingState(name: "ESPN Fantasy", status: .completed, progress: 1.0),
            "sleeper_1": LeagueLoadingState(name: "Sleeper Dynasty", status: .loading, progress: 0.7),
            "sleeper_2": LeagueLoadingState(name: "Chopped League", status: .pending, progress: 0.0)
        ]
    )
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.black)
}