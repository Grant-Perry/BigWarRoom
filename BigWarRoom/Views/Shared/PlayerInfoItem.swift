//
//  PlayerInfoItem.swift
//  BigWarRoom
//
//  Reusable component for displaying player information items
//

import SwiftUI

/// Reusable component for displaying player information
struct PlayerInfoItem: View {
    let label: String
    let value: String
    let style: Style
    
    enum Style {
        case detail    // For detailed rows (label on left, value on right)
        case compact   // For compact display (vertical stack)
        case fantasy   // For fantasy analysis with color
        
        var labelColor: Color {
            switch self {
            case .detail, .compact: return .secondary
            case .fantasy: return .secondary
            }
        }
    }
    
    init(_ label: String, _ value: String, style: Style = .detail) {
        self.label = label
        self.value = value
        self.style = style
    }
    
    var body: some View {
        switch style {
        case .detail:
            detailStyle
        case .compact:
            compactStyle
        case .fantasy:
            detailStyle // Same as detail for now
        }
    }
    
    private var detailStyle: some View {
        HStack {
            Text(label)
                .foregroundColor(style.labelColor)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
    }
    
    private var compactStyle: some View {
        VStack(spacing: 2) {
            Text(label)
                .foregroundColor(style.labelColor)
            Text(value)
                .fontWeight(.medium)
        }
    }
}