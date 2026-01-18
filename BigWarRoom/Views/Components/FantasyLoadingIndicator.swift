//
//  FantasyLoadingIndicator.swift
//  BigWarRoom
//
//  🔥 FIXED: Uses the standalone SpinningOrbsView component (no parameters needed)
//

import SwiftUI

struct FantasyLoadingIndicator: View {
    var body: some View {
        SpinningOrbsView()
            .frame(width: 200, height: 200)
    }
}