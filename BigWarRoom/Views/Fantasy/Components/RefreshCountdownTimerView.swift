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
    
    // MARK: - Computed Properties
    
    /// Color progression for the timer based on remaining time
    private var timerColor: Color {
        let progress = timeRemaining / TimeInterval(AppConstants.MatchupRefresh)
        
        if progress > 0.66 {
            return .gpGreen
        } else if progress > 0.33 {
            return .orange
        } else {
            return .gpRedPink
        }
    }
    
    /// Progress value for the circular progress indicator
    private var timerProgress: Double {
        let progress = timeRemaining / TimeInterval(AppConstants.MatchupRefresh)
        return progress // Full progress (1.0 = full circle, 0.0 = empty)
    }
    
    // MARK: - Body
    
    var body: some View {
        // 🔥 EXACT SAME TIMER as Live Players
        ZStack {
            // 🔥 External glow layers (multiple for depth)
            ForEach(0..<3) { index in
                Circle()
                    .fill(timerColor.opacity(0.15 - Double(index) * 0.05))
                    .frame(width: 45 + CGFloat(index * 8), height: 45 + CGFloat(index * 8))
                    .blur(radius: CGFloat(4 + index * 3))
                    .animation(.easeInOut(duration: 0.8), value: timerColor)
                    .scaleEffect(timeRemaining < 3 ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: timeRemaining < 3)
            }
            
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 2.5)
                    .frame(width: 32, height: 32)
                
                // 🔥 Circular sweep progress
                Circle()
                    .trim(from: 0, to: timerProgress)
                    .stroke(
                        AngularGradient(
                            colors: [timerColor, timerColor.opacity(0.6), timerColor],
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                    )
                    .frame(width: 32, height: 32)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: timerProgress)
                
                // Center fill
                Circle()
                    .fill(timerColor.opacity(0.15))
                    .frame(width: 27, height: 27)
                    .animation(.easeInOut(duration: 0.3), value: timerColor)
                
                // 🔥 Timer text with swipe animation
                ZStack {
                    Text("\(Int(timeRemaining))")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: timerColor.opacity(0.8), radius: 2, x: 0, y: 1)
                        .scaleEffect(timeRemaining < 3 ? 1.1 : 1.0)
                        .id("mission-timer-\(Int(timeRemaining))") // 🔥 Unique ID for transition
                        .transition(
                            .asymmetric(
                                insertion: AnyTransition.move(edge: .leading)
                                    .combined(with: .scale(scale: 0.8))
                                    .combined(with: .opacity),
                                removal: AnyTransition.move(edge: .trailing)
                                    .combined(with: .scale(scale: 1.2))
                                    .combined(with: .opacity)
                            )
                        )
                }
                .frame(width: 24, height: 24) // Fixed frame to prevent layout shifts
                .clipped()
                .animation(.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0.1), value: Int(timeRemaining))
            }
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