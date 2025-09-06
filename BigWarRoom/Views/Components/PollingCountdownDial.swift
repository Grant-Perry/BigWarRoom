//
//  PollingCountdownDial.swift
//  BigWarRoom
//
//  Circular countdown dial for draft polling with manual refresh
//
// MARK: -> Polling Countdown Dial

import SwiftUI

struct PollingCountdownDial: View {
    let countdown: Double
    let maxInterval: Double
    let isPolling: Bool
    let onRefresh: () -> Void
    
    @State private var isPressed = false
    
    private var progress: Double {
        guard maxInterval > 0 else { return 0 }
        return max(0, min(1, countdown / maxInterval))
    }
    
    private var progressColor: Color {
        let ratio = progress
        if ratio > 0.66 {
            return .gpGreen
        } else if ratio > 0.33 {
            return .gpYellow
        } else {
            return .gpRedPink
        }
    }
    
    private var countdownText: String {
        if countdown <= 0 {
            return "•"
        } else if countdown < 10 {
            return String(format: "%.1f", countdown)
        } else {
            return "\(Int(countdown))"
        }
    }
    
    var body: some View {
        Button(action: {
            onRefresh()
        }) {
            ZStack {
                // Yellow shadow behind the dial
                Circle()
                    .stroke(Color.gpYellow.opacity(0.5), lineWidth: 3)
                    .frame(width: 36, height: 36)
                    .blur(radius: 2)
                
                // Background circle
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 3)
                    .frame(width: 36, height: 36)
                
                // Progress circle - starts at 12 and goes counter-clockwise with smooth sweeping
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        isPolling ? progressColor : Color.gray,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 36, height: 36)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1.0), value: progress)
                
                // Center text
                Text(countdownText)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(isPolling ? progressColor : .gray)
                
                // Pulse effect when pressed
                if isPressed {
                    Circle()
                        .fill(progressColor.opacity(0.2))
                        .frame(width: 36, height: 36)
                        .scaleEffect(1.2)
                        .animation(.easeOut(duration: 0.2), value: isPressed)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

#Preview {
    VStack(spacing: 20) {
        PollingCountdownDial(
            countdown: 12.0,
            maxInterval: 15.0,
            isPolling: true,
            onRefresh: {}
        )
        
        PollingCountdownDial(
            countdown: 5.0,
            maxInterval: 15.0,
            isPolling: true,
            onRefresh: {}
        )
        
        PollingCountdownDial(
            countdown: 1.0,
            maxInterval: 15.0,
            isPolling: true,
            onRefresh: {}
        )
    }
    .padding()
}