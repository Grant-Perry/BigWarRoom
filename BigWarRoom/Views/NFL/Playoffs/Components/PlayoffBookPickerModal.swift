//
//  PlayoffBookPickerModal.swift
//  BigWarRoom
//
//  Modal for selecting sportsbook
//

import SwiftUI

struct PlayoffBookPickerModal: View {
    let odds: GameBettingOdds
    @Binding var selectedBook: String
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.75)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }
            
            BookPickerSheet(
                odds: odds,
                selectedBook: $selectedBook,
                onDismiss: onDismiss
            )
            .shadow(color: .black.opacity(0.3), radius: 20)
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.2), value: true)
    }
}