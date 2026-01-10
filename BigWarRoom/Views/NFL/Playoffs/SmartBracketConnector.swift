//
//  SmartBracketConnector.swift
//  BigWarRoom
//
//  Dynamic connector that draws between two calculated points
//

import SwiftUI

struct SmartBracketConnector: View {
    let startPoint: ConnectionPoint?
    let endPoint: ConnectionPoint?
    let isReversed: Bool
    
    var body: some View {
        GeometryReader { geo in
            if let start = startPoint, let end = endPoint {
                Path { path in
                    // Convert points to local coordinate system
                    let startLocal = CGPoint(x: start.x, y: start.y)
                    let endLocal = CGPoint(x: end.x, y: end.y)
                    
                    // Calculate midpoint for the elbow
                    let midX = (startLocal.x + endLocal.x) / 2
                    
                    // Draw L-shaped connector
                    path.move(to: startLocal)
                    path.addLine(to: CGPoint(x: midX, y: startLocal.y))  // Horizontal out
                    path.addLine(to: CGPoint(x: midX, y: endLocal.y))    // Vertical
                    path.addLine(to: endLocal)                            // Horizontal in
                }
                .stroke(Color.gray.opacity(0.5), lineWidth: 1.5)
            }
        }
    }
}