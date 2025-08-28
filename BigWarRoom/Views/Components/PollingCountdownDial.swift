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
        return max(0, min(1, (maxInterval - countdown) / maxInterval))
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
                // Background circle
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 3)
                    .frame(width: 36, height: 36)
                
                // Progress circle
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        isPolling ? Color.blue : Color.gray,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 36, height: 36)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.1), value: progress)
                
                // Center text
                Text(countdownText)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(isPolling ? .blue : .gray)
                
                // Pulse effect when pressed
                if isPressed {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
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
            countdown: 2.3,
            maxInterval: 5.0,
            isPolling: true,
            onRefresh: {}
        )
        
        PollingCountdownDial(
            countdown: 0.0,
            maxInterval: 5.0,
            isPolling: true,
            onRefresh: {}
        )
        
        PollingCountdownDial(
            countdown: 15.0,
            maxInterval: 15.0,
            isPolling: false,
            onRefresh: {}
        )
    }
    .padding()
}