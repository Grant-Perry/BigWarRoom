//
//  FantasyRedirectView.swift
//  BigWarRoom
//
//  Redirects Fantasy tab users to War Room for proper league setup
//

import SwiftUI

struct FantasyRedirectView: View {
    @Binding var selectedTab: Int
    let draftRoomViewModel: DraftRoomViewModel
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // App logo or football icon
                AppConstants.appLogo
                    .frame(width: 80, height: 80)
                
                VStack(spacing: 16) {
                    Text("Fantasy Matchups")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Connect to your leagues in War Room first")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Text("War Room handles all league connections and setup. Once connected, you'll be able to view your fantasy matchups.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Redirect button
                Button(action: {
                    // Switch to War Room tab
                    selectedTab = 1
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "brain.head.profile")
                            .font(.title2)
                        
                        Text("Go to War Room")
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [.gpGreen, .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .gpGreen.opacity(0.3), radius: 10, x: 0, y: 4)
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Fantasy")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            // If user already has a connected league, auto-switch to War Room
            if draftRoomViewModel.selectedLeagueWrapper != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    selectedTab = 1
                }
            }
        }
    }
}