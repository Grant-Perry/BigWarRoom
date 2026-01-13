//
//  BracketConnectorLine.swift
//  BigWarRoom
//
//  Curved bracket line connecting two teams in a matchup
//

import SwiftUI

/// Curved bracket line connecting two teams in a matchup
struct BracketConnectorLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let cardHeight: CGFloat = 50
        let spacing: CGFloat = 20
        
        // Calculate centers of the two cards
        let topCardCenterY = cardHeight / 2
        let bottomCardCenterY = cardHeight + spacing + (cardHeight / 2)
        
        let startX = rect.maxX // Start at right edge (will touch card)
        let curveOutX = rect.minX // Curve out to left edge
        
        // Start at right edge, center of top card
        path.move(to: CGPoint(x: startX, y: topCardCenterY))
        
        // Line out to the left
        path.addLine(to: CGPoint(x: curveOutX + 10, y: topCardCenterY))
        
        // Rounded corner at top
        path.addQuadCurve(
            to: CGPoint(x: curveOutX, y: topCardCenterY + 10),
            control: CGPoint(x: curveOutX, y: topCardCenterY)
        )
        
        // Vertical line connecting the two cards
        path.addLine(to: CGPoint(x: curveOutX, y: bottomCardCenterY - 10))
        
        // Rounded corner at bottom
        path.addQuadCurve(
            to: CGPoint(x: curveOutX + 10, y: bottomCardCenterY),
            control: CGPoint(x: curveOutX, y: bottomCardCenterY)
        )
        
        // Line back to card
        path.addLine(to: CGPoint(x: startX, y: bottomCardCenterY))
        
        return path
    }
}