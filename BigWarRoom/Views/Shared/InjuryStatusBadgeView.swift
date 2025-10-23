//
//  InjuryStatusBadgeView.swift
//  BigWarRoom
//
//  Small circular injury status badge for player images
//

import SwiftUI

struct InjuryStatusBadgeView: View {
    let injuryStatus: String
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(backgroundColor)
                .strokeBorder(Color.white, lineWidth: 1.5)
                .frame(width: 22, height: 22)
            
            // Status text
            Text(statusText)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(textColor)
                .minimumScaleFactor(0.8)
        }
    }
    
    // MARK: - Computed Properties
    
    private var statusText: String {
        let status = injuryStatus.uppercased()
        
        // Map common injury statuses to short codes
        switch status {
        case "QUESTIONABLE":
            return "Q"
        case "DOUBTFUL":
            return "D"
        case "OUT":
            return "O"
        case "INJURED_RESERVE", "IR":
            return "IR"
        case "PROBABLE":
            return "P"
        case "BYE":
            return "BYE"
        case "SUSPENDED":
            return "S"
        case "PHYSICALLY_UNABLE_TO_PERFORM", "PUP":
            return "PUP"
        case "NON_FOOTBALL_INJURY", "NFI":
            return "NFI"
        default:
            // For other statuses, take first letter or first 2 letters if short
            if status.count <= 2 {
                return status
            } else {
                return String(status.prefix(1))
            }
        }
    }
    
    private var backgroundColor: Color {
        let status = injuryStatus.uppercased()
        
        switch status {
        case "QUESTIONABLE":
            return .yellow
        case "DOUBTFUL":
            return .orange
        case "OUT", "INJURED_RESERVE", "IR":
            return .red
        case "PROBABLE":
            return .green.opacity(0.8)
        case "BYE":
            return .blue.opacity(0.8)
        case "SUSPENDED":
            return .purple
        case "PHYSICALLY_UNABLE_TO_PERFORM", "PUP", "NON_FOOTBALL_INJURY", "NFI":
            return .gray.opacity(0.8)
        default:
            return .orange // Default for unknown statuses
        }
    }
    
    private var textColor: Color {
        let status = injuryStatus.uppercased()
        
        switch status {
        case "QUESTIONABLE":
            return .black // Yellow background needs black text
        case "PROBABLE":
            return .white
        case "BYE":
            return .white
        default:
            return .white
        }
    }
}

#Preview("Questionable") {
    InjuryStatusBadgeView(injuryStatus: "Questionable")
        .padding()
        .background(Color.gray)
}

#Preview("Out") {
    InjuryStatusBadgeView(injuryStatus: "Out")
        .padding()
        .background(Color.gray)
}

#Preview("IR") {
    InjuryStatusBadgeView(injuryStatus: "IR")
        .padding()
        .background(Color.gray)
}

#Preview("BYE") {
    InjuryStatusBadgeView(injuryStatus: "BYE")
        .padding()
        .background(Color.gray)
}