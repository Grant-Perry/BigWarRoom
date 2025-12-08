//
//  ProjectedScoreView.swift
//  BigWarRoom
//
//  🎯 DRY COMPONENT: Reusable projected score display
//  Shows projected score with winning/losing color
//

import SwiftUI

/// Reusable component to display projected scores
struct ProjectedScoreView: View {
    let myProjected: Double
    let opponentProjected: Double
    let alignment: HorizontalAlignment
    let size: DisplaySize
    
    enum DisplaySize {
        case small
        case medium
        case large
        
        var fontSize: CGFloat {
            switch self {
            case .small: return 12
            case .medium: return 14
            case .large: return 16
            }
        }
        
        var labelFontSize: CGFloat {
            switch self {
            case .small: return 9
            case .medium: return 10
            case .large: return 12
            }
        }
    }
    
    init(
        myProjected: Double,
        opponentProjected: Double,
        alignment: HorizontalAlignment = .center,
        size: DisplaySize = .medium
    ) {
        self.myProjected = myProjected
        self.opponentProjected = opponentProjected
        self.alignment = alignment
        self.size = size
    }
    
    var body: some View {
        VStack(alignment: alignment, spacing: 2) {
            Text("Projected")
                .font(.system(size: size.labelFontSize, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
                .textCase(.uppercase)
                .tracking(0.5)
            
            Text(projectedScoreString)
                .font(.system(size: size.fontSize, weight: .bold, design: .rounded))
                .foregroundColor(projectedColor)
                .shadow(color: projectedColor.opacity(0.3), radius: 4, x: 0, y: 2)
        }
    }
    
    // MARK: - Computed Properties
    
    private var projectedScoreString: String {
        String(format: "%.1f", myProjected)
    }
    
    private var projectedColor: Color {
        if myProjected > opponentProjected {
            return .gpGreen
        } else if myProjected < opponentProjected {
            return .gpRedPink
        } else {
            return .white.opacity(0.8)
        }
    }
}

// MARK: - Preview

#Preview("Winning") {
    ZStack {
        Color.black
        ProjectedScoreView(
            myProjected: 125.5,
            opponentProjected: 108.2,
            size: .large
        )
    }
}

#Preview("Losing") {
    ZStack {
        Color.black
        ProjectedScoreView(
            myProjected: 95.3,
            opponentProjected: 112.8,
            size: .large
        )
    }
}