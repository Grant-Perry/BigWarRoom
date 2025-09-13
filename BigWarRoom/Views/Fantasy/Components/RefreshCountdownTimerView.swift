//
//  RefreshCountdownTimerView.swift
//  BigWarRoom
//
//  Circular countdown timer for fantasy matchup refreshes
//

import SwiftUI

/// Circular countdown timer with color-coded progress indicator
struct RefreshCountdownTimerView: View {
    @State private var timeRemaining: TimeInterval = TimeInterval(AppConstants.MatchupRefresh)
    @State private var timer: Timer?
    @State private var glowIntensity: Double = 0.3
    
    // MARK: - Computed Properties
    
    /// Color progression for the timer based on remaining time
    private var timerColor: Color {
        let progress = timeRemaining / TimeInterval(AppConstants.MatchupRefresh)
        
        if progress > 0.66 {
            return .green
        } else if progress > 0.33 {
            return .orange
        } else {
            return .red
        }
    }
    
    /// Progress value for the circular progress indicator
    private var progress: Double {
        return timeRemaining / TimeInterval(AppConstants.MatchupRefresh)
    }
    
    /// Dynamic glow opacity that intensifies as time runs out
    private var dynamicGlowOpacity: Double {
        let baseIntensity = glowIntensity
        let urgencyMultiplier = 1.0 + (1.0 - progress) * 2.0 // 1x to 3x intensity
        return baseIntensity * urgencyMultiplier
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Subtle glow background layers
            ForEach(0..<2) { index in
                Circle()
                    .fill(timerColor.opacity(0.1))
                    .frame(width: 42 + CGFloat(index * 6), height: 42 + CGFloat(index * 6))
                    .blur(radius: CGFloat(2 + index * 2))
                    .opacity(0.3 * (1.0 - Double(index) * 0.3))
                    .animation(.easeInOut(duration: 0.5), value: timerColor)
            }
            
            // Background circle
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 2.5)
                .frame(width: 38, height: 38)
            
            // Center fill that matches the rotating circle color
            Circle()
                .fill(timerColor.opacity(0.2))
                .frame(width: 33, height: 33)
                .animation(.easeInOut(duration: 0.3), value: timerColor)
            
            // Progress circle with color animation
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        colors: [timerColor, timerColor.opacity(0.6)],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                )
                .frame(width: 38, height: 38)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: progress)
            
            // Time remaining text
            Text(String(format: "%.0f", timeRemaining))
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(timerColor)
                .animation(.easeInOut(duration: 0.3), value: timerColor)
        }
        .onAppear {
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
    }
    
    // MARK: - Private Methods
    
    private func startTimer() {
        // Reset to full time when view appears
        timeRemaining = TimeInterval(AppConstants.MatchupRefresh)
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                // Reset timer when it reaches 0 (next refresh cycle)
                timeRemaining = TimeInterval(AppConstants.MatchupRefresh)
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}