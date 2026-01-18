//
//  StatBlock.swift
//  BigWarRoom
//
//  Reusable stat display component for All Live Players
//

import SwiftUI

/// A reusable component for displaying a statistic with title and value
struct StatBlock: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}