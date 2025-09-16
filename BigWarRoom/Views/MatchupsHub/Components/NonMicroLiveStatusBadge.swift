//
//  NonMicroLiveStatusBadge.swift
//  BigWarRoom
//
//  Created by System on 1/27/2025.
//

import SwiftUI

/// Live status badge for non-micro cards
struct NonMicroLiveStatusBadge: View {
    let isLive: Bool
    
    var body: some View {
        Text("LIVE")
            .font(.system(size: isLive ? 10 : 8, weight: .black))
            .foregroundColor(isLive ? .gpGreen : .gpRedPink.opacity(0.4))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill((isLive ? Color.gpGreen : Color.gpRedPink).opacity(isLive ? 0.2 : 0.1))
            )
            .scaleEffect(isLive ? 1.0 : 0.9)
            .opacity(isLive ? 1.0 : 0.6)
    }
}