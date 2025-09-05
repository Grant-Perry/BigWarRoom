//
//  MatchupsHubLoadingIndicator.swift
//  BigWarRoom
//
//  Enhanced loading indicator for the Matchups Hub with league names
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
            heroLoadingAnimation
            
            // League progress section
            leagueProgressSection
            
            // Overall progress
            overallProgressBar
        }
        .padding(.horizontal, 24)
        .onAppear {
            startAnimations()
        }
    }
    
    private var heroLoadingAnimation: some View {
        ZStack {
            // Animated gradient rings
            ForEach(0..<4) { index in
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [.gpGreen.opacity(0.6), .blue.opacity(0.4), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: CGFloat(3 - index)
                    )
                    .frame(width: CGFloat(100 + index * 25))
                    .rotationEffect(.degrees(rotation + Double(index * 45)))
                    .opacity(opacity - Double(index) * 0.15)
            }
            
            // Central football with glow
            ZStack {
                // Glow effect
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.gpGreen.opacity(0.8), .clear],
                            center: .center,
                            startRadius: 5,
                            endRadius: 40
                        )
                    )
                    .frame(width: 80, height: 80)
                    .scaleEffect(pulseScale)
                
                // Football background
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.brown.opacity(0.9), Color.brown.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                    .scaleEffect(scale)
                
                // Football icon
                Image(systemName: "football.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(rotation * 0.5))
            }
        }
    }
    
    private var leagueProgressSection: some View {
        VStack(spacing: 16) {
            // Current loading message
            VStack(spacing: 8) {
                Text("MISSION CONTROL")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.gpGreen, .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text(currentLeague)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .animation(.easeInOut(duration: 0.3), value: currentLeague)
            }
            
            // League loading states
            if !loadingStates.isEmpty {
                LazyVStack(spacing: 8) {
                    ForEach(Array(loadingStates.keys.sorted()), id: \.self) { leagueID in
                        if let state = loadingStates[leagueID] {
                            LeagueLoadingRow(state: state)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    private var overallProgressBar: some View {
        VStack(spacing: 12) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 12)
                    
                    // Progress fill with gradient
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [.gpGreen, .blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * max(0.05, progress), height: 12)
                        .animation(.easeInOut(duration: 0.5), value: progress)
                    
                    // Shimmer effect
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [.clear, .white.opacity(0.6), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 12)
                        .offset(x: -geometry.size.width + (geometry.size.width * 2 * progress))
                        .animation(
                            .linear(duration: 2.0).repeatForever(autoreverses: false),
                            value: progress
                        )
                }
            }
            .frame(height: 12)
            
            // Progress text
            HStack {
                Text("Loading your fantasy empire...")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
                
                Spacer()
                
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.gpGreen)
                    .animation(.easeInOut(duration: 0.3), value: progress)
            }
        }
        .frame(maxWidth: 300)
    }
    
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
                                
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(state.status.color)
                                    .frame(width: geometry.size.width * state.progress, height: 4)
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